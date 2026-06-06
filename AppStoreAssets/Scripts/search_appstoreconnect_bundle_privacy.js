(() => {
  const urls = Array.from(new Set(
    performance.getEntriesByType("resource")
      .map((entry) => entry.name)
      .filter((name) => /m-myapps\/static\/js\/.*\.js/i.test(name))
  ));

  function getText(url) {
    const xhr = new XMLHttpRequest();
    xhr.open("GET", url, false);
    xhr.withCredentials = true;
    xhr.send(null);
    return { status: xhr.status, text: xhr.responseText || "" };
  }

  const snippets = [];
  for (const url of urls) {
    const result = getText(url);
    const text = result.text;
    const lower = text.toLowerCase();
    let index = lower.indexOf("privacy");
    const seen = new Set();
    while (index >= 0 && snippets.length < 80) {
      const start = Math.max(0, index - 220);
      const end = Math.min(text.length, index + 420);
      const snippet = text.slice(start, end);
      if (!seen.has(snippet)) {
        seen.add(snippet);
        snippets.push({ url, status: result.status, index, snippet });
      }
      index = lower.indexOf("privacy", index + 7);
    }
  }

  return JSON.stringify({ urls, snippetCount: snippets.length, snippets }, null, 2);
})();
