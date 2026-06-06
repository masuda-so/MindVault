(() => {
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const specs = [
    {
      label: "Pro Monthly",
      subscriptionId: "6777127690"
    },
    {
      label: "Team Monthly",
      subscriptionId: "6777126997"
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

    return { method, url, status: xhr.status, response };
  }

  function collectTerritoryIds(subscriptionId) {
    const territoryIds = new Set();
    let next = `${base}/subscriptions/${subscriptionId}/prices?include=territory&limit=200`;
    while (next) {
      const result = request("GET", next);
      if (result.status < 200 || result.status >= 300) {
        throw new Error(JSON.stringify(result, null, 2));
      }
      for (const item of result.response.included || []) {
        if (item.type === "territories") territoryIds.add(item.id);
      }
      next = result.response.links?.next || null;
    }
    return Array.from(territoryIds).sort();
  }

  function setAvailability(spec) {
    const territoryIds = collectTerritoryIds(spec.subscriptionId);
    const result = request("POST", `${base}/subscriptionAvailabilities`, {
      data: {
        type: "subscriptionAvailabilities",
        attributes: {
          availableInNewTerritories: true
        },
        relationships: {
          availableTerritories: {
            data: territoryIds.map((id) => ({ type: "territories", id }))
          },
          subscription: {
            data: { type: "subscriptions", id: spec.subscriptionId }
          }
        }
      }
    });

    return {
      label: spec.label,
      subscriptionId: spec.subscriptionId,
      requestedTerritoryCount: territoryIds.length,
      status: result.status,
      response: result.response.errors ? result.response : {
        id: result.response.data?.id,
        availableInNewTerritories: result.response.data?.attributes?.availableInNewTerritories,
        availableTerritoriesTotal: result.response.data?.relationships?.availableTerritories?.meta?.paging?.total ?? null
      }
    };
  }

  try {
    return JSON.stringify(specs.map(setAvailability), null, 2);
  } catch (error) {
    return JSON.stringify({ ok: false, error: String(error && error.message ? error.message : error) }, null, 2);
  }
})();
