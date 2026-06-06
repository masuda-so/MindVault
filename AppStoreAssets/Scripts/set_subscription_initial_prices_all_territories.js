(() => {
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const specs = [
    {
      label: "Pro Monthly",
      subscriptionId: "6777127690",
      baseTerritory: "USA",
      basePricePointId: "eyJzIjoiNjc3NzEyNzY5MCIsInQiOiJVU0EiLCJwIjoiMTAxMjcifQ",
      equalizationsUrl: "https://appstoreconnect.apple.com/iris/v1/subscriptionPricePoints/eyJzIjoiNjc3NzEyNzY5MCIsInQiOiJVU0EiLCJwIjoiMTAxMjcifQ/equalizations"
    },
    {
      label: "Team Monthly",
      subscriptionId: "6777126997",
      baseTerritory: "USA",
      basePricePointId: "eyJzIjoiNjc3NzEyNjk5NyIsInQiOiJVU0EiLCJwIjoiMTAyMjcifQ",
      equalizationsUrl: "https://appstoreconnect.apple.com/iris/v1/subscriptionPricePoints/eyJzIjoiNjc3NzEyNjk5NyIsInQiOiJVU0EiLCJwIjoiMTAyMjcifQ/equalizations"
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

  function collectEqualizedPricePoints(url) {
    const items = [];
    let next = `${url}?include=territory&limit=200`;
    while (next) {
      const result = request("GET", next);
      if (result.status < 200 || result.status >= 300) {
        throw new Error(JSON.stringify(result, null, 2));
      }
      for (const item of result.response.data || []) {
        const territoryId = item.relationships?.territory?.data?.id;
        if (!territoryId) continue;
        items.push({ territoryId, pricePointId: item.id });
      }
      next = result.response.links?.next || null;
    }
    return items;
  }

  function setInitialPrices(spec) {
    const allPrices = [
      { territoryId: spec.baseTerritory, pricePointId: spec.basePricePointId },
      ...collectEqualizedPricePoints(spec.equalizationsUrl)
    ];

    const relationshipData = [];
    const included = [];
    for (const price of allPrices) {
      const localId = "${price-" + price.territoryId.toLowerCase() + "}";
      relationshipData.push({ type: "subscriptionPrices", id: localId });
      included.push({
        type: "subscriptionPrices",
        id: localId,
        relationships: {
          subscriptionPricePoint: {
            data: { type: "subscriptionPricePoints", id: price.pricePointId }
          },
          territory: {
            data: { type: "territories", id: price.territoryId }
          }
        }
      });
    }

    const result = request("PATCH", `${base}/subscriptions/${spec.subscriptionId}`, {
      data: {
        type: "subscriptions",
        id: spec.subscriptionId,
        relationships: {
          prices: {
            data: relationshipData
          }
        }
      },
      included
    });

    return {
      label: spec.label,
      subscriptionId: spec.subscriptionId,
      requestedPriceCount: allPrices.length,
      patchStatus: result.status,
      response: result.response.errors ? result.response : {
        state: result.response.data?.attributes?.state,
        priceTotal: result.response.data?.relationships?.prices?.meta?.paging?.total ?? null
      }
    };
  }

  try {
    return JSON.stringify(specs.map(setInitialPrices), null, 2);
  } catch (error) {
    return JSON.stringify({ ok: false, error: String(error && error.message ? error.message : error) }, null, 2);
  }
})();
