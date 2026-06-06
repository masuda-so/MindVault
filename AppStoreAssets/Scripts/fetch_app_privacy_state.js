(() => {
  const appId = "6776897058";
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

  const usages = request(
    "GET",
    `${base}/apps/${appId}/dataUsages?include=category,grouping,purpose,dataProtection&limit=500`
  );
  const publishState = request(
    "GET",
    `${base}/apps/${appId}/dataUsagePublishState`
  );

  return JSON.stringify({
    usages: {
      status: usages.status,
      count: usages.response.data?.length ?? null,
      data: usages.response.data || null,
      included: usages.response.included || null,
      errors: usages.response.errors || null
    },
    publishState: {
      status: publishState.status,
      data: publishState.response.data || null,
      errors: publishState.response.errors || null
    }
  }, null, 2);
})();
