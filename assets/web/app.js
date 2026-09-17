/*
 * AR Gallery — scene builder and Flutter bridge.
 *
 * The Flutter layer owns all UI. This file owns tracking and video playback,
 * and reports what it sees back across the bridge.
 *
 * Lifecycle, driven from Dart:
 *   onReady        -> Dart sends the manifest
 *   ARApp.init()   -> builds the scene -> onSceneReady
 *   ARApp.start()  -> camera + tracking -> onArReady | onArError
 *   ... onTargetFound / onTargetLost as the visitor moves ...
 */
(function () {
  'use strict';

  var DEFAULT_CHROMA = '0.1 0.9 0.2';

  var state = {
    scene: null,
    arSystem: null,
    artworks: [],      // manifest order
    videos: {},        // targetIndex -> HTMLVideoElement
    activeIndex: null,
    started: false,
    muted: true
  };

  // --- bridge ------------------------------------------------------------

  function send(handler, payload) {
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler(handler, payload || {});
        return;
      }
    } catch (e) {
      // fall through to console so the page stays debuggable in a browser
    }
    console.log('[ARApp]', handler, JSON.stringify(payload || {}));
  }

  function fail(stage, err) {
    send('onError', {
      stage: stage,
      message: (err && (err.message || err.toString())) || 'unknown error'
    });
  }

  // --- video pool --------------------------------------------------------

  // preload="none" is deliberate: with 6-12 artworks, preloading every clip
  // would download the whole gallery on launch and burn Supabase egress for
  // videos the visitor never looks at. Each clip loads when its artwork is
  // first recognised.
  function makeVideo(art) {
    var v = document.createElement('video');
    v.id = 'vid-' + art.targetIndex;
    v.src = art.videoUrl;
    v.crossOrigin = 'anonymous';   // required, or the texture taints the WebGL context
    v.loop = true;
    v.muted = true;                // iOS will not autoplay with sound
    v.playsInline = true;
    v.setAttribute('playsinline', '');
    v.setAttribute('webkit-playsinline', '');
    v.setAttribute('muted', '');
    v.preload = 'none';
    v.addEventListener('error', function () {
      var e = v.error;
      send('onVideoError', {
        targetIndex: art.targetIndex,
        slug: art.slug,
        code: e ? e.code : null,
        message: e ? e.message : 'video failed to load'
      });
    });
    document.getElementById('video-pool').appendChild(v);
    state.videos[art.targetIndex] = v;
    return v;
  }

  function playVideo(index) {
    var v = state.videos[index];
    if (!v) return;
    var p = v.play();
    if (p && typeof p.catch === 'function') {
      p.catch(function (err) {
        // Autoplay was refused. Dart shows a tap-to-play affordance; the
        // gesture is forwarded back through ARApp.resumePlayback().
        send('onPlaybackBlocked', {
          targetIndex: index,
          message: (err && err.message) || 'autoplay blocked'
        });
      });
    }
  }

  function pauseVideo(index) {
    var v = state.videos[index];
    if (!v) return;
    try { v.pause(); } catch (e) { /* teardown race, harmless */ }
  }

  // --- scene -------------------------------------------------------------

  function targetEntity(art) {
    var entity = document.createElement('a-entity');
    entity.setAttribute('mindar-image-target', 'targetIndex: ' + art.targetIndex);

    // MindAR normalises targets to 1 unit wide, with height = aspect ratio.
    // A fullframe clip therefore sits exactly on the real canvas. A cutout
    // may deliberately overflow those bounds, so it carries its own size.
    var width = art.planeWidth || 1;
    var height = art.planeHeight || art.aspectRatio;
    var pos = (art.offsetX || 0) + ' ' + (art.offsetY || 0) + ' 0';

    var plane;
    if (art.videoMode === 'cutout') {
      plane = document.createElement('a-plane');
      plane.setAttribute('material',
        'shader: chromakey; src: #vid-' + art.targetIndex +
        '; color: ' + (art.chromaColor || DEFAULT_CHROMA));
      // The chromakey shader writes alpha, so the plane must not write depth
      // or it will occlude whatever is behind it within the same target.
      plane.setAttribute('transparent', 'true');
    } else {
      plane = document.createElement('a-video');
      plane.setAttribute('src', '#vid-' + art.targetIndex);
    }
    plane.setAttribute('width', width);
    plane.setAttribute('height', height);
    plane.setAttribute('position', pos);
    entity.appendChild(plane);

    entity.addEventListener('targetFound', function () {
      state.activeIndex = art.targetIndex;
      playVideo(art.targetIndex);
      send('onTargetFound', {
        targetIndex: art.targetIndex,
        slug: art.slug,
        title: art.title,
        artist: art.artist,
        year: art.year,
        description: art.description
      });
    });

    entity.addEventListener('targetLost', function () {
      if (state.activeIndex === art.targetIndex) state.activeIndex = null;
      pauseVideo(art.targetIndex);
      send('onTargetLost', { targetIndex: art.targetIndex, slug: art.slug });
    });

    return entity;
  }

  function buildScene(manifest) {
    var scene = document.createElement('a-scene');

    // autoStart:false — the camera only opens once Dart confirms permission.
    // maxTrack:1 — a visitor looks at one painting at a time, and detection
    // cost grows with the number of simultaneously tracked targets.
    scene.setAttribute('mindar-image',
      'imageTargetSrc: ' + manifest.mindUrl + '; ' +
      'autoStart: false; ' +
      'maxTrack: 1; ' +
      'uiLoading: no; uiError: no; uiScanning: no' +
      (manifest.filterMinCF != null ? '; filterMinCF: ' + manifest.filterMinCF : '') +
      (manifest.filterBeta != null ? '; filterBeta: ' + manifest.filterBeta : ''));

    scene.setAttribute('embedded', '');
    scene.setAttribute('color-space', 'sRGB');
    scene.setAttribute('renderer', 'colorManagement: true, physicallyCorrectLights, alpha: true');
    scene.setAttribute('vr-mode-ui', 'enabled: false');
    scene.setAttribute('device-orientation-permission-ui', 'enabled: false');

    var camera = document.createElement('a-camera');
    camera.setAttribute('position', '0 0 0');
    camera.setAttribute('look-controls', 'enabled: false');
    scene.appendChild(camera);

    manifest.artworks.forEach(function (art) {
      makeVideo(art);
      scene.appendChild(targetEntity(art));
    });

    scene.addEventListener('arReady', function () {
      send('onArReady', { targetCount: manifest.artworks.length });
    });
    scene.addEventListener('arError', function (e) {
      send('onArError', {
        message: (e && e.detail && e.detail.error) || 'AR failed to initialise'
      });
    });

    document.getElementById('scene-root').appendChild(scene);
    state.scene = scene;
    state.artworks = manifest.artworks;

    scene.addEventListener('loaded', function () {
      state.arSystem = scene.systems['mindar-image-system'];
      send('onSceneReady', { targetCount: manifest.artworks.length });
    });
  }

  // --- public API --------------------------------------------------------

  window.ARApp = {
    init: function (manifest) {
      try {
        if (state.scene) {
          fail('init', new Error('scene already built'));
          return;
        }
        if (!manifest || !manifest.mindUrl || !manifest.artworks) {
          fail('init', new Error('manifest missing mindUrl or artworks'));
          return;
        }
        buildScene(manifest);
      } catch (e) {
        fail('init', e);
      }
    },

    start: function () {
      try {
        if (!state.arSystem) { fail('start', new Error('scene not ready')); return; }
        if (state.started) return;
        state.arSystem.start();
        state.started = true;
      } catch (e) {
        fail('start', e);
      }
    },

    stop: function () {
      try {
        if (state.arSystem && state.started) {
          state.arSystem.stop();
          state.started = false;
        }
        Object.keys(state.videos).forEach(function (i) { pauseVideo(i); });
      } catch (e) {
        fail('stop', e);
      }
    },

    // Called when Flutter backgrounds the AR screen. pause(true) also releases
    // the camera track, which Android requires before another app can use it.
    pause: function () {
      try {
        if (state.arSystem && state.started) state.arSystem.pause(true);
        Object.keys(state.videos).forEach(function (i) { pauseVideo(i); });
      } catch (e) {
        fail('pause', e);
      }
    },

    resume: function () {
      try {
        if (state.arSystem && state.started) state.arSystem.unpause();
        if (state.activeIndex != null) playVideo(state.activeIndex);
      } catch (e) {
        fail('resume', e);
      }
    },

    // Retry after onPlaybackBlocked, called from a real user gesture in Dart.
    resumePlayback: function () {
      if (state.activeIndex != null) playVideo(state.activeIndex);
    },

    setMuted: function (muted) {
      state.muted = !!muted;
      Object.keys(state.videos).forEach(function (i) {
        state.videos[i].muted = state.muted;
      });
      return state.muted;
    },

    isMuted: function () { return state.muted; }
  };

  // Tell Dart the page is parsed and the API exists. Dart replies with init().
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () { send('onReady', {}); });
  } else {
    send('onReady', {});
  }
})();
