(() => {
  const APP_ID = "6776897058";
  const VERSION_ID = "9f074ce3-67e3-4dc0-98b4-e6a92b0893e6";
  const BUILD_ID = "3f45871a-71e9-4d7f-b386-db229b3dc6cd";

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

  const v1 = "https://appstoreconnect.apple.com/iris/v1";
  const v2 = "https://appstoreconnect.apple.com/iris/v2";
  const version = request("GET", `${v1}/appStoreVersions/${VERSION_ID}?include=build&fields[appStoreVersions]=appStoreState,appVersionState,versionString,releaseType,storeIcon,usesIdfa,build&fields[builds]=version,processingState,usesNonExemptEncryption`);
  const app = request("GET", `${v1}/apps/${APP_ID}?fields[apps]=contentRightsDeclaration`);
  const priceSchedule = request("GET", `${v1}/appPriceSchedules/${APP_ID}?include=baseTerritory,manualPrices&limit[manualPrices]=50`);
  const reviewSubmissions = request("GET", `${v1}/apps/${APP_ID}/reviewSubmissions?include=appStoreVersionForReview,items&limit=2000&limit[items]=200`);
  const subscriptionGroups = request("GET", `${v1}/apps/${APP_ID}/subscriptionGroups?include=subscriptions,subscriptionGroupLocalizations&limit[subscriptions]=50&limit[subscriptionGroupLocalizations]=10`);
  const privacyState = request("GET", `${v1}/appDataUsagesPublishState/${APP_ID}`);
  const appDataUsages = request("GET", `${v1}/apps/${APP_ID}/appDataUsages?include=dataProtection&limit=200`);
  const appAvailability = request("GET", `${v2}/appAvailabilities/${APP_ID}?include=territoryAvailabilities&limit[territoryAvailabilities]=200`);

  const versionIncluded = version.response.included || [];
  const build = versionIncluded.find((item) => item.type === "builds") || null;
  const subscriptions = (subscriptionGroups.response.included || [])
    .filter((item) => item.type === "subscriptions")
    .map((item) => ({
      id: item.id,
      name: item.attributes && item.attributes.name,
      productId: item.attributes && item.attributes.productId,
      state: item.attributes && item.attributes.state,
      submitWithNextAppStoreVersion: item.attributes && item.attributes.submitWithNextAppStoreVersion,
      isAppStoreReviewInProgress: item.attributes && item.attributes.isAppStoreReviewInProgress
    }));
  const reviewDrafts = (reviewSubmissions.response.data || []).map((submission) => ({
    id: submission.id,
    state: submission.attributes && submission.attributes.state,
    submittedDate: submission.attributes && submission.attributes.submittedDate,
    appStoreVersionForReview: submission.relationships && submission.relationships.appStoreVersionForReview && submission.relationships.appStoreVersionForReview.data,
    itemCount: submission.relationships && submission.relationships.items && submission.relationships.items.meta && submission.relationships.items.meta.paging && submission.relationships.items.meta.paging.total
  }));
  const appPrice = (priceSchedule.response.included || [])
    .filter((item) => item.type === "appPrices")
    .map((item) => ({
      id: item.id,
      startDate: item.attributes && item.attributes.startDate,
      endDate: item.attributes && item.attributes.endDate,
      appPricePoint: item.relationships && item.relationships.appPricePoint && item.relationships.appPricePoint.data
    }));
  const dataProtectionIds = (appDataUsages.response.data || []).map((usage) => (
    usage.relationships &&
    usage.relationships.dataProtection &&
    usage.relationships.dataProtection.data &&
    usage.relationships.dataProtection.data.id
  ));
  const territoryAvailabilities = (appAvailability.response.included || [])
    .filter((item) => item.type === "territoryAvailabilities");

  return JSON.stringify({
    app: {
      status: app.status,
      contentRightsDeclaration: app.response.data && app.response.data.attributes && app.response.data.attributes.contentRightsDeclaration
    },
    version: {
      status: version.status,
      id: VERSION_ID,
      attributes: version.response.data && version.response.data.attributes,
      build: build && {
        id: build.id,
        version: build.attributes && build.attributes.version,
        processingState: build.attributes && build.attributes.processingState,
        usesNonExemptEncryption: build.attributes && build.attributes.usesNonExemptEncryption
      }
    },
    appPriceSchedule: {
      status: priceSchedule.status,
      id: priceSchedule.response.data && priceSchedule.response.data.id,
      baseTerritory: priceSchedule.response.included && priceSchedule.response.included.find((item) => item.type === "territories"),
      manualPrices: appPrice,
      errors: priceSchedule.response.errors
    },
    appAvailability: {
      status: appAvailability.status,
      includedTerritoryAvailabilityCount: territoryAvailabilities.length,
      sample: territoryAvailabilities.slice(0, 5).map((item) => ({ id: item.id, attributes: item.attributes })),
      errors: appAvailability.response.errors
    },
    privacy: {
      publishStatus: privacyState.status,
      published: privacyState.response.data && privacyState.response.data.attributes && privacyState.response.data.attributes.published,
      lastPublished: privacyState.response.data && privacyState.response.data.attributes && privacyState.response.data.attributes.lastPublished,
      dataProtections: dataProtectionIds
    },
    subscriptions,
    reviewSubmissions: {
      status: reviewSubmissions.status,
      drafts: reviewDrafts,
      included: (reviewSubmissions.response.included || []).map((item) => ({
        type: item.type,
        id: item.id,
        attributes: item.attributes
      }))
    }
  }, null, 2);
})();
