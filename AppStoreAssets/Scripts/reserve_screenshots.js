(() => {
  const LOCALIZATION_ID = "0ef30351-d1ba-41ab-81ee-b20b8105a4ff";
  const base = "https://appstoreconnect.apple.com/iris/v1";

  const screenshotSets = [
    {
      displayType: "APP_IPHONE_65",
      files: [
        { localPath: "AppStoreAssets/Screenshots/iPhone/01-graph.png", fileName: "01-graph.png", fileSize: 2267481 },
        { localPath: "AppStoreAssets/Screenshots/iPhone/02-notes.png", fileName: "02-notes.png", fileSize: 419203 },
        { localPath: "AppStoreAssets/Screenshots/iPhone/03-search.png", fileName: "03-search.png", fileSize: 463064 },
        { localPath: "AppStoreAssets/Screenshots/iPhone/04-settings-plan.png", fileName: "04-settings-plan.png", fileSize: 428686 }
      ]
    },
    {
      displayType: "APP_IPAD_PRO_3GEN_129",
      files: [
        { localPath: "AppStoreAssets/Screenshots/iPad/01-ipad-graph.png", fileName: "01-ipad-graph.png", fileSize: 2342020 }
      ]
    }
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

  function createSet(displayType) {
    return request("POST", `${base}/appScreenshotSets`, {
      data: {
        type: "appScreenshotSets",
        attributes: {
          screenshotDisplayType: displayType
        },
        relationships: {
          appStoreVersionLocalization: {
            data: { type: "appStoreVersionLocalizations", id: LOCALIZATION_ID }
          }
        }
      }
    }).data;
  }

  function createScreenshot(setId, file) {
    return request("POST", `${base}/appScreenshots`, {
      data: {
        type: "appScreenshots",
        attributes: {
          fileName: file.fileName,
          fileSize: file.fileSize
        },
        relationships: {
          appScreenshotSet: {
            data: { type: "appScreenshotSets", id: setId }
          }
        }
      }
    }).data;
  }

  const reservations = [];

  for (const setSpec of screenshotSets) {
    const set = createSet(setSpec.displayType);
    for (const file of setSpec.files) {
      const screenshot = createScreenshot(set.id, file);
      reservations.push({
        displayType: setSpec.displayType,
        setId: set.id,
        screenshotId: screenshot.id,
        localPath: file.localPath,
        fileName: file.fileName,
        fileSize: file.fileSize,
        uploadOperations: screenshot.attributes.uploadOperations,
        assetDeliveryState: screenshot.attributes.assetDeliveryState
      });
    }
  }

  return JSON.stringify(reservations, null, 2);
})();
