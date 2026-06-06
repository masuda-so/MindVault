(() => {
  const LOCALIZATION_ID = "0ef30351-d1ba-41ab-81ee-b20b8105a4ff";
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const whatsNew =
    "MindVault 1.0 の初回リリースです。Markdownメモ、知識グラフ、ローカル検索、インポート・エクスポート、オンデバイスAI整理の導線を追加しました。";

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

  const before = request("GET", `${base}/appStoreVersionLocalizations/${LOCALIZATION_ID}`);
  const current = before.response?.data?.attributes?.whatsNew;
  let patch = null;
  if (!current || !String(current).trim()) {
    patch = request("PATCH", `${base}/appStoreVersionLocalizations/${LOCALIZATION_ID}`, {
      data: {
        type: "appStoreVersionLocalizations",
        id: LOCALIZATION_ID,
        attributes: { whatsNew }
      }
    });
  }
  const after = request("GET", `${base}/appStoreVersionLocalizations/${LOCALIZATION_ID}`);

  return JSON.stringify({
    before: {
      status: before.status,
      whatsNew: current
    },
    patch: patch && {
      status: patch.status,
      errors: patch.response?.errors,
      whatsNew: patch.response?.data?.attributes?.whatsNew
    },
    after: {
      status: after.status,
      whatsNew: after.response?.data?.attributes?.whatsNew
    }
  }, null, 2);
})();
