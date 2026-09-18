# AR Gallery

Point a phone at a painting in the campus gallery and the painting moves.

Built in the shape of [Artivive](https://www.artivive.com/): a photo of the
artwork is compiled into a tracking target, and a short video is overlaid on the
real canvas through the camera. The app opens straight into the viewfinder —
there is no menu to get through first.

The animations are produced by hand in Google Flow (Veo) and uploaded as
finished MP4s.

---

## How it fits together

```
┌─ Flutter (Dart) ────────────────────────────────┐
│  ARScreen  ← home screen, opens on launch       │
│   ├── scanning overlay                          │
│   ├── info sheet, slides up on targetFound      │
│   └── InAppWebView (fullscreen, behind the UI)  │
│        └── http://localhost:8080/ar.html        │
│             └── A-Frame + MindAR                │
│                  ├─ fullframe → <a-video>       │
│                  └─ cutout    → chromakey shader│
└─────────────────────────────────────────────────┘
        │ manifest JSON            ▲ targetFound/Lost
        ▼                          │
┌─ Supabase ──────────────────────────────────────┐
│  Postgres: artworks, target_bundles             │
│  Storage:  ar-targets/(.mind)  ar-videos/(.mp4) │
└─────────────────────────────────────────────────┘
```

The AR page and its libraries **ship inside the APK**, so the app launches and
the tracking engine loads with no network. Only content — the `.mind` bundle,
the videos, the descriptions — comes from Supabase at runtime, which keeps the
install small and lets the gallery change without a new release.

### Why a WebView

The Flutter AR plugin ecosystem does not currently support this use case:

| Option | Why not |
|---|---|
| `ar_flutter_plugin` | No release since Nov 2022; Dart SDK capped `<3.0.0` |
| `augen` | ~196 downloads; image tracking but no video-on-target |
| `AR_quido` | Detection callbacks only, no rendering; needs an EasyAR licence key |
| Native ARCore + SceneView | Good, but Android-only, and chroma-key needs a custom Filament material |

MindAR in a WebView is the only route where cut-out (green-screen) video is
cheap, and where iOS later is a build step rather than a rewrite.

---

## Setup

### 1. Supabase

Create a project, then in the SQL editor run, in order:

```
supabase/schema.sql
supabase/storage.sql
```

That creates the `artworks` and `target_bundles` tables, RLS policies, the two
public storage buckets, and the `publish_bundle()` function.

> **Free tier projects pause after a week of inactivity.** Open the dashboard a
> day before any demo, or the app will fail to load the gallery.

### 2. Compile and publish content

```bash
cd tools/compile-targets
npm install                      # also fetches Chromium for the compiler
cp .env.example .env             # fill in SUPABASE_SERVICE_ROLE_KEY
cp artworks.example.json artworks.json
```

Put your target photos in `targets/` and your videos in `videos/`, list them in
`artworks.json`, then:

```bash
node compile.js --dry-run                 # compile only, nothing uploaded
node --env-file=.env compile.js           # compile, upload, publish
```

**The array order in `artworks.json` is the target index.** The tool compiles
the bundle and writes the database rows in the same run, through a single
transactional `publish_bundle()` call, because those two things must agree — the
app addresses targets purely by position, and if they drift every painting plays
its neighbour's video with no visible error.

### 3. Run the app

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

The publishable (anon) key is safe to ship — RLS limits it to reading published
artworks. The **service role key is never used by the app**, only by the compile
tool, and must stay out of the repo.

On iOS you additionally need `permission_handler`'s camera macro enabled in the
Podfile; see that package's README.

---

## Preparing artwork

**Target photos are not the Flow output.** The target is a flat, straight-on,
evenly lit photo of the painting *as it hangs*. Feature-rich, high-contrast
artwork tracks well; flat or repetitive artwork tracks poorly — test each piece
early rather than discovering it at the gallery.

**Full-frame clips.** Feed the painting photo into Flow as the start frame and
prompt for a *locked-off camera, no zoom, no pan*, with subtle loopable motion.
A drifting camera makes the video slide off the real painting as the phone moves.

**Cut-out clips.** Generate the subject on a pure, evenly lit green background
and set `videoMode: "cutout"` with `chromaColor`. Keep green and teal out of the
subject itself. Use `planeWidth` / `planeHeight` / `offsetY` to let the subject
extend past the canvas edge.

**Transcode before upload:** 720p H.264 + AAC with `-movflags +faststart`, under
roughly 6 MB per clip.

```bash
ffmpeg -i in.mp4 -vf scale=-2:720 -c:v libx264 -crf 24 -preset slow \
       -c:a aac -b:a 96k -movflags +faststart out.mp4
```

---

## Budget and limits

Supabase free tier: 1 GB storage, 10 GB egress/month (5 cached + 5 uncached).

- Videos at ~6 MB each: roughly 1,600 plays/month.
- **The `.mind` bundle is ~500 KB per target** and is fetched on every launch.
  At 12 artworks that is a ~6 MB download per app start — in practice this, not
  the videos, is the thing most likely to exhaust egress. Caching it on device
  is the first optimisation to reach for.

A demo day of 50 visitors × 6 artworks lands around 2 GB. It fits, but without
much room to spare.

---

## Repo layout

```
lib/
  core/config.dart              build-time Supabase config
  data/                         Artwork model + repository
  features/ar/                  AR home screen, JS bridge, overlays
  features/catalog/             secondary artwork list
assets/web/
  ar.html, app.js               the AR scene
  vendor/                       A-Frame, MindAR, chromakey (committed)
supabase/
  schema.sql, storage.sql       tables, RLS, publish_bundle()
tools/compile-targets/          Node + headless Chromium compiler
```

## Tests

```bash
flutter test      # model parsing + target-index validation
flutter analyze
```

## Credits and licensing

The artworks belong to their artists. Get written permission from the gallery
and the artists before running this as a public installation. Video generated
with Google Flow (Veo) carries an invisible SynthID watermark.
