(() => {
  const subscriptions = [
    { productId: "mindvault.pro.monthly", id: "6777127690", target: "9.99" },
    { productId: "mindvault.team.monthly", id: "6777126997", target: "29.99" }
  ];
  const base = "https://appstoreconnect.apple.com/iris/v1";

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

    if (xhr.status < 200 || xhr.status >= 300) {
      throw new Error(JSON.stringify({ method, url, status: xhr.status, response }, null, 2));
    }

    return response;
  }

  function findPricePoint(subscription, territory) {
    let url = `${base}/subscriptions/${subscription.id}/pricePoints?filter[territory]=${territory}&include=territory&limit=200`;
    while (url) {
      const response = request("GET", url);
      const match = (response.data || []).find((item) => item.attributes.customerPrice === subscription.target);
      if (match) {
        return {
          productId: subscription.productId,
          subscriptionId: subscription.id,
          territory,
          target: subscription.target,
          pricePointId: match.id,
          customerPrice: match.attributes.customerPrice,
          currency: match.attributes.currency,
          proceeds: match.attributes.proceeds,
          equalizationsUrl: match.relationships.equalizations.links.related
        };
      }
      url = response.links?.next || null;
    }
    return {
      productId: subscription.productId,
      subscriptionId: subscription.id,
      territory,
      target: subscription.target,
      pricePointId: null
    };
  }

  return JSON.stringify(subscriptions.map((subscription) => findPricePoint(subscription, "USA")), null, 2);
})();
