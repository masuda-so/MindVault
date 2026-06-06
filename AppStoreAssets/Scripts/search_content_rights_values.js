(() => {
  const urls = Array.from(new Set(
    performance.getEntriesByType("resource")
      .map((entry) => entry.name)
      .filter((name) => (
        /m-appstore\/static\/js\/.*\.js/i.test(name) ||
        /partials\/app-store\/js\/.*\.js/i.test(name)
      ))
  ));

  const terms = [
    "DOES_NOT_USE_THIRD_PARTY_CONTENT",
    "USES_THIRD_PARTY_CONTENT",
    "CONTAINS_THIRD_PARTY",
    "DOES_NOT_CONTAIN",
    "thirdPartyContent",
    "contentRightsDeclaration:",
    "content_rights"
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
      while (index >= 0 && count < 12) {
        snippets.push({
          url: url.replace(/^https:\/\/appstoreconnect\.apple\.com/, ""),
          term,
          index,
          snippet: text.slice(Math.max(0, index - 1400), Math.min(text.length, index + 2200))
        });
        count += 1;
        index = lower.indexOf(term.toLowerCase(), index + term.length);
      }
    }
  }

  return JSON.stringify({ scriptCount: urls.length, snippetCount: snippets.length, snippets }, null, 2);
})();
