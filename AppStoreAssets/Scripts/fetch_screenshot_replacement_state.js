(() => {
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const apps = [
    { name: "MindVault", id: "6776897058" },
    { name: "SmallThanksDiary", id: "6766864082" }
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

    if (xhr.status < 200 || xhr.status >= 300) {
      throw new Error(JSON.stringify({ method, url, status: xhr.status, response }, null, 2));
    }
    return response;
  }

  const result = {};
  for (const app of apps) {
    const versions = request(
      "GET",
      `${base}/apps/${app.id}/appStoreVersions?include=appStoreVersionLocalizations&limit=20&limit[appStoreVersionLocalizations]=10`
    );
    const included = versions.included || [];
    const localizationsById = Object.fromEntries(
      included
        .filter((item) => item.type === "appStoreVersionLocalizations")
        .map((item) => [item.id, item])
    );

    result[app.name] = (versions.data || []).map((version) => {
      const locRefs = version.relationships?.appStoreVersionLocalizations?.data || [];
      const localizations = locRefs.map((ref) => {
        const loc = localizationsById[ref.id] || { id: ref.id, attributes: {} };
        const sets = request(
          "GET",
          `${base}/appStoreVersionLocalizations/${ref.id}/appScreenshotSets?include=appScreenshots&limit[appScreenshots]=50`
        );
        const screenshotsBySet = {};
        for (const set of sets.data || []) {
          screenshotsBySet[set.id] = {
            id: set.id,
            displayType: set.attributes?.screenshotDisplayType,
            screenshots: []
          };
        }
        for (const shot of sets.included || []) {
          if (shot.type !== "appScreenshots") continue;
          const setId = (sets.data || []).find((set) =>
            (set.relationships?.appScreenshots?.data || []).some((item) => item.id === shot.id)
          )?.id;
          if (setId && screenshotsBySet[setId]) {
            screenshotsBySet[setId].screenshots.push({
              id: shot.id,
              fileName: shot.attributes?.fileName,
              fileSize: shot.attributes?.fileSize,
              state: shot.attributes?.assetDeliveryState?.state,
              uploaded: shot.attributes?.uploaded
            });
          }
        }
        return {
          id: ref.id,
          locale: loc.attributes?.locale,
          screenshots: Object.values(screenshotsBySet)
        };
      });

      return {
        id: version.id,
        versionString: version.attributes?.versionString,
        platform: version.attributes?.platform,
        appStoreState: version.attributes?.appStoreState,
        localizations
      };
    });
  }

  return JSON.stringify(result, null, 2);
})();
