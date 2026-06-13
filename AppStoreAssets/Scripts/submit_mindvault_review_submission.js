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

  function summarize(result) {
    const included = result.response.included || [];
    return {
      status: result.status,
      submissions: (result.response.data || []).map((submission) => ({
        id: submission.id,
        state: submission.attributes && submission.attributes.state,
        submittedDate: submission.attributes && submission.attributes.submittedDate,
        appStoreVersionForReview: submission.relationships &&
          submission.relationships.appStoreVersionForReview &&
          submission.relationships.appStoreVersionForReview.data,
        items: ((submission.relationships &&
          submission.relationships.items &&
          submission.relationships.items.data) || []).map((ref) => {
          const item = included.find((candidate) => candidate.type === ref.type && candidate.id === ref.id);
          return {
            id: ref.id,
            type: ref.type,
            state: item && item.attributes && item.attributes.state
          };
        })
      }))
    };
  }

  const base = "https://appstoreconnect.apple.com/iris/v1";
  const before = fetchSubmissions();
  const submission = (before.response.data || []).find((candidate) => {
    const versionRef = candidate.relationships &&
      candidate.relationships.appStoreVersionForReview &&
      candidate.relationships.appStoreVersionForReview.data;
    return versionRef && versionRef.id === VERSION_ID;
  });

  const submitResult = submission ? request(
    "PATCH",
    `${base}/reviewSubmissions/${submission.id}`,
    {
      data: {
        type: "reviewSubmissions",
        id: submission.id,
        attributes: {
          submitted: true
        }
      }
    }
  ) : null;

  const after = fetchSubmissions();

  return JSON.stringify({
    before: summarize(before),
    submitResult: submitResult && {
      status: submitResult.status,
      data: submitResult.response.data && {
        id: submitResult.response.data.id,
        type: submitResult.response.data.type,
        attributes: submitResult.response.data.attributes
      },
      errors: submitResult.response.errors
    },
    after: summarize(after)
  }, null, 2);
})();
