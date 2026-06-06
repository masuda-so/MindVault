(() => {
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const buildId = "3f45871a-71e9-4d7f-b386-db229b3dc6cd";

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

  const result = request("PATCH", `${base}/builds/${buildId}`, {
    data: {
      type: "builds",
      id: buildId,
      attributes: {
        usesNonExemptEncryption: false
      }
    }
  });

  return JSON.stringify({
    status: result.status,
    usesNonExemptEncryption: result.response.data?.attributes?.usesNonExemptEncryption ?? null,
    errors: result.response.errors || null
  }, null, 2);
})();
