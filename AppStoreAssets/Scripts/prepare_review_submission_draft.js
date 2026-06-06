(() => {
  const APP_ID = "6776897058";
  const VERSION_ID = "9f074ce3-67e3-4dc0-98b4-e6a92b0893e6";
  const SUBSCRIPTIONS = [
    { id: "6777127690", name: "Pro Monthly" },
    { id: "6777126997", name: "Team Monthly" }
  ];

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

  function findDraftSubmission() {
    const result = request(
      "GET",
      `${base}/apps/${APP_ID}/reviewSubmissions?include=appStoreVersionForReview,items,lastUpdatedByActor,submittedByActor,createdByActor&limit=2000&limit[items]=200`
    );
    const submissions = result.response.data || [];
    return {
      result,
      submission: submissions.find((submission) => {
        const state = submission.attributes && submission.attributes.state;
        return state === "PREPARE_FOR_SUBMISSION" || state === "READY_FOR_REVIEW";
      }) || submissions[0] || null
    };
  }

  function createSubmission() {
    return request(
      "POST",
      `${base}/reviewSubmissions`,
      {
        data: {
          type: "reviewSubmissions",
          attributes: { platform: "IOS" },
          relationships: {
            app: { data: { type: "apps", id: APP_ID } }
          }
        }
      }
    );
  }

  function addVersionToSubmission(submissionId) {
    return request(
      "POST",
      `${base}/reviewSubmissionItems`,
      {
        data: {
          type: "reviewSubmissionItems",
          relationships: {
            reviewSubmission: { data: { type: "reviewSubmissions", id: submissionId } },
            appStoreVersion: { data: { type: "appStoreVersions", id: VERSION_ID } }
          }
        }
      }
    );
  }

  function submitSubscriptionWithVersion(subscriptionId) {
    return request(
      "POST",
      `${base}/subscriptionSubmissions`,
      {
        data: {
          type: "subscriptionSubmissions",
          attributes: { submitWithNextAppStoreVersion: true },
          relationships: {
            subscription: { data: { type: "subscriptions", id: subscriptionId } }
          }
        }
      }
    );
  }

  const base = "https://appstoreconnect.apple.com/iris/v1";
  const before = findDraftSubmission();
  let submission = before.submission;
  let createResult = null;

  if (!submission) {
    createResult = createSubmission();
    submission = createResult.response && createResult.response.data;
  }

  const submissionId = submission && submission.id;
  const versionItemResult = submissionId ? addVersionToSubmission(submissionId) : null;
  const subscriptionResults = SUBSCRIPTIONS.map((subscription) => ({
    ...subscription,
    result: submitSubscriptionWithVersion(subscription.id)
  }));
  const after = findDraftSubmission();

  return JSON.stringify({
    before: {
      status: before.result.status,
      count: (before.result.response.data || []).length,
      submission: before.submission && {
        id: before.submission.id,
        state: before.submission.attributes && before.submission.attributes.state
      }
    },
    createResult: createResult && {
      status: createResult.status,
      data: createResult.response.data,
      errors: createResult.response.errors
    },
    submissionId,
    versionItemResult: versionItemResult && {
      status: versionItemResult.status,
      data: versionItemResult.response.data,
      errors: versionItemResult.response.errors
    },
    subscriptionResults: subscriptionResults.map((entry) => ({
      id: entry.id,
      name: entry.name,
      status: entry.result.status,
      data: entry.result.response.data,
      errors: entry.result.response.errors
    })),
    after: {
      status: after.result.status,
      count: (after.result.response.data || []).length,
      submission: after.submission && {
        id: after.submission.id,
        state: after.submission.attributes && after.submission.attributes.state,
        itemRefs: after.submission.relationships && after.submission.relationships.items && after.submission.relationships.items.data
      },
      included: (after.result.response.included || []).map((item) => ({
        type: item.type,
        id: item.id,
        attributes: item.attributes,
        relationships: item.relationships
      }))
    }
  }, null, 2);
})();
