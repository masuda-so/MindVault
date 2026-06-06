(() => {
  const APP_ID = "6776897058";

  function request(method, url) {
    const xhr = new XMLHttpRequest();
    xhr.open(method, url, false);
    xhr.withCredentials = true;
    xhr.setRequestHeader("Accept", "application/vnd.api+json");
    xhr.send(null);

    let response;
    try {
      response = JSON.parse(xhr.responseText || "{}");
    } catch {
      response = xhr.responseText;
    }

    return { status: xhr.status, response };
  }

  const base = "https://appstoreconnect.apple.com/iris/v1";
  const result = request(
    "GET",
    `${base}/apps/${APP_ID}/reviewSubmissions?include=appStoreVersionForReview,items,lastUpdatedByActor,submittedByActor,createdByActor&limit=2000&limit[items]=200`
  );

  const submissions = (result.response.data || []).map((submission) => ({
    id: submission.id,
    state: submission.attributes && submission.attributes.state,
    platform: submission.attributes && submission.attributes.platform,
    submitted: submission.attributes && submission.attributes.submitted,
    itemRefs: submission.relationships && submission.relationships.items && submission.relationships.items.data,
    appStoreVersionForReview: submission.relationships && submission.relationships.appStoreVersionForReview && submission.relationships.appStoreVersionForReview.data
  }));

  const included = (result.response.included || []).map((item) => ({
    type: item.type,
    id: item.id,
    attributes: item.attributes,
    relationships: item.relationships
  }));

  return JSON.stringify({
    status: result.status,
    count: submissions.length,
    submissions,
    included
  }, null, 2);
})();
