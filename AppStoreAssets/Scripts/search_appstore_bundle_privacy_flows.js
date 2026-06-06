(() => {
  const urls = Array.from(new Set(
    performance.getEntriesByType("resource")
      .map((entry) => entry.name)
      .filter((name) => /m-appstore|partials\/app-store/i.test(name) && /\.js(\?|$)/i.test(name))
  ));
  const terms = [
    "dataUsagePublishState",
    "appDataUsagesPublishState",
    "appDataUsages",
    "dataUsages",
    "DataNotCollected",
    "data-not-collected",
    "notCollected",
    "published",
    "collects",
    "APP_DATA_USAGES_REQUIRED"
  ];

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
    for (const term of terms) {
      let index = lower.indexOf(term.toLowerCase());
      let count = 0;
      while (index >= 0 && count < 18) {
        snippets.push({
          term,
          url,
          index,
          snippet: text.slice(Math.max(0, index - 900), Math.min(text.length, index + 1600))
        });
        count += 1;
        index = lower.indexOf(term.toLowerCase(), index + term.length);
      }
    }
  }

  return JSON.stringify({ urls, snippetCount: snippets.length, snippets }, null, 2);
})();
