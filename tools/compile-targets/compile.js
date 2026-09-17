#!/usr/bin/env node
/*
 * Compiles artwork photos into a MindAR .mind bundle and publishes it.
 *
 *   node compile.js [--dry-run] [--manifest artworks.json]
 *
 * The array order in the manifest IS target_index. This one script both
 * compiles the bundle and writes the database rows, because those two things
 * must agree: the app addresses targets purely by position, so if they drift
 * every painting plays its neighbour's video with no visible error.
 *
 * Compilation runs in headless Chromium rather than node-canvas. MindAR's
 * compiler is a browser API, and node-canvas needs native Cairo/Pango headers
 * that are painful to install on Windows. Chromium also lets this script reuse
 * the exact mind-ar build the app ships.
 */
import { createServer } from 'node:http';
import { readFile, writeFile, mkdir, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium } from 'playwright';
import { createClient } from '@supabase/supabase-js';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const APP_VENDOR = path.resolve(HERE, '../../assets/web/vendor');
const OUT_DIR = path.join(HERE, 'out');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
};

const VIDEO_MIME = {
  '.mp4': 'video/mp4',
  '.webm': 'video/webm',
  '.mov': 'video/quicktime',
};

const IMAGE_MIME = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
};

function fail(message) {
  console.error(`\n  ERROR  ${message}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const args = { dryRun: false, manifest: 'artworks.json' };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--dry-run') args.dryRun = true;
    else if (argv[i] === '--manifest') args.manifest = argv[++i];
    else fail(`unknown argument: ${argv[i]}`);
  }
  return args;
}

// --- manifest ---------------------------------------------------------------

async function loadManifest(file) {
  const abs = path.resolve(HERE, file);
  if (!existsSync(abs)) {
    fail(
      `${file} not found.\n         Copy artworks.example.json to artworks.json and edit it.`,
    );
  }

  let parsed;
  try {
    parsed = JSON.parse(await readFile(abs, 'utf8'));
  } catch (e) {
    fail(`${file} is not valid JSON: ${e.message}`);
  }

  const artworks = parsed.artworks;
  if (!Array.isArray(artworks) || artworks.length === 0) {
    fail(`${file} must contain a non-empty "artworks" array.`);
  }

  const seen = new Set();
  artworks.forEach((a, i) => {
    const where = `artworks[${i}]${a.slug ? ` (${a.slug})` : ''}`;
    for (const field of ['slug', 'title', 'target', 'video']) {
      if (!a[field]) fail(`${where} is missing "${field}".`);
    }
    if (seen.has(a.slug)) fail(`${where}: duplicate slug "${a.slug}".`);
    seen.add(a.slug);

    const mode = a.videoMode ?? 'fullframe';
    if (!['fullframe', 'cutout'].includes(mode)) {
      fail(`${where}: videoMode must be "fullframe" or "cutout", got "${mode}".`);
    }
    if (mode === 'cutout' && !a.chromaColor) {
      fail(
        `${where}: a cutout artwork needs "chromaColor" (e.g. "0.1 0.9 0.2"),\n` +
          `         otherwise the green background is never keyed out.`,
      );
    }

    for (const [field, dir] of [['target', 'target photo'], ['video', 'video']]) {
      const p = path.resolve(HERE, a[field]);
      if (!existsSync(p)) fail(`${where}: ${dir} not found at ${a[field]}`);
    }

    const ext = path.extname(a.target).toLowerCase();
    if (!IMAGE_MIME[ext]) {
      fail(`${where}: target must be .jpg or .png, got "${ext}".`);
    }
  });

  return artworks;
}

// --- compilation ------------------------------------------------------------

/** Serves the compiler page plus the app's vendored mind-ar build. */
function startServer() {
  const server = createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    let file;
    if (url.pathname === '/' || url.pathname === '/index.html') {
      file = path.join(HERE, 'compiler-page.html');
    } else if (url.pathname.startsWith('/vendor/')) {
      file = path.join(APP_VENDOR, url.pathname.replace('/vendor/', ''));
    } else {
      res.writeHead(404).end('not found');
      return;
    }

    try {
      const body = await readFile(file);
      res.writeHead(200, {
        'Content-Type': MIME[path.extname(file)] ?? 'application/octet-stream',
      });
      res.end(body);
    } catch {
      res.writeHead(404).end('not found');
    }
  });

  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () =>
      resolve({ server, port: server.address().port }),
    );
  });
}

async function compile(artworks) {
  for (const f of ['aframe.min.js', 'mindar-image-aframe.prod.js']) {
    if (!existsSync(path.join(APP_VENDOR, f))) {
      fail(`missing ${f} in assets/web/vendor — see that folder's VERSIONS.md.`);
    }
  }

  const dataUrls = await Promise.all(
    artworks.map(async (a) => {
      const buf = await readFile(path.resolve(HERE, a.target));
      const mime = IMAGE_MIME[path.extname(a.target).toLowerCase()];
      return `data:${mime};base64,${buf.toString('base64')}`;
    }),
  );

  const { server, port } = await startServer();
  let browser;
  try {
    // CHROMIUM_PATH lets a machine reuse a Chromium it already has instead of
    // letting Playwright download its own — useful in CI and on locked-down
    // lab machines. Normally `npm install` handles this via postinstall.
    browser = await chromium.launch(
      process.env.CHROMIUM_PATH
        ? { executablePath: process.env.CHROMIUM_PATH }
        : {},
    );
    const page = await browser.newPage();

    page.on('pageerror', (e) => console.error(`  [page] ${e.message}`));

    await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: 'load' });
    await page.waitForFunction(
      () => typeof window.compileTargets === 'function' && window.MINDAR?.IMAGE?.Compiler,
      null,
      { timeout: 30_000 },
    );

    const ticker = setInterval(async () => {
      try {
        const p = await page.evaluate(() => window.__progress);
        if (typeof p === 'number') {
          process.stdout.write(`\r  compiling… ${p.toFixed(0)}%   `);
        }
      } catch {
        /* page busy in the compile loop; try again next tick */
      }
    }, 500);

    // Generous: feature extraction is CPU-bound and scales with target count
    // and image resolution.
    const result = await page.evaluate(
      (urls) => window.compileTargets(urls),
      dataUrls,
    );

    clearInterval(ticker);
    process.stdout.write('\r  compiling… 100%     \n');
    return {
      mind: Buffer.from(result.mind, 'base64'),
      targets: result.targets,
    };
  } finally {
    if (browser) await browser.close();
    server.close();
  }
}

