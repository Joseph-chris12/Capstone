# Vendored browser libraries

Committed rather than loaded from a CDN so the AR page works with no network and
cannot break when a CDN changes. Re-vendor with:

    npm install --ignore-scripts mind-ar@1.2.5 aframe@1.7.1 aframe-chromakey-material

then copy the dist files listed below.

| File | Package | Version |
|---|---|---|
| `aframe.min.js` | aframe | 1.7.1 |
| `mindar-image-aframe.prod.js` | mind-ar | 1.2.5 |
| `aframe-chromakey-material.min.js` | aframe-chromakey-material | 1.1.4 |

`mindar-image-aframe.prod.js` is self-contained — it has no dynamic imports and
does not reference the `controller-*.js` split chunks in the package, so it is
the only mind-ar file needed.
