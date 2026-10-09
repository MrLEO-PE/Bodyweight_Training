/* Bodyweight Builder service worker.
   Lets the app open without a connection (after the first visit) and install on the home screen.
   Pages are fetched from the network first, so a new version arrives as soon as you are online.
   Data requests to Supabase are never cached: they always go to the network. */
const VERSION = 'bwb-v1';
const SHELL = ['./', 'index.html', 'manifest.webmanifest', 'icons/icon-192.png', 'icons/icon-512.png'];
const LIBS = ['cdn.jsdelivr.net', 'cdnjs.cloudflare.com', 'fonts.googleapis.com', 'fonts.gstatic.com'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSION).then(c => Promise.allSettled(SHELL.map(u => c.add(u)))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});

const keep = (req, res) => { if(res && (res.ok || res.type === 'opaque')) caches.open(VERSION).then(c => c.put(req, res.clone())).catch(() => {}); return res; };

self.addEventListener('fetch', e => {
  const req = e.request, url = new URL(req.url);
  if(req.method !== 'GET' || url.hostname.endsWith('supabase.co')) return;   // data: always live
  const sameOrigin = url.origin === self.location.origin;
  if(!sameOrigin && !LIBS.includes(url.hostname)) return;
  if(req.mode === 'navigate' || (sameOrigin && url.pathname.endsWith('index.html'))){
    // network first, so updates arrive; fall back to the saved copy when offline
    e.respondWith(fetch(req).then(res => keep(req, res)).catch(() => caches.match(req, { ignoreSearch:true }).then(r => r || caches.match('index.html')).then(r => r || caches.match('./'))));
    return;
  }
  // everything else: show the saved copy straight away and refresh it in the background
  e.respondWith(caches.match(req).then(saved => {
    const fresh = fetch(req).then(res => keep(req, res)).catch(() => saved);
    return saved || fresh;
  }));
});
