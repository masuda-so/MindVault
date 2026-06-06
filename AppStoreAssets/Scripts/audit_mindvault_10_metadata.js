(() => {
  const APP_ID = "6776897058";
  const VERSION_STRING = "1.0";
  const LOCALE = "ja";
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

    if (xhr.status < 200 || xhr.status >= 300) {
      throw new Error(JSON.stringify({ method, url, status: xhr.status, response }, null, 2));
    }
    return response;
  }

  function safe(label, fn) {
    try {
      return { ok: true, value: fn() };
    } catch (error) {
      return { ok: false, error: String(error) };
    }
  }

  function findVersionAndLocalization() {
    const versions = request(
      "GET",
      `${base}/apps/${APP_ID}/appStoreVersions?include=appStoreVersionLocalizations,build,ageRatingDeclaration&limit=20&limit[appStoreVersionLocalizations]=10`
    );
    const includedById = Object.fromEntries((versions.included || []).map((item) => [item.id, item]));
    const locsById = Object.fromEntries((versions.included || [])
      .filter((item) => item.type === "appStoreVersionLocalizations")
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
    const ageRef = version.relationships?.ageRatingDeclaration?.data;
    return {
      version,
      localization: locsById[locRef.id],
      build: buildRef ? includedById[buildRef.id] || { id: buildRef.id } : null,
      ageRatingDeclaration: ageRef ? includedById[ageRef.id] || { id: ageRef.id } : null
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

  function reviewSubmissionSummary() {
    const response = request(
      "GET",
      `${base}/apps/${APP_ID}/reviewSubmissions?include=appStoreVersionForReview,items&limit=2000&limit[items]=200`
    );
    return {
      submissions: (response.data || []).map((submission) => ({
        id: submission.id,
        state: submission.attributes?.state,
        submittedDate: submission.attributes?.submittedDate,
        appStoreVersionForReview: submission.relationships?.appStoreVersionForReview?.data,
        itemCount: submission.relationships?.items?.meta?.paging?.total
      })),
      included: (response.included || []).map((item) => ({
        type: item.type,
        id: item.id,
        attributes: item.attributes,
        relationships: item.relationships
      }))
    };
  }

  function priceAndRightsSummary() {
    const app = request("GET", `${base}/apps/${APP_ID}?fields[apps]=contentRightsDeclaration`);
    const price = request("GET", `${base}/appPriceSchedules/${APP_ID}?include=baseTerritory,manualPrices&limit[manualPrices]=50`);
    return {
      contentRightsDeclaration: app.data?.attributes?.contentRightsDeclaration,
      baseTerritory: (price.included || []).find((item) => item.type === "territories")?.id,
      manualPriceCount: (price.included || []).filter((item) => item.type === "appPrices").length
    };
  }

  const found = findVersionAndLocalization();
  const locAttrs = found.localization.attributes || {};
  const review = reviewDetail(found.version.id);
  const missing = [];

  const requiredLocalization = {
    promotionalText: locAttrs.promotionalText,
    description: locAttrs.description,
    whatsNew: locAttrs.whatsNew,
    keywords: locAttrs.keywords,
    supportUrl: locAttrs.supportUrl,
    marketingUrl: locAttrs.marketingUrl
  };
  Object.entries(requiredLocalization).forEach(([key, value]) => {
    if (!value || !String(value).trim()) missing.push(`localization.${key}`);
  });
  if (!found.version.attributes?.copyright) missing.push("version.copyright");
  if (found.version.attributes?.usesIdfa === null || found.version.attributes?.usesIdfa === undefined) missing.push("version.usesIdfa");
  if (!found.build) missing.push("version.build");
  if (!review?.attributes?.contactFirstName) missing.push("review.contactFirstName");
  if (!review?.attributes?.contactLastName) missing.push("review.contactLastName");
  if (!review?.attributes?.contactPhone) missing.push("review.contactPhone");
  if (!review?.attributes?.contactEmail) missing.push("review.contactEmail");
  if (!review?.attributes?.notes) missing.push("review.notes");

  const appInfo = appInfoSummary();
  const jaAppInfo = appInfo.localizations.find((item) => item.locale === LOCALE);
  if (!jaAppInfo?.name) missing.push("appInfo.name");
  if (!jaAppInfo?.subtitle) missing.push("appInfo.subtitle");
  if (!jaAppInfo?.privacyPolicyUrl) missing.push("appInfo.privacyPolicyUrl");

  return JSON.stringify({
    target: "MindVault",
    appId: APP_ID,
    versionId: found.version.id,
    versionString: found.version.attributes?.versionString,
    appStoreState: found.version.attributes?.appStoreState,
    appVersionState: found.version.attributes?.appVersionState,
    releaseType: found.version.attributes?.releaseType,
    copyright: found.version.attributes?.copyright,
    usesIdfa: found.version.attributes?.usesIdfa,
    build: found.build ? {
      id: found.build.id,
      version: found.build.attributes?.version,
      processingState: found.build.attributes?.processingState,
      usesNonExemptEncryption: found.build.attributes?.usesNonExemptEncryption
    } : null,
    localizationId: found.localization.id,
    localization: {
      locale: locAttrs.locale,
      promotionalText: locAttrs.promotionalText,
      descriptionLength: (locAttrs.description || "").length,
      whatsNew: locAttrs.whatsNew,
      keywords: locAttrs.keywords,
      supportUrl: locAttrs.supportUrl,
      marketingUrl: locAttrs.marketingUrl
    },
    screenshots: screenshotSummary(found.localization.id),
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
    ageRatingDeclarationPresent: Boolean(found.ageRatingDeclaration),
    appInfo,
    priceAndRights: priceAndRightsSummary(),
    subscriptions: subscriptionSummary(),
    reviewSubmissions: reviewSubmissionSummary(),
    missing
  }, null, 2);
})();
