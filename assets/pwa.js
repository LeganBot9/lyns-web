// Register the network-only service worker so LYNS is an installable app.
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").catch((err) => {
      console.warn("LYNS: service worker registration failed", err);
    });
  });
}
