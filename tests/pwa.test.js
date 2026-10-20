import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = process.cwd();

test('manifest.webmanifest is valid and all icon files exist', () => {
  const manifestPath = join(ROOT, 'manifest.webmanifest');
  assert.ok(existsSync(manifestPath), 'manifest.webmanifest exists');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));

  assert.equal(manifest.display, 'standalone');
  assert.ok(manifest.name);
  assert.ok(manifest.short_name);
  assert.equal(manifest.start_url, './');
  assert.equal(manifest.scope, './');
  assert.ok(Array.isArray(manifest.icons) && manifest.icons.length >= 3);

  const sizes = new Set(manifest.icons.map((i) => i.sizes));
  assert.ok(sizes.has('192x192'), 'has 192x192 icon');
  assert.ok(sizes.has('512x512'), 'has 512x512 icon');
  assert.ok(manifest.icons.some((i) => i.purpose === 'maskable'), 'has maskable icon');

  for (const icon of manifest.icons) {
    const iconPath = join(ROOT, icon.src);
    assert.ok(existsSync(iconPath), `icon exists: ${icon.src}`);
    assert.ok(statSync(iconPath).size > 0, `icon is non-empty: ${icon.src}`);
  }
});

test('service worker precache list references existing files', () => {
  const swPath = join(ROOT, 'sw.js');
  assert.ok(existsSync(swPath), 'sw.js exists');
  const swSource = readFileSync(swPath, 'utf8');
  const match = swSource.match(/const PRECACHE_ASSETS = \[([\s\S]*?)\];/);
  assert.ok(match, 'PRECACHE_ASSETS array found in sw.js');
  const urls = [...match[1].matchAll(/'([^']+)'/g)].map((m) => m[1]);
  assert.ok(urls.length >= 10, 'precache list includes core assets');

  for (const rel of urls) {
    if (rel === './') continue;
    const clean = rel.replace(/^\.\//, '');
    const full = join(ROOT, clean);
    assert.ok(existsSync(full), `precache asset exists: ${rel}`);
  }
});

test('index.html and Godot export preset enable PWA support', () => {
  const html = readFileSync(join(ROOT, 'index.html'), 'utf8');
  assert.match(html, /<link[^>]+rel="manifest"[^>]+href="manifest\.webmanifest"/);
  assert.match(html, /<link[^>]+rel="apple-touch-icon"[^>]+href="assets\/apple-touch-icon\.png"/);

  const presets = readFileSync(join(ROOT, 'godot/export_presets.cfg'), 'utf8');
  assert.match(presets, /progressive_web_app\/enabled=true/);
});
