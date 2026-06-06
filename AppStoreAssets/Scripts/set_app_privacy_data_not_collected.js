(() => {
  const appId = "6776897058";
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

  const existing = request(
    "GET",
    `${base}/apps/${appId}/dataUsages?include=category,purpose,grouping,dataProtection&limit=500`
  );
  const hasDataNotCollected = (existing.response.data || []).some(
    (item) => item.relationships?.dataProtection?.data?.id === "DATA_NOT_COLLECTED"
  );

  const createResult = hasDataNotCollected ? {
    status: 200,
    response: { skipped: "DATA_NOT_COLLECTED already exists" }
  } : request("POST", `${base}/appDataUsages`, {
    data: {
      type: "appDataUsages",
      relationships: {
        dataProtection: {
          data: { type: "appDataUsageDataProtections", id: "DATA_NOT_COLLECTED" }
        },
        app: {
          data: { type: "apps", id: appId }
        }
      }
    }
  });

  const after = request(
    "GET",
    `${base}/apps/${appId}/dataUsages?include=category,purpose,grouping,dataProtection&limit=500`
  );

  return JSON.stringify({
    beforeCount: existing.response.data?.length ?? null,
    createStatus: createResult.status,
    createResponse: createResult.response.errors ? createResult.response : {
      id: createResult.response.data?.id || null,
      skipped: createResult.response.skipped || null,
      dataProtection: createResult.response.data?.relationships?.dataProtection?.data?.id || null
    },
    afterCount: after.response.data?.length ?? null,
    afterDataProtections: (after.response.data || []).map((item) => ({
      id: item.id,
      dataProtection: item.relationships?.dataProtection?.data?.id || null,
      category: item.relationships?.category?.data?.id || null,
      purpose: item.relationships?.purpose?.data?.id || null
    })),
    errors: createResult.response.errors || after.response.errors || null
  }, null, 2);
})();
