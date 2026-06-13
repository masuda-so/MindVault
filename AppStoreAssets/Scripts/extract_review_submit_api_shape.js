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
    "PostReviewSubmissionAPI",
    "GetReviewSubmissions",
    "PatchReviewSubmissionAPI",
    "appStoreVersionSubmissions",
    "/appStoreVersionSubmissions",
    "/reviewSubmissions",
    "reviewSubmissionSubmissions",
    "reviewSubmissionOperations",
    "reviewSubmissionItems",
    "reviewSubmission",
    "CANCEL_REVIEW_SUBMISSION",
    "SUBMIT_APP_VERSION",
    "SUBMIT_FOR_REVIEW",
    "SubmitForReview",
    "submittedByActor",
    "submittedDate"
  ];

  function getText(url) {
    const xhr = new XMLHttpRequest();
    xhr.open("GET", url, false);
    xhr.withCredentials = true;
    xhr.send(null);
    return xhr.responseText || "";
  }

  function compactSnippet(text, index) {
    return text
      .slice(Math.max(0, index - 900), Math.min(text.length, index + 1600))
      .replace(/\s+/g, " ");
  }

  const snippets = [];
  for (const url of urls) {
    const text = getText(url);
    const lower = text.toLowerCase();

    for (const term of terms) {
      let index = lower.indexOf(term.toLowerCase());
      let count = 0;

      while (index >= 0 && count < 6) {
        snippets.push({
          url: url.replace(/^https:\/\/appstoreconnect\.apple\.com/, ""),
          term,
          index,
          snippet: compactSnippet(text, index)
        });
        index = lower.indexOf(term.toLowerCase(), index + term.length);
        count += 1;
      }
    }
  }

  return JSON.stringify({ scriptCount: urls.length, snippetCount: snippets.length, snippets }, null, 2);
})();
