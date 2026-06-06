(() => {
  try {
    const base = "https://appstoreconnect.apple.com/iris/v1";
    const subscriptionId = "6777127690";
    const pricePointId = "eyJzIjoiNjc3NzEyNzY5MCIsInQiOiJVU0EiLCJwIjoiMTAxMjcifQ";

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

    const result = request("POST", `${base}/subscriptionPrices`, {
      data: {
        type: "subscriptionPrices",
        attributes: {
          startDate: "2026-06-07",
          preserveCurrentPrice: false
        },
        relationships: {
          subscription: {
            data: { type: "subscriptions", id: subscriptionId }
          },
          subscriptionPricePoint: {
            data: { type: "subscriptionPricePoints", id: pricePointId }
          },
          territory: {
            data: { type: "territories", id: "USA" }
          }
        }
      }
    });

    return JSON.stringify(result, null, 2);
  } catch (error) {
    return JSON.stringify({ ok: false, error: String(error && error.message ? error.message : error) }, null, 2);
  }
})();
