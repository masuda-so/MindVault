(() => {
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const screenshots = [
    { label: "Pro Monthly", id: "d0841138-4312-43ef-bbc1-03aaeac65c19" },
    { label: "Team Monthly", id: "74fcfa2b-89f6-4e96-9218-017007e28907" }
  ];

  function request(method, url, body) {
    const xhr = new XMLHttpRequest();
    xhr.open(method, url, false);
    xhr.withCredentials = true;
    xhr.setRequestHeader("Content-Type", "application/vnd.api+json");
    xhr.setRequestHeader("Accept", "application/vnd.api+json");
    xhr.send(body ? JSON.stringify(body) : null);

    let response;
    try {
      response = JSON.parse(xhr.responseText || "{}");
    } catch {
      response = xhr.responseText;
    }

    return { method, url, status: xhr.status, response };
  }

  const results = [];
  for (const screenshot of screenshots) {
    const result = request("PATCH", `${base}/subscriptionAppStoreReviewScreenshots/${screenshot.id}`, {
      data: {
        type: "subscriptionAppStoreReviewScreenshots",
        id: screenshot.id,
        attributes: {
          uploaded: true
        }
      }
    });
    results.push({
      label: screenshot.label,
      screenshotId: screenshot.id,
      status: result.status,
      assetDeliveryState: result.response.data?.attributes?.assetDeliveryState || null,
      imageAsset: result.response.data?.attributes?.imageAsset || null,
      error: result.response.errors || null
    });
  }

  return JSON.stringify(results, null, 2);
})();
