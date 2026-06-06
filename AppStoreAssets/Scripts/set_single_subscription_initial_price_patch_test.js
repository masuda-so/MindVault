(() => {
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

  const priceId = "${price-usa-initial}";
  const result = request("PATCH", `${base}/subscriptions/${subscriptionId}`, {
    data: {
      type: "subscriptions",
      id: subscriptionId,
      relationships: {
        prices: {
          data: [
            { type: "subscriptionPrices", id: priceId }
          ]
        }
      }
    },
    included: [
      {
        type: "subscriptionPrices",
        id: priceId,
        relationships: {
          subscriptionPricePoint: {
            data: { type: "subscriptionPricePoints", id: pricePointId }
          },
          territory: {
            data: { type: "territories", id: "USA" }
          }
        }
      }
    ]
  });

  return JSON.stringify(result, null, 2);
})();
