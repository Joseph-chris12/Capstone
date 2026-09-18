-- AR Gallery — Storage buckets
-- Public buckets: Supabase serves them with Access-Control-Allow-Origin: *,
-- CDN-cached, and with HTTP Range support. The WebView needs all three:
-- CORS so the video texture does not taint the WebGL context, and Range so
-- playback starts before the whole file arrives.

insert into storage.buckets (id, name, public)
values ('ar-targets', 'ar-targets', true)
on conflict (id) do update set public = true;

insert into storage.buckets (id, name, public)
values ('ar-videos', 'ar-videos', true)
on conflict (id) do update set public = true;

-- Public buckets are already world-readable; these policies make the intent
-- explicit and keep writes off the anon key.
drop policy if exists "public read ar-targets" on storage.objects;
create policy "public read ar-targets"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'ar-targets');

drop policy if exists "public read ar-videos" on storage.objects;
create policy "public read ar-videos"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'ar-videos');
