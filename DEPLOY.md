# Deploying AR Gallery — step by step

Everything runs on GitHub Actions and Supabase; you do not need Flutter or
Node installed to get the app onto a phone.

| Piece | Where it lives |
|---|---|
| Database + storage | Supabase project `skyvxextruhfofmjopln` |
| Artwork content (photos, clips) | `tools/compile-targets/` in this repo → uploaded to Supabase |
| Android app | **Android APK** workflow → downloadable `.apk` |
| Web app | `flutter run -d chrome`, or GitHub Pages at `/app/` once on `main` |

---

## 1. Database — already done

The schema is applied to the project as three migrations
(`ar_gallery_schema`, `ar_gallery_storage`, `ar_gallery_pin_search_path`).
You can see them in Supabase → **Database → Migrations**, and the tables in
**Table Editor**: `artists`, `artworks`, `target_bundles`, `scan_events`, all
with RLS on. Storage has two public buckets, `ar-targets` and `ar-videos`.

To recreate it on another project: Supabase → **SQL Editor** → paste and run
`supabase/schema.sql`, then `supabase/storage.sql`. Both are safe to re-run.

## 2. Add two GitHub secrets (one time)

GitHub → this repo → **Settings → Secrets and variables → Actions →
New repository secret**:

| Name | Value |
|---|---|
| `SUPABASE_URL` | `https://skyvxextruhfofmjopln.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase → **Project Settings → API Keys** → the **secret** key (`sb_secret_…`), or under *Legacy API keys* the `service_role` key |

The service-role key bypasses every security rule. Put it only in this
GitHub secret — never in the app, a chat, or a commit. The app itself uses the
public *publishable* key, which is already built in.

## 3. Upload the artworks to Supabase

GitHub → **Actions → Publish content → Run workflow**, pick branch
`claude/jolly-archimedes-c60lkd` (or `main` once merged) → **Run workflow**.

It takes a few minutes (it compiles the 13 tracking targets). When it is green:

- the log ends with `published bundle version 1`
- Supabase → **Table Editor → artworks** shows 13 rows
- Supabase → **Storage** shows the `.mind` bundle, 13 videos and 13 thumbnails

## 4. Install the Android app

1. GitHub → **Actions → Android APK** → open the latest green run.
2. Under **Artifacts**, download `ar-gallery-apk` and unzip it.
3. Copy `app-release.apk` to the phone (USB, Google Drive, Telegram to yourself…).
4. Tap it on the phone. Android asks to **allow installing unknown apps** for
   the app you opened it from — allow, then **Install**.
5. Open **AR Gallery** and allow the camera.

The APK reads content from Supabase at launch, so after step 3 there is no
need to rebuild it when artworks change.

## 5. Web version

**On a laptop** (uses the webcam; `localhost` counts as secure for the camera):

```bash
git clone https://github.com/Joseph-chris12/Capstone.git
cd Capstone && git checkout claude/jolly-archimedes-c60lkd
flutter run -d chrome
```

**On a phone's browser** (needs HTTPS, so GitHub Pages):

1. Merge `claude/jolly-archimedes-c60lkd` into `main` (open a pull request and merge it).
2. One time: **Settings → Pages → Build and deployment → Source = GitHub Actions**.
3. The **Deploy AR test page** workflow runs on the merge.
4. Open `https://joseph-chris12.github.io/Capstone/app/`.

## 6. Try it

Point the camera at one of the posters — or at its photo on a laptop screen.
Within a few seconds the clip should play on top of it and the title, artist
and description slide up from the bottom.

- If **Tap to play** appears, tap it (some phones block autoplay).
- Sound starts muted; use the speaker icon top-left.
- The grid icon top-right lists every artwork.
- **Behind the Blinds** (the blue/red waves) is not recognised: its repeating
  stripes give the tracker too little to lock onto.

## 7. See who scanned what

Supabase → **SQL Editor**:

```sql
select * from scan_stats order by day desc, scans desc;
```

One row per artwork per day: scans, and distinct visitors (app launches).

## 8. Changing the artworks later

1. Put the photo in `tools/compile-targets/targets/` and the clip (720p H.264,
   a few MB — see the README's ffmpeg line) in `tools/compile-targets/videos/`.
2. Add an entry to `tools/compile-targets/artworks.json`. Array order is the
   target index; the tool handles it.
3. Commit, push, and re-run **Publish content**. Phones pick it up on next launch.

Removing an entry and republishing removes that artwork *and its scan history*.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| "Could not load the gallery — No published target bundle" | Step 3 not run yet. |
| "Could not load the gallery" with a network error | Supabase free projects **pause after ~1 week idle**: open the dashboard and restore it a day before a demo. |
| Camera stays black | Camera permission denied: Android Settings → Apps → AR Gallery → Permissions. |
| Artwork recognised but no video | Tap **Tap to play**; check the clip exists in Storage → `ar-videos`. |
| Publish content fails at "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set" | Secret names in step 2 are misspelled or missing. |
| Wrong video on an artwork | Never edit `target_index` by hand; re-run **Publish content**. |
