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
    return { status: xhr.status, response };
  }

  const subs = request(
    "GET",
    `${base}/subscriptionGroups/${GROUP_ID}/subscriptions?include=subscriptionLocalizations&limit[subscriptionLocalizations]=20`
  );

  const summaries = [];
  for (const sub of subs.response.data || []) {
    const prices = request("GET", `${base}/subscriptions/${sub.id}/prices?limit=1`);
    const availability = request("GET", `${base}/subscriptions/${sub.id}/subscriptionAvailability`);
    summaries.push({
      id: sub.id,
      name: sub.attributes.name,
      productId: sub.attributes.productId,
      state: sub.attributes.state,
      groupLevel: sub.attributes.groupLevel,
      localizations: sub.relationships.subscriptionLocalizations?.meta?.paging?.total ?? null,
      pricesStatus: prices.status,
      priceCount: prices.response.meta?.paging?.total ?? null,
      firstPrice: prices.response.data?.[0]?.id || null,
      availabilityStatus: availability.status,
      availability: availability.response.data?.attributes || availability.response.errors || null
    });
  }

  return JSON.stringify(summaries, null, 2);
})();
