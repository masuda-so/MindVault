(() => {
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const duplicateIds = [
    "191ada1a-d8e6-45e3-a4e1-08655536daa2",
    "82755206-8606-47a6-a60b-dac1e80d9215",
    "cf7883a1-ade7-4545-8fe0-826d1e0b70e4"
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

    if (xhr.status < 200 || xhr.status >= 300) {
      throw new Error(JSON.stringify({ method, url, status: xhr.status, response }, null, 2));
    }

    return { method, url, status: xhr.status, response };
  }

  const results = [];
  for (const id of duplicateIds) {
    results.push(request("DELETE", `${base}/appScreenshots/${id}`));
  }

  return JSON.stringify(results, null, 2);
})();
