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

    return { method, url, status: xhr.status, response };
  }

  const results = [];
  for (const subscription of subscriptions) {
    for (const territory of ["USA", "JPN"]) {
      results.push({
        productId: subscription.productId,
        subscriptionId: subscription.id,
        target: subscription.target,
        territory,
        pricePoints: request(
          "GET",
          `${base}/subscriptions/${subscription.id}/pricePoints?filter[territory]=${territory}&include=territory&limit=200`
        )
      });
    }
  }

  return JSON.stringify(results, null, 2);
})();
