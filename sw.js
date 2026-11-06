// Service Worker for Dead Man's Hand: Devil's Parlor (Web Prototype)
// Caches all core game shell files for offline play and PWA installation.

const CACHE_NAME = 'dmh-devils-parlor-v3';

const PRECACHE_ASSETS = [
  './',
  './index.html',
  './styles.css',
  './manifest.webmanifest',
  './src/main.js',
  './src/i18n.js',
  './src/audio.js',
  './src/data.js',
  './src/rng.js',
  './src/rules.js',
  './src/ai.js',
  './src/render.js',
  './assets/icon.svg',
  './assets/icon-192.png',
  './assets/icon-512.png',
  './assets/icon-maskable-512.png',
  './assets/apple-touch-icon.png',
];

self.addEventListener('install', (event) => {
  // 이 파일들은 주소에 버전이 없어 내용이 바뀌어도 주소가 같다. 그냥 받으면 HTTP 캐시(Pages 10분)에 남은
  // 옛 파일이 새 캐시에 들어가 캐시 우선으로 나간다(manifest id를 고쳐도 Chrome이 옛 id를 보던 문제).
  // 그래서 설치 때는 HTTP 캐시를 건너뛰고 새로 받는다.
  const requests = PRECACHE_ASSETS.map((url) => new Request(url, { cache: 'reload' }));
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => cache.addAll(requests))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key.startsWith('dmh-devils-parlor-') && key !== CACHE_NAME)
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Leave the Godot web build under /play/ to its own service worker / network.
  const scopePath = new URL(self.registration.scope).pathname;
  const relPath = url.pathname.startsWith(scopePath)
    ? url.pathname.slice(scopePath.length)
    : url.pathname;
  if (relPath === 'play' || relPath.startsWith('play/')) return;

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put('./index.html', copy));
          return response;
        })
        .catch(async () => {
          const cache = await caches.open(CACHE_NAME);
          return (await cache.match('./index.html')) || (await cache.match('./'));
        }),
    );
    return;
  }

  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cached = await cache.match(request);
      const networkFetch = fetch(request)
        .then((response) => {
          if (response && response.ok) {
            cache.put(request, response.clone());
          }
          return response;
        })
        .catch(() => cached);
      return cached || networkFetch;
    }),
  );
});
