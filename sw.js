// LYNS service worker — NETWORK-ONLY.
// It exists so the app qualifies as an installable PWA (App Store / Play Store
// wrappers require one). It caches nothing except a small offline page, so it
// can never serve stale content — every request goes to the network.
const CACHE = "lyns-v3";
const OFFLINE_URL = "/offline";

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((c) => c.add(OFFLINE_URL)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  event.respondWith(
    fetch(req).catch(() => {
      if (req.mode === "navigate") return caches.match(OFFLINE_URL);
      return new Response("", { status: 504, statusText: "offline" });
    })
  );
});
