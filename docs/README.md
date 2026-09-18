# Cafe test page

A standalone, single-target AR page for testing on a phone with no Flutter
build, no Android SDK and no cable. Served over HTTPS by GitHub Pages because
`getUserMedia` refuses to run on an insecure origin.

| File | What it is |
|---|---|
| `index.html` | The whole experience — scene, controls, video lifecycle |
| `targets.mind` | Compiled tracking bundle (1 target, 461 KB) |
| `clip.mp4` | The Kling clip, 720x1280, 5.0s, H.264/AAC |
| `target-preview.jpg` | The rectified poster the target was compiled from |
| `vendor/` | A-Frame + MindAR, same builds the Flutter app ships |

## The target

Compiled from a photo of an Espresso poster, perspective-corrected to a
front-on view. The frame was isolated by **saturation** rather than brightness:
the black frame and the maroon panel have almost identical luminance, but the
frame is neutral (RGB spread ~2) while the maroon is strongly saturated
(spread ~57).

Rectified target: 1100x1848, aspect ratio **1.68**.

The maroon panel sits at these fractions of the target, measured from the
rectified image and used by `index.html` to place the video:

```
x: 0.0491 .. 0.9600      y: 0.1472 .. 0.7305
```

## Controls

The clip is 720x1280 (aspect 1.778) and the poster is 1.68, so they nearly
match; the maroon panel is roughly square and does not. Rather than guessing
which placement suits the clip, the page exposes both:

- **Whole poster / Maroon panel** — which region the video covers.
- **Fill / Fit whole video** — crop the overflow (via texture repeat/offset),
  or shrink the plane to the clip's shape so nothing is cropped.
- **Sound** — starts muted, because no mobile browser will autoplay with audio.

## Known limitation of the build environment

The video could not be played back where this was built: Playwright's Chromium
has no proprietary codecs, so H.264 does not decode there. Everything else —
target compilation, bundle round-trip, scene construction, geometry maths, the
control toggles — was verified headlessly. Phones decode H.264 in hardware, so
playback is expected to work, but it is the one untested link.
