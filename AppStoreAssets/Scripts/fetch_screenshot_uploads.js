(() => {
  const LOCALIZATION_ID = "0ef30351-d1ba-41ab-81ee-b20b8105a4ff";
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const localPaths = {
    "01-graph-connections.jpg": "AppStoreAssets/PromotionalImages/ja-iPhone65/01-graph-connections.jpg",
    "02-notes-grow.jpg": "AppStoreAssets/PromotionalImages/ja-iPhone65/02-notes-grow.jpg",
    "03-local-search.jpg": "AppStoreAssets/PromotionalImages/ja-iPhone65/03-local-search.jpg",
    "04-privacy-plan.jpg": "AppStoreAssets/PromotionalImages/ja-iPhone65/04-privacy-plan.jpg",
    "01-graph.png": "AppStoreAssets/Screenshots/iPhone65/01-graph.png",
    "02-notes.png": "AppStoreAssets/Screenshots/iPhone65/02-notes.png",
    "03-search.png": "AppStoreAssets/Screenshots/iPhone65/03-search.png",
    "04-settings-plan.png": "AppStoreAssets/Screenshots/iPhone65/04-settings-plan.png",
    "01-ipad-graph.png": "AppStoreAssets/Screenshots/iPad/01-ipad-graph.png"
  };

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

    if (xhr.status < 200 || xhr.status >= 300) {
      throw new Error(JSON.stringify({ method, url, status: xhr.status, response }, null, 2));
    }

    return response;
  }

  const response = request(
    "GET",
    `${base}/appStoreVersionLocalizations/${LOCALIZATION_ID}/appScreenshotSets?include=appScreenshots&limit[appScreenshots]=50`
  );
  const setsByScreenshotId = {};
  for (const set of response.data || []) {
    const ids = set.relationships?.appScreenshots?.data || [];
    for (const item of ids) {
      setsByScreenshotId[item.id] = {
        setId: set.id,
        displayType: set.attributes.screenshotDisplayType
      };
    }
  }

  const uploads = (response.included || [])
    .filter((item) => item.type === "appScreenshots")
    .map((item) => ({
      screenshotId: item.id,
      setId: setsByScreenshotId[item.id]?.setId,
      displayType: setsByScreenshotId[item.id]?.displayType,
      fileName: item.attributes.fileName,
      fileSize: item.attributes.fileSize,
      localPath: localPaths[item.attributes.fileName],
      uploadOperations: item.attributes.uploadOperations,
      assetDeliveryState: item.attributes.assetDeliveryState
    }))
    .sort((a, b) => (a.fileName || "").localeCompare(b.fileName || ""));

  return JSON.stringify(uploads, null, 2);
})();
