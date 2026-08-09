'use strict';

// Bumper à chaque fix UI critique — force purge des vieux main.dart.js
const CACHE_NAME = 'sombateka-flutter-v4';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys.filter((k) => k.startsWith('sombateka-') && k !== CACHE_NAME).map((k) => caches.delete(k))
      );
      await Promise.all(
        keys
          .filter((k) => k.startsWith('flutter-app-') || k.includes('flutter'))
          .map((k) => caches.delete(k))
      );
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  // Ne jamais servir le shell / le JS principal depuis un vieux cache
  const isShell =
    url.pathname === '/' ||
    url.pathname.endsWith('/index.html') ||
    url.pathname.endsWith('flutter_bootstrap.js') ||
    url.pathname.endsWith('main.dart.js') ||
    url.pathname.endsWith('flutter_service_worker.js');

  if (isShell) {
    event.respondWith(
      fetch(req)
        .then((resp) => {
          if (resp && resp.ok && url.pathname.endsWith('main.dart.js')) {
            caches.open(CACHE_NAME).then((cache) => cache.put(req, resp.clone()));
          }
          return resp;
        })
        .catch(() => caches.match(req))
    );
    return;
  }

  const isAsset =
    url.pathname.endsWith('.js') ||
    url.pathname.endsWith('.wasm') ||
    url.pathname.endsWith('.json') ||
    url.pathname.endsWith('.png') ||
    url.pathname.endsWith('.jpg') ||
    url.pathname.endsWith('.webp') ||
    url.pathname.endsWith('.svg') ||
    url.pathname.endsWith('.woff2') ||
    url.pathname.includes('/assets/') ||
    url.pathname.includes('/icons/') ||
    url.pathname.includes('/fonts/');

  if (!isAsset) return;

  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cached = await cache.match(req);
      if (cached) return cached;
      const resp = await fetch(req);
      if (resp && resp.ok) {
        cache.put(req, resp.clone());
      }
      return resp;
    })
  );
});