// --- publishing -------------------------------------------------------------

function supabaseFromEnv() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    fail(
      'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.\n' +
        '         Copy .env.example to .env, fill it in, then run with:\n' +
        '           node --env-file=.env compile.js',
    );
  }
  return createClient(url, key, { auth: { persistSession: false } });
}

async function upload(sb, bucket, dest, body, contentType) {
  const { error } = await sb.storage
    .from(bucket)
    .upload(dest, body, { contentType, upsert: true });
  if (error) fail(`upload to ${bucket}/${dest} failed: ${error.message}`);
  return dest;
}

async function publish(artworks, compiled, mindBytes) {
  const sb = supabaseFromEnv();
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const mindPath = `targets-${stamp}.mind`;

  console.log('\n  uploading…');
  await upload(sb, 'ar-targets', mindPath, mindBytes, 'application/octet-stream');
  console.log(`    ar-targets/${mindPath}`);

  const rows = [];
  for (let i = 0; i < artworks.length; i++) {
    const a = artworks[i];
    const ext = path.extname(a.video).toLowerCase();
    const videoPath = `${a.slug}${ext}`;
    await upload(
      sb,
      'ar-videos',
      videoPath,
      await readFile(path.resolve(HERE, a.video)),
      VIDEO_MIME[ext] ?? 'video/mp4',
    );
    console.log(`    ar-videos/${videoPath}`);

    rows.push({
      slug: a.slug,
      title: a.title,
      artist: a.artist ?? '',
      year: a.year ?? '',
      description: a.description ?? '',
      target_index: i,
      aspect_ratio: compiled.targets[i].aspectRatio,
      video_path: videoPath,
      video_mode: a.videoMode ?? 'fullframe',
      chroma_color: a.chromaColor ?? '',
      plane_width: a.planeWidth ?? '',
      plane_height: a.planeHeight ?? '',
      offset_x: a.offsetX ?? 0,
      offset_y: a.offsetY ?? 0,
    });
  }

  // One RPC so the bundle swap and the row rewrite land together. A partial
  // publish would leave the app pairing new indexes with an old bundle.
  const { data, error } = await sb.rpc('publish_bundle', {
    p_mind_path: mindPath,
    p_artworks: rows,
  });
  if (error) fail(`publish_bundle failed: ${error.message}`);

  return data;
}

// --- main -------------------------------------------------------------------

async function main() {
  const args = parseArgs(process.argv.slice(2));

  console.log('\n  AR Gallery — target compiler\n');
  const artworks = await loadManifest(args.manifest);
  console.log(`  ${artworks.length} artwork(s), in bundle order:`);
  artworks.forEach((a, i) =>
    console.log(`    [${i}] ${a.slug}  (${a.videoMode ?? 'fullframe'})`),
  );
  console.log();

  const compiled = await compile(artworks);

  await mkdir(OUT_DIR, { recursive: true });
  const localMind = path.join(OUT_DIR, 'targets.mind');
  await writeFile(localMind, compiled.mind);

  const kb = (await stat(localMind)).size / 1024;
  console.log(`\n  bundle: ${localMind} (${kb.toFixed(0)} KB)`);
  compiled.targets.forEach((t, i) =>
    console.log(
      `    [${i}] ${artworks[i].slug}  ${t.width}x${t.height}  ` +
        `aspect ${t.aspectRatio.toFixed(4)}`,
    ),
  );

  if (args.dryRun) {
    console.log('\n  --dry-run: nothing uploaded, database untouched.\n');
    return;
  }

  const version = await publish(artworks, compiled, compiled.mind);
  console.log(`\n  published bundle version ${version}. The app will pick it up on next launch.\n`);
}

main().catch((e) => fail(e.stack ?? e.message));
