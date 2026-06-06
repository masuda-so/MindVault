(() => {
  const APP_ID = "6776897058";
  const VERSION_ID = "9f074ce3-67e3-4dc0-98b4-e6a92b0893e6";
  const APP_INFO_ID = "3cf0a3b3-ab0c-4e4e-9da0-c3b1bd0c1176";
  const AGE_RATING_ID = "3cf0a3b3-ab0c-4e4e-9da0-c3b1bd0c1176";

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

    return { method, url, status: xhr.status, response };
  }

  const base = "https://appstoreconnect.apple.com/iris/v1";
  const results = {};

  results.version = request(
    "GET",
    `${base}/appStoreVersions/${VERSION_ID}?include=appStoreVersionLocalizations,appStoreReviewDetail,build&limit[appStoreVersionLocalizations]=10`
  );
  results.appInfos = request(
    "GET",
    `${base}/apps/${APP_ID}/appInfos?include=appInfoLocalizations,primaryCategory,secondaryCategory&limit[appInfoLocalizations]=10`
  );
  results.ageRating = request(
    "GET",
    `${base}/ageRatingDeclarations/${AGE_RATING_ID}`
  );
  results.screenshotSets = request(
    "GET",
    `${base}/appStoreVersionLocalizations/0ef30351-d1ba-41ab-81ee-b20b8105a4ff/appScreenshotSets?include=appScreenshots&limit[appScreenshots]=50`
  );
  results.subscriptionGroups = request(
    "GET",
    `${base}/apps/${APP_ID}/subscriptionGroups?include=subscriptions,subscriptionGroupLocalizations&limit[subscriptions]=50&limit[subscriptionGroupLocalizations]=10`
  );
  results.inAppPurchases = request(
    "GET",
    `${base}/apps/${APP_ID}/inAppPurchasesV2?limit=50`
  );

  return JSON.stringify(results, null, 2);
})();
