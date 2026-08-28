// Register the service worker so LYNS is installable as an app.
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").catch((err) => {
      console.warn("LYNS: service worker registration failed", err);
    });
  });
}
