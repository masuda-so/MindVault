(() => {
  try {
    const base = "https://appstoreconnect.apple.com/iris/v1";
    const specs = [
      {
        productId: "mindvault.pro.monthly",
        subscriptionId: "6777127690",
        pricePointId: "eyJzIjoiNjc3NzEyNzY5MCIsInQiOiJVU0EiLCJwIjoiMTAxMjcifQ",
        equalizationsUrl: "https://appstoreconnect.apple.com/iris/v1/subscriptionPricePoints/eyJzIjoiNjc3NzEyNzY5MCIsInQiOiJVU0EiLCJwIjoiMTAxMjcifQ/equalizations"
      },
      {
        productId: "mindvault.team.monthly",
        subscriptionId: "6777126997",
        pricePointId: "eyJzIjoiNjc3NzEyNjk5NyIsInQiOiJVU0EiLCJwIjoiMTAyMjcifQ",
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

      if (xhr.status < 200 || xhr.status >= 300) {
        return { ok: false, method, url, status: xhr.status, response };
      }

      return { ok: true, method, url, status: xhr.status, response };
    }

    function collectEqualizedPricePointIds(url) {
      const ids = [];
      let next = `${url}?limit=200`;
      while (next) {
        const result = request("GET", next);
        if (!result.ok) throw new Error(JSON.stringify(result, null, 2));
        ids.push(...(result.response.data || []).map((item) => item.id));
        next = result.response.links?.next || null;
      }
      return ids;
    }

    function createPrice(subscriptionId, pricePointId) {
      return request("POST", `${base}/subscriptionPrices`, {
        data: {
          type: "subscriptionPrices",
          relationships: {
            subscription: {
              data: { type: "subscriptions", id: subscriptionId }
            },
            subscriptionPricePoint: {
              data: { type: "subscriptionPricePoints", id: pricePointId }
            }
          }
        }
      });
    }

    const results = [];
    for (const spec of specs) {
      const equalizedIds = collectEqualizedPricePointIds(spec.equalizationsUrl);
      const pricePointIds = [spec.pricePointId, ...equalizedIds];
      const createResults = [];
      for (const pricePointId of pricePointIds) {
        createResults.push(createPrice(spec.subscriptionId, pricePointId));
      }
      results.push({
        productId: spec.productId,
        subscriptionId: spec.subscriptionId,
        pricePointCount: pricePointIds.length,
        okCount: createResults.filter((result) => result.ok).length,
        failed: createResults.filter((result) => !result.ok).slice(0, 10)
      });
    }

    return JSON.stringify({ ok: true, results }, null, 2);
  } catch (error) {
    return JSON.stringify({ ok: false, error: String(error && error.message ? error.message : error) }, null, 2);
  }
})();
