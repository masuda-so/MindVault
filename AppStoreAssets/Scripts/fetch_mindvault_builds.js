(() => {
  const APP_ID = "6776897058";
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

    return { status: xhr.status, response };
  }

  const builds = request(
    "GET",
    `${base}/builds?filter[app]=${APP_ID}&sort=-uploadedDate&limit=10&fields[builds]=version,processingState,uploadedDate,expired,usesNonExemptEncryption,minOsVersion,iconAssetToken`
  );
  const buildUploads = request(
    "GET",
    `${base}/apps/${APP_ID}/buildUploads?filter[cfBundleShortVersionString]=1.0&filter[platform]=IOS&limit=10`
  );

  return JSON.stringify({
    status: builds.status,
    builds: (builds.response.data || []).map((build) => ({
      id: build.id,
      version: build.attributes?.version,
      processingState: build.attributes?.processingState,
      uploadedDate: build.attributes?.uploadedDate,
      expired: build.attributes?.expired,
      usesNonExemptEncryption: build.attributes?.usesNonExemptEncryption,
      minOsVersion: build.attributes?.minOsVersion,
      hasIconAssetToken: Boolean(build.attributes?.iconAssetToken)
    })),
    buildUploads: {
      status: buildUploads.status,
      uploads: (buildUploads.response.data || []).map((upload) => ({
        id: upload.id,
        cfBundleShortVersionString: upload.attributes?.cfBundleShortVersionString,
        cfBundleVersion: upload.attributes?.cfBundleVersion,
        createdDate: upload.attributes?.createdDate,
        uploadedDate: upload.attributes?.uploadedDate,
        platform: upload.attributes?.platform,
        state: upload.attributes?.state
      })),
      errors: buildUploads.response.errors
    },
    errors: builds.response.errors
  }, null, 2);
})();
