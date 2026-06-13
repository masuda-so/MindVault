(() => {
  const VERSION_ID = "9f074ce3-67e3-4dc0-98b4-e6a92b0893e6";
  const BUILD_ID = "a6d5bbe1-1cf9-4473-bcba-2a3af0de7c4b";
  const base = "https://appstoreconnect.apple.com/iris/v1";

  function request(method, url, body) {
    const xhr = new XMLHttpRequest();
    xhr.open(method, url, false);
    xhr.withCredentials = true;
    xhr.setRequestHeader("Accept", "application/vnd.api+json");
    if (body) {
      xhr.setRequestHeader("Content-Type", "application/vnd.api+json");
    }
    xhr.send(body ? JSON.stringify(body) : null);

    let response;
    try {
      response = JSON.parse(xhr.responseText || "{}");
    } catch {
      response = xhr.responseText;
    }

    return { method, url, status: xhr.status, response };
  }

  const exportCompliance = request("PATCH", `${base}/builds/${BUILD_ID}`, {
    data: {
      type: "builds",
      id: BUILD_ID,
      attributes: {
        usesNonExemptEncryption: false
      }
    }
  });

  const selectBuild = request("PATCH", `${base}/appStoreVersions/${VERSION_ID}/relationships/build`, {
    data: {
      type: "builds",
      id: BUILD_ID
    }
  });

  const version = request(
    "GET",
    `${base}/appStoreVersions/${VERSION_ID}?include=build&fields[appStoreVersions]=appStoreState,appVersionState,versionString,build&fields[builds]=version,processingState,usesNonExemptEncryption`
  );

  const build = (version.response.included || []).find((item) => item.type === "builds");

  return JSON.stringify({
    exportCompliance: {
      status: exportCompliance.status,
      usesNonExemptEncryption: exportCompliance.response.data?.attributes?.usesNonExemptEncryption ?? null,
      errors: exportCompliance.response.errors
    },
    selectBuild: {
      status: selectBuild.status,
      data: selectBuild.response.data,
      errors: selectBuild.response.errors
    },
    version: {
      status: version.status,
      attributes: version.response.data?.attributes,
      build: build && {
        id: build.id,
        version: build.attributes?.version,
        processingState: build.attributes?.processingState,
        usesNonExemptEncryption: build.attributes?.usesNonExemptEncryption
      },
      errors: version.response.errors
    }
  }, null, 2);
})();
