-- ARise — feedback form (lib/features/feedback/)
-- Run in the Supabase SQL editor after schema.sql. Safe to re-run.
--
-- The app may INSERT feedback and upload a photo, but never read either back:
-- submissions are only visible in the dashboard / with the service role.

create table if not exists public.feedback (
  id              bigint generated always as identity primary key,
  category        text not null
                    check (category in ('ar_tracking', 'feature_request',
                                        'visuals_audio', 'bug_report', 'praise')),
  rating          smallint check (rating between 1 and 5),
  message         text check (char_length(message) <= 500),
  email           text check (email is null or email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  attachment_path text,
  app_version     text,
  platform        text,
  created_at      timestamptz not null default now(),

  -- the form only sends when there is something to act on
  constraint feedback_has_content check (rating is not null or message is not null)
);

alter table public.feedback enable row level security;

drop policy if exists "app submits feedback" on public.feedback;
create policy "app submits feedback"
  on public.feedback for insert
  to anon, authenticated
  with check (true);

-- Private bucket: photos are not public, and the app can only add to it.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('feedback-attachments', 'feedback-attachments', false, 15728640,
        array['image/jpeg', 'image/png', 'image/heic', 'image/webp'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "app uploads feedback photos" on storage.objects;
create policy "app uploads feedback photos"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'feedback-attachments');
