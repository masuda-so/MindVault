(() => {
  const resources = performance.getEntriesByType("resource")
    .map((entry) => entry.name)
    .filter((name) => /appstoreconnect\.apple\.com/i.test(name))
    .slice(0, 250);

  return JSON.stringify({
    location: location.href,
    resourceCount: performance.getEntriesByType("resource").length,
    appleResourceCount: resources.length,
    resources
  }, null, 2);
})();
