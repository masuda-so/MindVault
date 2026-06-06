(() => {
  const urls = Array.from(new Set(
    performance.getEntriesByType("resource")
      .map((entry) => entry.name)
      .filter((name) => /m-myapps\/static\/js\/.*\.js/i.test(name))
  ));
  const terms = [
    "appDataUsages",
    "dataUsages",
    "appDataUsage",
    "GET_APP_DATA_USAGES",
    "SAVE_APP_DATA_USAGE",
    "GET_APP_PRIVACY",
    "privacyChoicesUrl",
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
    for (const term of terms) {
      const lower = text.toLowerCase();
      const search = term.toLowerCase();
      let index = lower.indexOf(search);
      let count = 0;
      while (index >= 0 && count < 20) {
        snippets.push({
          term,
          url,
          status: result.status,
          index,
          snippet: text.slice(Math.max(0, index - 520), Math.min(text.length, index + 900))
        });
        count += 1;
        index = lower.indexOf(search, index + search.length);
      }
    }
  }

  return JSON.stringify({ snippetCount: snippets.length, snippets }, null, 2);
})();
