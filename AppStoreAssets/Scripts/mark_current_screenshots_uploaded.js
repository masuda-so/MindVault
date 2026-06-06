(() => {
  const LOCALIZATION_ID = "0ef30351-d1ba-41ab-81ee-b20b8105a4ff";
  const base = "https://appstoreconnect.apple.com/iris/v1";

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

  const listing = request(
    "GET",
    `${base}/appStoreVersionLocalizations/${LOCALIZATION_ID}/appScreenshotSets?include=appScreenshots&limit[appScreenshots]=50`
  );
  const screenshots = listing.response.included || [];
  const results = [listing];

  for (const item of screenshots) {
    if (item.type !== "appScreenshots") continue;
    const state = item.attributes?.assetDeliveryState?.state;
    if (state !== "AWAITING_UPLOAD" && state !== "UPLOAD_COMPLETE") continue;

    results.push(request("PATCH", `${base}/appScreenshots/${item.id}`, {
      data: {
        type: "appScreenshots",
        id: item.id,
        attributes: {
          uploaded: true
        }
      }
    }));
  }

  return JSON.stringify(results, null, 2);
})();
