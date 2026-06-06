(() => {
  const scripts = Array.from(document.scripts || [])
    .map((script) => script.src)
    .filter(Boolean);
  const resources = performance.getEntriesByType("resource")
    .map((entry) => entry.name)
    .filter((name) => /appstoreconnect|itunes|iris|privacy/i.test(name));

  return JSON.stringify({
    location: location.href,
    scriptCount: scripts.length,
    scripts: scripts.slice(0, 80),
    resourceCount: resources.length,
    resources: resources.slice(-120)
  }, null, 2);
})();
