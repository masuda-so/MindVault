(() => {
  const APP_ID = "6776897058";
  const VERSION_ID = "9f074ce3-67e3-4dc0-98b4-e6a92b0893e6";
  const REVIEW_SUBMISSION_ID = "56bc8dc9-4b2f-4310-a436-661a9380b673";
  const USA_FREE_PRICE_POINT_ID = "eyJzIjoiNjc3Njg5NzA1OCIsInQiOiJVU0EiLCJwIjoiMTAwMDAifQ";

  function request(method, url, body) {
    const xhr = new XMLHttpRequest();
    xhr.open(method, url, false);
    xhr.withCredentials = true;
    xhr.setRequestHeader("Accept", "application/vnd.api+json");
    if (body) {
      xhr.setRequestHeader("Content-Type", "application/vnd.api+json");
    }
    xhr.send(body ? JSON.stringify(body) : null);

    let response;
    try {
      response = JSON.parse(xhr.responseText || "{}");
    } catch {
      response = xhr.responseText;
    }

    return { method, url, status: xhr.status, response };
  }

  const v1 = "https://appstoreconnect.apple.com/iris/v1";
  const beforeApp = request("GET", `${v1}/apps/${APP_ID}?fields[apps]=contentRightsDeclaration`);

  const contentRightsResult = request(
    "PATCH",
    `${v1}/apps/${APP_ID}`,
    {
      data: {
        id: APP_ID,
        type: "apps",
        attributes: {
          contentRightsDeclaration: "DOES_NOT_USE_THIRD_PARTY_CONTENT"
        }
      }
    }
  );

  const priceScheduleResult = request(
    "POST",
    `${v1}/appPriceSchedules`,
    {
      data: {
        type: "appPriceSchedules",
        attributes: {},
        relationships: {
          app: { data: { type: "apps", id: APP_ID } },
          baseTerritory: { data: { type: "territories", id: "USA" } },
          manualPrices: {
            data: [
              { type: "appPrices", id: "${mindvault-usa-free-price}" }
            ]
          }
        }
      },
      included: [
        {
          type: "appPrices",
          id: "${mindvault-usa-free-price}",
          attributes: {
            startDate: null,
            endDate: null
          },
          relationships: {
            appPricePoint: {
              data: { type: "appPricePoints", id: USA_FREE_PRICE_POINT_ID }
            }
          }
        }
      ]
    }
  );

  const versionItemResult = request(
    "POST",
    `${v1}/reviewSubmissionItems`,
    {
      data: {
        type: "reviewSubmissionItems",
        relationships: {
          reviewSubmission: { data: { type: "reviewSubmissions", id: REVIEW_SUBMISSION_ID } },
          appStoreVersion: { data: { type: "appStoreVersions", id: VERSION_ID } }
        }
      }
    }
  );

  const afterApp = request("GET", `${v1}/apps/${APP_ID}?include=appPriceSchedule&fields[apps]=contentRightsDeclaration,appPriceSchedule`);
  const afterReview = request(
    "GET",
    `${v1}/apps/${APP_ID}/reviewSubmissions?include=appStoreVersionForReview,items,lastUpdatedByActor,submittedByActor,createdByActor&limit=2000&limit[items]=200`
  );

  return JSON.stringify({
    beforeApp: {
      status: beforeApp.status,
      attributes: beforeApp.response.data && beforeApp.response.data.attributes,
      errors: beforeApp.response.errors
    },
    contentRightsResult: {
      status: contentRightsResult.status,
      attributes: contentRightsResult.response.data && contentRightsResult.response.data.attributes,
      errors: contentRightsResult.response.errors
    },
    priceScheduleResult: {
      status: priceScheduleResult.status,
      data: priceScheduleResult.response.data,
      errors: priceScheduleResult.response.errors
    },
    versionItemResult: {
      status: versionItemResult.status,
      data: versionItemResult.response.data,
      errors: versionItemResult.response.errors
    },
    afterApp: {
      status: afterApp.status,
      attributes: afterApp.response.data && afterApp.response.data.attributes,
      relationships: afterApp.response.data && afterApp.response.data.relationships,
      included: afterApp.response.included,
      errors: afterApp.response.errors
    },
    afterReview: {
      status: afterReview.status,
      data: afterReview.response.data,
      included: afterReview.response.included,
      errors: afterReview.response.errors
    }
  }, null, 2);
})();
