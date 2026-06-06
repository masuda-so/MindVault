(() => {
  const SET_ID = "6680bd29-5341-4cc0-86b0-fb6dc3bb7ae6";
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const files = [
    { localPath: "AppStoreAssets/PromotionalImages/ja-iPhone65/02-notes-grow.jpg", fileName: "02-notes-grow.jpg", fileSize: 285952 },
    { localPath: "AppStoreAssets/PromotionalImages/ja-iPhone65/03-local-search.jpg", fileName: "03-local-search.jpg", fileSize: 316506 },
    { localPath: "AppStoreAssets/PromotionalImages/ja-iPhone65/04-privacy-plan.jpg", fileName: "04-privacy-plan.jpg", fileSize: 277473 }
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

    if (xhr.status < 200 || xhr.status >= 300) {
      throw new Error(JSON.stringify({ method, url, status: xhr.status, response }, null, 2));
    }

    return response;
  }

  const reservations = [];
  for (const file of files) {
    const screenshot = request("POST", `${base}/appScreenshots`, {
      data: {
        type: "appScreenshots",
        attributes: {
          fileName: file.fileName,
          fileSize: file.fileSize
        },
        relationships: {
          appScreenshotSet: {
            data: { type: "appScreenshotSets", id: SET_ID }
          }
        }
      }
    }).data;

    reservations.push({
      displayType: "APP_IPHONE_65",
      setId: SET_ID,
      screenshotId: screenshot.id,
      localPath: file.localPath,
      fileName: file.fileName,
      fileSize: file.fileSize,
      uploadOperations: screenshot.attributes.uploadOperations,
      assetDeliveryState: screenshot.attributes.assetDeliveryState
    });
  }

  return JSON.stringify(reservations, null, 2);
})();
