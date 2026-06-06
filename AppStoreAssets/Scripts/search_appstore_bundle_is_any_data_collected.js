(() => {
  const urls = Array.from(new Set(
    performance.getEntriesByType("resource")
      .map((entry) => entry.name)
      .filter((name) => /m-appstore|partials\/app-store/i.test(name) && /\.js(\?|$)/i.test(name))
  ));
  const terms = [
    "isAnyDataCollected",
    "uiAppDataUsageDetails",
    "DATA_NOT_COLLECTED_CONFIRMATION",
    "DataTypeSelectionModal",
    "PRIVACY_DETAILS_FORM",
    "PATCH_APP_DATA_USAGE_PUBLISH_STATE"
  ];

  function getText(url) {
    const xhr = new XMLHttpRequest();
    xhr.open("GET", url, false);
    xhr.withCredentials = true;
    xhr.send(null);
    return xhr.responseText || "";
  }

  const snippets = [];
  for (const url of urls) {
    const text = getText(url);
    const lower = text.toLowerCase();
    for (const term of terms) {
      let index = lower.indexOf(term.toLowerCase());
      let count = 0;
      while (index >= 0 && count < 30) {
        snippets.push({
          term,
          url,
          index,
          snippet: text.slice(Math.max(0, index - 1400), Math.min(text.length, index + 2200))
        });
        count += 1;
        index = lower.indexOf(term.toLowerCase(), index + term.length);
      }
    }
  }

  return JSON.stringify({ snippetCount: snippets.length, snippets }, null, 2);
})();
