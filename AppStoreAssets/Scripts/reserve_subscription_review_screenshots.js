(() => {
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const file = {
    localPath: "AppStoreAssets/Screenshots/Subscription/review-plan.jpg",
    fileName: "mindvault-subscription-review-plan.jpg",
    fileSize: 283236
  };
  const subscriptions = [
    { label: "Pro Monthly", id: "6777127690" },
    { label: "Team Monthly", id: "6777126997" }
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

  function createReservation(subscription) {
    const result = request("POST", `${base}/subscriptionAppStoreReviewScreenshots`, {
      data: {
        type: "subscriptionAppStoreReviewScreenshots",
        attributes: {
          fileName: file.fileName,
          fileSize: file.fileSize
        },
        relationships: {
          subscription: {
            data: { type: "subscriptions", id: subscription.id }
          }
        }
      }
    });

    return {
      label: subscription.label,
      subscriptionId: subscription.id,
      status: result.status,
      localPath: file.localPath,
      fileName: file.fileName,
      screenshotId: result.response.data?.id || null,
      uploadOperations: result.response.data?.attributes?.uploadOperations || [],
      assetDeliveryState: result.response.data?.attributes?.assetDeliveryState || null,
      error: result.response.errors || null
    };
  }

  return JSON.stringify(subscriptions.map(createReservation), null, 2);
})();
