(() => {
  const SET_ID = "ce50d810-9cb5-4413-91b3-e03df38ac0cc";
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const files = [
    { localPath: "AppStoreAssets/Screenshots/iPhone65/01-graph.png", fileName: "01-graph.png", fileSize: 2296072 },
    { localPath: "AppStoreAssets/Screenshots/iPhone65/02-notes.png", fileName: "02-notes.png", fileSize: 536058 },
    { localPath: "AppStoreAssets/Screenshots/iPhone65/03-search.png", fileName: "03-search.png", fileSize: 582266 },
    { localPath: "AppStoreAssets/Screenshots/iPhone65/04-settings-plan.png", fileName: "04-settings-plan.png", fileSize: 525680 }
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
