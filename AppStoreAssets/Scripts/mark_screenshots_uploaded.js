(() => {
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const screenshotIds = [
    "f76b2339-77ce-48a9-b706-c623203398d2",
    "baa05685-8482-4711-a7ef-ec56c2e9de5e",
    "c6bbaa94-8cd7-4402-8331-4d490b87aacf",
    "7b224cd6-140a-482d-a812-9cb9d750097a",
    "376151da-359a-44cb-a424-cebbee7a291e"
  ];

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

  const results = [];
  for (const id of screenshotIds) {
    results.push(request("PATCH", `${base}/appScreenshots/${id}`, {
      data: {
        type: "appScreenshots",
        id,
        attributes: {
          uploaded: true
        }
      }
    }));
  }

  return JSON.stringify(results, null, 2);
})();
