(() => {
  const specs = [
    {
      productId: "mindvault.pro.monthly",
      equalizationsUrl: "https://appstoreconnect.apple.com/iris/v1/subscriptionPricePoints/eyJzIjoiNjc3NzEyNzY5MCIsInQiOiJVU0EiLCJwIjoiMTAxMjcifQ/equalizations"
    },
    {
      productId: "mindvault.team.monthly",
      equalizationsUrl: "https://appstoreconnect.apple.com/iris/v1/subscriptionPricePoints/eyJzIjoiNjc3NzEyNjk5NyIsInQiOiJVU0EiLCJwIjoiMTAyMjcifQ/equalizations"
    }
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

  const results = [];
  for (const spec of specs) {
    const result = request("GET", `${spec.equalizationsUrl}?include=territory&limit=5`);
    results.push({
      productId: spec.productId,
      status: result.status,
      total: result.response.meta?.paging?.total ?? null,
      sample: (result.response.data || []).slice(0, 5),
      includedSample: (result.response.included || []).slice(0, 5)
    });
  }

  return JSON.stringify(results, null, 2);
})();
