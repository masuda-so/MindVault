(() => {
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

  const categories = request("GET", `${base}/appDataUsageCategories?include=grouping`);
  const purposes = request("GET", `${base}/appDataUsagePurposes`);

  return JSON.stringify({
    categories: {
      status: categories.status,
      count: categories.response.data?.length ?? null,
      data: (categories.response.data || []).map((item) => ({
        id: item.id,
        type: item.type,
        attributes: item.attributes || null,
        grouping: item.relationships?.grouping?.data?.id || null
      })),
      included: categories.response.included || null,
      errors: categories.response.errors || null
    },
    purposes: {
      status: purposes.status,
      count: purposes.response.data?.length ?? null,
      data: purposes.response.data || null,
      errors: purposes.response.errors || null
    }
  }, null, 2);
})();
