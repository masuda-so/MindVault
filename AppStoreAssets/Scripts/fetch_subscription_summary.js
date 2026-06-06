(() => {
  const GROUP_ID = "22136604";
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

  const subscriptions = request(
    "GET",
    `${base}/subscriptionGroups/${GROUP_ID}/subscriptions?include=subscriptionLocalizations&limit[subscriptionLocalizations]=20`
  );

  const summaries = [];
  for (const subscription of subscriptions.response.data || []) {
    const prices = request(
      "GET",
      `${base}/subscriptions/${subscription.id}/prices?include=subscriptionPricePoint,territory&limit=200`
    );
    const availability = request(
      "GET",
      `${base}/subscriptions/${subscription.id}/subscriptionAvailability`
    );
    summaries.push({
      id: subscription.id,
      productId: subscription.attributes.productId,
      state: subscription.attributes.state,
      localizations: subscription.relationships.subscriptionLocalizations?.meta?.paging?.total ?? null,
      priceCount: prices.response.meta?.paging?.total ?? null,
      priceStatus: prices.status,
      availabilityStatus: availability.status,
      availability: availability.response.data?.attributes || null,
      firstPrices: (prices.response.data || []).slice(0, 5).map((price) => ({
        id: price.id,
        relationships: price.relationships
      }))
    });
  }

  return JSON.stringify({ subscriptions: summaries }, null, 2);
})();
