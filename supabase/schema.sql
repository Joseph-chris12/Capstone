-- AR Gallery — Supabase schema
-- Apply via the Supabase SQL editor, or `supabase db push`.

-- ---------------------------------------------------------------------------
-- artworks
-- ---------------------------------------------------------------------------
-- target_index points into the compiled .mind bundle. It is written ONLY by
-- tools/compile-targets, which compiles the bundle and updates these rows in
-- the same run. Editing it by hand desynchronises the app from the bundle and
-- makes every artwork show the wrong video.
create table if not exists public.artworks (
  id            uuid primary key default gen_random_uuid(),
  slug          text unique not null,
  title         text not null,
  artist        text,
  year          text,
  description   text,
  target_index  int  not null,
  aspect_ratio  numeric not null check (aspect_ratio > 0),
  video_path    text not null,
  video_mode    text not null default 'fullframe'
                  check (video_mode in ('fullframe', 'cutout')),
  chroma_color  text,

  -- Plane geometry, in MindAR target units (target = 1.0 wide, aspect_ratio
  -- tall). NULL means "exactly cover the artwork", which is what a fullframe
  -- clip wants. A cutout that steps out of the canvas overrides these.
  plane_width   numeric check (plane_width  > 0),
  plane_height  numeric check (plane_height > 0),
  offset_x      numeric not null default 0,
  offset_y      numeric not null default 0,
  is_active     boolean not null default true,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  -- a cutout artwork is meaningless without a key colour
  constraint cutout_needs_chroma_color
    check (video_mode <> 'cutout' or chroma_color is not null)
);

-- Deferrable on purpose: publish_bundle() below reshuffles target_index across
-- rows inside one transaction, and a non-deferrable constraint would fire on
-- the intermediate state even though the final state is valid.
alter table public.artworks
  drop constraint if exists artworks_target_index_unique;
alter table public.artworks
  add constraint artworks_target_index_unique
  unique (target_index) deferrable initially deferred;

-- ---------------------------------------------------------------------------
-- target_bundles — compiled .mind files, versioned
-- ---------------------------------------------------------------------------
create table if not exists public.target_bundles (
  id         uuid primary key default gen_random_uuid(),
  version    int not null unique,
  mind_path  text not null,
  is_current boolean not null default false,
  created_at timestamptz not null default now()
);

-- exactly one current bundle
create unique index if not exists target_bundles_one_current
  on public.target_bundles (is_current) where is_current;

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists artworks_set_updated_at on public.artworks;
create trigger artworks_set_updated_at
  before update on public.artworks
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
-- The app ships the anon key, so anon may read published content and nothing
-- else. All writes go through tools/compile-targets using the service role key,
-- which bypasses RLS and must never be bundled into the app.
alter table public.artworks      enable row level security;
alter table public.target_bundles enable row level security;

drop policy if exists "anon reads active artworks" on public.artworks;
create policy "anon reads active artworks"
  on public.artworks for select
  to anon, authenticated
  using (is_active);

drop policy if exists "anon reads current bundle" on public.target_bundles;
create policy "anon reads current bundle"
  on public.target_bundles for select
  to anon, authenticated
  using (is_current);

-- ---------------------------------------------------------------------------
-- publish_bundle — the only supported way to publish a compile run
-- ---------------------------------------------------------------------------
-- Rewrites the artwork set and swaps in a new .mind bundle atomically.
--
-- This has to be one transaction. The app pairs artworks.target_index with
-- positions inside the bundle, so a half-applied publish — new indexes against
-- the old bundle, or vice versa — makes every painting play its neighbour's
-- video with no visible error. Callers use the service role key.
--
-- p_artworks is the compile tool's output, in bundle order: the array position
-- IS the target_index, which is why the tool that compiles is the tool that
-- writes these rows.
create or replace function public.publish_bundle(
  p_mind_path text,
  p_artworks  jsonb
)
returns int
language plpgsql
as $$
declare
  v_version int;
begin
  if jsonb_typeof(p_artworks) <> 'array' or jsonb_array_length(p_artworks) = 0 then
    raise exception 'p_artworks must be a non-empty JSON array';
  end if;

  select coalesce(max(version), 0) + 1 into v_version from public.target_bundles;

  -- Artworks no longer in the compile run leave the gallery.
  delete from public.artworks
  where slug not in (
    select x->>'slug' from jsonb_array_elements(p_artworks) x
  );

  insert into public.artworks (
    slug, title, artist, year, description,
    target_index, aspect_ratio, video_path, video_mode, chroma_color,
    plane_width, plane_height, offset_x, offset_y, sort_order, is_active
  )
  select
    x->>'slug',
    x->>'title',
    nullif(x->>'artist', ''),
    nullif(x->>'year', ''),
    nullif(x->>'description', ''),
    (x->>'target_index')::int,
    (x->>'aspect_ratio')::numeric,
    x->>'video_path',
    coalesce(nullif(x->>'video_mode', ''), 'fullframe'),
    nullif(x->>'chroma_color', ''),
    (nullif(x->>'plane_width',  ''))::numeric,
    (nullif(x->>'plane_height', ''))::numeric,
    coalesce((nullif(x->>'offset_x', ''))::numeric, 0),
    coalesce((nullif(x->>'offset_y', ''))::numeric, 0),
    (x->>'target_index')::int,
    true
  from jsonb_array_elements(p_artworks) x
  on conflict (slug) do update set
    title        = excluded.title,
    artist       = excluded.artist,
    year         = excluded.year,
    description  = excluded.description,
    target_index = excluded.target_index,
    aspect_ratio = excluded.aspect_ratio,
    video_path   = excluded.video_path,
    video_mode   = excluded.video_mode,
    chroma_color = excluded.chroma_color,
    plane_width  = excluded.plane_width,
    plane_height = excluded.plane_height,
    offset_x     = excluded.offset_x,
    offset_y     = excluded.offset_y,
    sort_order   = excluded.sort_order,
    is_active    = true;

  update public.target_bundles set is_current = false where is_current;

  insert into public.target_bundles (version, mind_path, is_current)
  values (v_version, p_mind_path, true);

  return v_version;
end;
$$;

-- The app's key must not be able to rewrite the gallery.
revoke all on function public.publish_bundle(text, jsonb) from public, anon, authenticated;
