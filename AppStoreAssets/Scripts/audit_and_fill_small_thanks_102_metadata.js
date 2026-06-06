(() => {
  const APP_ID = "6766864082";
  const VERSION_STRING = "1.0.2";
  const LOCALE = "ja";
  const base = "https://appstoreconnect.apple.com/iris/v1";

  const fillValues = {
    promotionalText:
      "小さな感謝を写真とメモでやさしく記録。連続記録、達成バッジ、書き出し、ふりかえりを通じて、前向きな習慣を無理なく続けられます。",
    whatsNew:
      "App Storeのスクリーンショットを更新し、記録、達成バッジ、ふりかえり、書き出し、Premium機能がより分かりやすく伝わるようにしました。アプリ本体の動作に変更はありません。"
  };

  try {

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

  function findVersionAndLocalization() {
    const versions = request(
      "GET",
      `${base}/apps/${APP_ID}/appStoreVersions?include=appStoreVersionLocalizations,build&limit=20&limit[appStoreVersionLocalizations]=10`
    );
    const locsById = Object.fromEntries((versions.included || [])
      .filter((item) => item.type === "appStoreVersionLocalizations")
      .map((item) => [item.id, item]));
    const buildsById = Object.fromEntries((versions.included || [])
      .filter((item) => item.type === "builds")
      .map((item) => [item.id, item]));

    const version = (versions.data || []).find((item) =>
      item.attributes?.platform === "IOS" &&
      item.attributes?.versionString === VERSION_STRING
    );
    if (!version) throw new Error(`Version not found: ${VERSION_STRING}`);

    const locRef = (version.relationships?.appStoreVersionLocalizations?.data || [])
      .find((ref) => locsById[ref.id]?.attributes?.locale === LOCALE);
    if (!locRef) throw new Error(`Localization not found: ${LOCALE}`);

    const buildRef = version.relationships?.build?.data;
    return {
      version,
      localization: locsById[locRef.id],
      build: buildRef ? buildsById[buildRef.id] || { id: buildRef.id } : null
    };
  }

  function screenshotSummary(localizationId) {
    const listing = request(
      "GET",
      `${base}/appStoreVersionLocalizations/${localizationId}/appScreenshotSets?include=appScreenshots&limit[appScreenshots]=50`
    );
    return (listing.data || []).map((set) => {
      const ids = new Set((set.relationships?.appScreenshots?.data || []).map((item) => item.id));
      const screenshots = (listing.included || [])
        .filter((item) => item.type === "appScreenshots" && ids.has(item.id))
        .map((item) => ({
          id: item.id,
          fileName: item.attributes?.fileName,
          fileSize: item.attributes?.fileSize,
          state: item.attributes?.assetDeliveryState?.state
        }))
        .sort((a, b) => (a.fileName || "").localeCompare(b.fileName || ""));
      return {
        id: set.id,
        displayType: set.attributes?.screenshotDisplayType,
        count: screenshots.length,
        incomplete: screenshots.filter((item) => item.state !== "COMPLETE"),
        screenshots
      };
    });
  }

  function reviewDetail(versionId) {
    const response = request("GET", `${base}/appStoreVersions/${versionId}/appStoreReviewDetail`);
    return response.data || null;
  }

  function latestBuilds() {
    const response = request(
      "GET",
      `${base}/apps/${APP_ID}/builds?limit=10&fields[builds]=version,processingState,uploadedDate,expired,usesNonExemptEncryption`
    );
    return (response.data || []).map((item) => ({
      id: item.id,
      version: item.attributes?.version,
      processingState: item.attributes?.processingState,
      uploadedDate: item.attributes?.uploadedDate,
      expired: item.attributes?.expired,
      usesNonExemptEncryption: item.attributes?.usesNonExemptEncryption
    }));
  }

  function appInfoSummary() {
    const response = request(
      "GET",
      `${base}/apps/${APP_ID}/appInfos?include=appInfoLocalizations,primaryCategory,secondaryCategory&limit[appInfoLocalizations]=10`
    );
    return {
      data: (response.data || []).map((item) => ({
        id: item.id,
        appStoreState: item.attributes?.appStoreState
      })),
      localizations: (response.included || [])
        .filter((item) => item.type === "appInfoLocalizations")
        .map((item) => ({
          id: item.id,
          locale: item.attributes?.locale,
          name: item.attributes?.name,
          subtitle: item.attributes?.subtitle,
          privacyPolicyUrl: item.attributes?.privacyPolicyUrl,
          privacyChoicesUrl: item.attributes?.privacyChoicesUrl
        })),
      categories: (response.included || [])
        .filter((item) => item.type === "appCategories")
        .map((item) => ({ id: item.id, name: item.attributes?.name }))
    };
  }

  function privacySummary() {
    let publishState = null;
    try {
      publishState = request("GET", `${base}/appDataUsagesPublishState/${APP_ID}`);
    } catch (error) {
      publishState = { error: String(error) };
    }
    let usages = { data: [] };
    try {
      usages = request("GET", `${base}/apps/${APP_ID}/appDataUsages?include=dataProtection&limit=200`);
    } catch (error) {
      usages = { data: [], error: String(error) };
    }
    return {
      published: publishState.data?.attributes?.published,
      lastPublished: publishState.data?.attributes?.lastPublished,
      publishStateError: publishState.error,
      usageError: usages.error,
      usageCount: (usages.data || []).length,
      dataProtections: (usages.data || []).map((usage) => usage.relationships?.dataProtection?.data?.id)
    };
  }

  function subscriptionSummary() {
    const response = request(
      "GET",
      `${base}/apps/${APP_ID}/subscriptionGroups?include=subscriptions,subscriptionGroupLocalizations&limit[subscriptions]=50&limit[subscriptionGroupLocalizations]=10`
    );
    return {
      groups: (response.data || []).map((group) => ({
        id: group.id,
        referenceName: group.attributes?.referenceName,
        subscriptionCount: group.relationships?.subscriptions?.meta?.paging?.total
      })),
      subscriptions: (response.included || [])
        .filter((item) => item.type === "subscriptions")
        .map((item) => ({
          id: item.id,
          name: item.attributes?.name,
          productId: item.attributes?.productId,
          state: item.attributes?.state,
          submitWithNextAppStoreVersion: item.attributes?.submitWithNextAppStoreVersion,
          isAppStoreReviewInProgress: item.attributes?.isAppStoreReviewInProgress
        }))
    };
  }

  const before = findVersionAndLocalization();
  const attrs = before.localization.attributes || {};
  const patchAttrs = {};
  const filled = [];
  if (!attrs.promotionalText || !attrs.promotionalText.trim()) {
    patchAttrs.promotionalText = fillValues.promotionalText;
    filled.push("promotionalText");
  }
  if (!attrs.whatsNew || !attrs.whatsNew.trim()) {
    patchAttrs.whatsNew = fillValues.whatsNew;
    filled.push("whatsNew");
  }

  let patchResponse = null;
  if (Object.keys(patchAttrs).length) {
    patchResponse = request("PATCH", `${base}/appStoreVersionLocalizations/${before.localization.id}`, {
      data: {
        type: "appStoreVersionLocalizations",
        id: before.localization.id,
        attributes: patchAttrs
      }
    });
  }

  const after = findVersionAndLocalization();
  const review = reviewDetail(after.version.id);

  return JSON.stringify({
    target: "SmallThanksDiary",
    appId: APP_ID,
    versionId: after.version.id,
    versionString: after.version.attributes?.versionString,
    appStoreState: after.version.attributes?.appStoreState,
    appVersionState: after.version.attributes?.appVersionState,
    releaseType: after.version.attributes?.releaseType,
    copyright: after.version.attributes?.copyright,
    usesIdfa: after.version.attributes?.usesIdfa,
    build: after.build ? {
      id: after.build.id,
      version: after.build.attributes?.version,
      processingState: after.build.attributes?.processingState,
      uploadedDate: after.build.attributes?.uploadedDate,
      expired: after.build.attributes?.expired,
      usesNonExemptEncryption: after.build.attributes?.usesNonExemptEncryption
    } : null,
    localizationId: after.localization.id,
    filled,
    patchStatus: patchResponse ? "patched" : "no_patch_needed",
    localization: {
      locale: after.localization.attributes?.locale,
      promotionalText: after.localization.attributes?.promotionalText,
      descriptionLength: (after.localization.attributes?.description || "").length,
      whatsNew: after.localization.attributes?.whatsNew,
      keywords: after.localization.attributes?.keywords,
      supportUrl: after.localization.attributes?.supportUrl,
      marketingUrl: after.localization.attributes?.marketingUrl
    },
    screenshots: screenshotSummary(after.localization.id),
    reviewDetail: review ? {
      id: review.id,
      contactFirstNamePresent: Boolean(review.attributes?.contactFirstName),
      contactLastNamePresent: Boolean(review.attributes?.contactLastName),
      contactPhonePresent: Boolean(review.attributes?.contactPhone),
      contactEmailPresent: Boolean(review.attributes?.contactEmail),
      demoAccountRequired: review.attributes?.demoAccountRequired,
      demoAccountNamePresent: Boolean(review.attributes?.demoAccountName),
      demoAccountPasswordPresent: Boolean(review.attributes?.demoAccountPassword),
      notesLength: (review.attributes?.notes || "").length
    } : null,
    latestBuilds: latestBuilds(),
    appInfo: appInfoSummary(),
    privacy: privacySummary(),
    subscriptions: subscriptionSummary()
  }, null, 2);
  } catch (error) {
    return JSON.stringify({
      ok: false,
      error: String(error),
      stack: error && error.stack
    }, null, 2);
  }
})();
