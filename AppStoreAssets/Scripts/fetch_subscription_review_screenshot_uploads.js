(() => {
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const screenshots = [
    {
      label: "Pro Monthly",
      subscriptionId: "6777127690",
      screenshotId: "d0841138-4312-43ef-bbc1-03aaeac65c19",
      localPath: "AppStoreAssets/Screenshots/Subscription/review-plan.jpg"
    },
    {
      label: "Team Monthly",
      subscriptionId: "6777126997",
      screenshotId: "74fcfa2b-89f6-4e96-9218-017007e28907",
      localPath: "AppStoreAssets/Screenshots/Subscription/review-plan.jpg"
    }
  ];

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

  const results = [];
  for (const screenshot of screenshots) {
    const result = request("GET", `${base}/subscriptionAppStoreReviewScreenshots/${screenshot.screenshotId}`);
    results.push({
      ...screenshot,
      status: result.status,
      fileName: result.response.data?.attributes?.fileName || null,
      fileSize: result.response.data?.attributes?.fileSize || null,
      uploadOperations: result.response.data?.attributes?.uploadOperations || [],
      assetDeliveryState: result.response.data?.attributes?.assetDeliveryState || null,
      error: result.response.errors || null
    });
  }

  return JSON.stringify(results, null, 2);
})();
