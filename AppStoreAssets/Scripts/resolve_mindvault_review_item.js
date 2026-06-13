(() => {
  const APP_ID = "6776897058";
  const VERSION_ID = "9f074ce3-67e3-4dc0-98b4-e6a92b0893e6";

  function request(method, url, body) {
    const xhr = new XMLHttpRequest();
    xhr.open(method, url, false);
    xhr.withCredentials = true;
    xhr.setRequestHeader("Accept", "application/vnd.api+json");
    if (body) {
      xhr.setRequestHeader("Content-Type", "application/vnd.api+json");
    }
    xhr.send(body ? JSON.stringify(body) : null);

    let response;
    try {
      response = JSON.parse(xhr.responseText || "{}");
    } catch {
      response = xhr.responseText;
    }

    return { method, url, status: xhr.status, response };
  }

  function fetchSubmissions() {
    return request(
      "GET",
      `${base}/apps/${APP_ID}/reviewSubmissions?include=appStoreVersionForReview,items,lastUpdatedByActor,submittedByActor,createdByActor&limit=2000&limit[items]=200`
    );
  }

  const base = "https://appstoreconnect.apple.com/iris/v1";
  const before = fetchSubmissions();
  const submissions = before.response.data || [];
  const included = before.response.included || [];
  const submission = submissions.find((candidate) => {
    const versionRef = candidate.relationships &&
      candidate.relationships.appStoreVersionForReview &&
      candidate.relationships.appStoreVersionForReview.data;
    const state = candidate.attributes && candidate.attributes.state;
    return versionRef && versionRef.id === VERSION_ID && state === "UNRESOLVED_ISSUES";
  });

  const itemRefs = (submission &&
    submission.relationships &&
    submission.relationships.items &&
    submission.relationships.items.data) || [];
  const rejectedItem = itemRefs
    .map((ref) => included.find((item) => item.type === ref.type && item.id === ref.id))
    .find((item) => item && item.attributes && item.attributes.state === "REJECTED");

  const patchResult = rejectedItem ? request(
    "PATCH",
    `${base}/reviewSubmissionItems/${encodeURIComponent(rejectedItem.id)}`,
    {
      data: {
        type: "reviewSubmissionItems",
        id: rejectedItem.id,
        attributes: {
          resolved: true
        }
      }
    }
  ) : null;

  const after = fetchSubmissions();

  return JSON.stringify({
    before: {
      status: before.status,
      submissions: submissions.map((entry) => ({
        id: entry.id,
        state: entry.attributes && entry.attributes.state,
        appStoreVersionForReview: entry.relationships &&
          entry.relationships.appStoreVersionForReview &&
          entry.relationships.appStoreVersionForReview.data
      })),
      rejectedItem: rejectedItem && {
        id: rejectedItem.id,
        state: rejectedItem.attributes && rejectedItem.attributes.state,
        resolved: rejectedItem.attributes && rejectedItem.attributes.resolved
      }
    },
    patchResult: patchResult && {
      status: patchResult.status,
      data: patchResult.response.data,
      errors: patchResult.response.errors
    },
    after: {
      status: after.status,
      submissions: (after.response.data || []).map((entry) => ({
        id: entry.id,
        state: entry.attributes && entry.attributes.state,
        submittedDate: entry.attributes && entry.attributes.submittedDate,
        appStoreVersionForReview: entry.relationships &&
          entry.relationships.appStoreVersionForReview &&
          entry.relationships.appStoreVersionForReview.data,
        itemRefs: entry.relationships &&
          entry.relationships.items &&
          entry.relationships.items.data
      })),
      included: (after.response.included || []).map((item) => ({
        type: item.type,
        id: item.id,
        attributes: item.attributes
      }))
    }
  }, null, 2);
})();
