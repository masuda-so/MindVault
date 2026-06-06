(() => {
  const APP_ID = "6766864082";
  const VERSION_STRING = "1.0.2";
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

    if (xhr.status < 200 || xhr.status >= 300) {
      throw new Error(JSON.stringify({ method, url, status: xhr.status, response }, null, 2));
    }
    return response;
  }

  const versions = request("GET", `${base}/apps/${APP_ID}/appStoreVersions?limit=20`);
  const version = (versions.data || []).find((item) =>
    item.attributes?.platform === "IOS" &&
    item.attributes?.versionString === VERSION_STRING
  );
  if (!version) throw new Error(`Version not found: ${VERSION_STRING}`);

  const detail = request("GET", `${base}/appStoreVersions/${version.id}/appStoreReviewDetail`).data;
  const currentNotes = detail.attributes?.notes || "";
  const oldLead = "Update for resubmission: This submission uses app version 1.0.1 and build 4.";
  const newLead =
    "Update for resubmission: This draft prepares app version 1.0.2. A corresponding 1.0.2 build still needs to be uploaded and selected before review submission. The app behavior is intended to remain consistent with the previously reviewed 1.0.1 build 4; this update primarily refreshes App Store screenshots and metadata.";
  const updatedNotes = currentNotes.includes(oldLead)
    ? currentNotes.replace(oldLead, newLead)
    : currentNotes;

  let patchStatus = "no_patch_needed";
  let response = null;
  if (updatedNotes !== currentNotes) {
    response = request("PATCH", `${base}/appStoreReviewDetails/${detail.id}`, {
      data: {
        type: "appStoreReviewDetails",
        id: detail.id,
        attributes: {
          notes: updatedNotes
        }
      }
    });
    patchStatus = "patched";
  }

  return JSON.stringify({
    versionId: version.id,
    reviewDetailId: detail.id,
    patchStatus,
    notesLengthBefore: currentNotes.length,
    notesLengthAfter: updatedNotes.length,
    firstParagraph: updatedNotes.split("\n\n")[0],
    returnedState: response?.data?.attributes?.state
  }, null, 2);
})();
