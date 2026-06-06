(() => {
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const specs = [
    { label: "Pro Monthly", subscriptionId: "6777127690" },
    { label: "Team Monthly", subscriptionId: "6777126997" }
  ];

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

  function collectPrices(subscriptionId) {
    const data = [];
    const included = [];
    let next = `${base}/subscriptions/${subscriptionId}/prices?include=subscriptionPricePoint,territory&limit=200`;
    while (next) {
      const result = request("GET", next);
      if (result.status < 200 || result.status >= 300) {
        return { status: result.status, response: result.response };
      }
      data.push(...(result.response.data || []));
      included.push(...(result.response.included || []));
      next = result.response.links?.next || null;
    }
    return { status: 200, data, included };
  }

  const results = [];
  for (const spec of specs) {
    const prices = collectPrices(spec.subscriptionId);
    const territories = (prices.included || [])
      .filter((item) => item.type === "territories")
      .map((item) => item.id)
      .sort();
    results.push({
      label: spec.label,
      status: prices.status,
      priceCount: prices.data?.length ?? null,
      territoryCount: territories.length,
      territorySample: territories.slice(0, 20),
      error: prices.response?.errors || null
    });
  }

  return JSON.stringify(results, null, 2);
})();
