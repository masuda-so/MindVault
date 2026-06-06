(() => {
  const appId = "6776897058";
  const base = "https://appstoreconnect.apple.com/iris/v1";

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

  const result = request("PATCH", `${base}/appDataUsagesPublishState/${appId}`, {
    data: {
      type: "appDataUsagesPublishState",
      id: appId,
      attributes: {
        published: true
      }
    }
  });

  return JSON.stringify({
    status: result.status,
    data: result.response.data || null,
    errors: result.response.errors || null
  }, null, 2);
})();
