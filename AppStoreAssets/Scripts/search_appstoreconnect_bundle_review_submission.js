(() => {
  const urls = Array.from(new Set(
    performance.getEntriesByType("resource")
      .map((entry) => entry.name)
      .filter((name) => (
        /m-myapps\/static\/js\/.*\.js/i.test(name) ||
        /m-appstore\/static\/js\/.*\.js/i.test(name) ||
        /partials\/app-store\/js\/.*\.js/i.test(name)
      ))
  ));

  const terms = [
    "reviewSubmissions",
    "reviewSubmissionItems",
    "appStoreVersionForReview",
    "subscriptionForReview",
    "SubmitForReview",
    "SUBMIT_APP_VERSION",
    "SUBMIT_SUBSCRIPTION_WITH_VERSION",
    "SUBMIT_SUBSCRIPTION_FOR_REVIEW",
    "ADD_FOR_REVIEW",
    "CancelSubmission",
    "RemoveFromReview"
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
          snippet: text.slice(Math.max(0, index - 1200), Math.min(text.length, index + 1800))
        });
        count += 1;
        index = lower.indexOf(term.toLowerCase(), index + term.length);
      }
    }
  }

  return JSON.stringify({ scriptCount: urls.length, snippetCount: snippets.length, snippets }, null, 2);
})();
