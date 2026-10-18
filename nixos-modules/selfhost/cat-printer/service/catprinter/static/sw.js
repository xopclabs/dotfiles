"use strict";
// Never cache API responses or queue print requests for later delivery.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) =>
  event.waitUntil(self.clients.claim()),
);
async function receiveShare(request) {
  try {
    const cache = await caches.open("catprinter-incoming-shares");
    for (const key of await cache.keys()) {
      const previous = await cache.match(key);
      if (
        Date.now() - Number(previous.headers.get("X-Share-Created")) >
        3600000
      )
        await cache.delete(key);
    }
    const token = crypto.randomUUID();
    const key = new URL("/share-target/" + token, self.location.origin);
    const data = await request.formData();
    await cache.put(
      key,
      new Response(data, {
        headers: { "X-Share-Created": String(Date.now()) },
      }),
    );
    return Response.redirect(
      new URL("/?share=" + token, self.location.origin),
      303,
    );
  } catch {
    return Response.redirect(
      new URL("/?share=failed", self.location.origin),
      303,
    );
  }
}
self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  if (
    url.origin === self.location.origin &&
    url.pathname === "/share-target" &&
    event.request.method === "POST"
  ) {
    event.respondWith(receiveShare(event.request));
    return;
  }
  if (event.request.mode !== "navigate") return;
  event.respondWith(
    fetch(event.request).catch(
      () =>
        new Response(
          '<!doctype html><meta name="viewport" content="width=device-width"><title>Catprinter</title><body style="font-family:system-ui;background:#eceff4;color:#2e3440;padding:2rem"><h1>Catprinter is offline</h1><p>Reconnect to the printer service, then reopen the app.</p></body>',
          {
            status: 503,
            headers: { "Content-Type": "text/html; charset=utf-8" },
          },
        ),
    ),
  );
});
