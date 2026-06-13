(() => {
  const REVIEW_DETAIL_ID = "6928991a-00b2-4652-a3f2-b50095930102";
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const notes = `Updated build for App Review: MindVault 1.0 build 5.

This build addresses the previous App Review feedback:

1. Guideline 2.1(b)
The Paid Apps Agreement for Ether LLC is active in App Store Connect Business. The MindVault auto-renewable subscription products are configured with pricing and availability and currently show Waiting for Review:
- mindvault.pro.monthly
- mindvault.team.monthly

The subscription screen uses Apple's StoreKit SubscriptionStoreView with the production product identifiers above. Build 5 also removes the previous development-only explanatory copy from the paywall so reviewers see the production purchase path.

Reviewer path: open MindVault, go to the Settings tab, then the Current Plan section. Choose a monthly plan from the StoreKit subscription options.

2. Guideline 3.1.2(c)
The subscription screen now includes visible policy links inside the app:
- Privacy Policy: https://masuda-so.github.io/MindVault/privacy/
- Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Reviewer path: open MindVault, go to the Settings tab, then the Current Plan section. The SubscriptionStoreView also exposes StoreKit policy buttons.

3. Guideline 3.1.1
The app now includes a distinct Restore Purchases button on the subscription screen. It calls StoreKit AppStore.sync() and refreshes verified transactions.

Reviewer path: open MindVault, go to Settings, then Current Plan, then tap Restore Purchases.

No demo account is required. MindVault works locally with sample/on-device content and StoreKit handles purchases.`;

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

  const before = request("GET", `${base}/appStoreReviewDetails/${REVIEW_DETAIL_ID}`);
  const patch = request("PATCH", `${base}/appStoreReviewDetails/${REVIEW_DETAIL_ID}`, {
    data: {
      type: "appStoreReviewDetails",
      id: REVIEW_DETAIL_ID,
      attributes: { notes }
    }
  });
  const after = request("GET", `${base}/appStoreReviewDetails/${REVIEW_DETAIL_ID}`);

  return JSON.stringify({
    before: {
      status: before.status,
      notesLength: (before.response.data?.attributes?.notes || "").length
    },
    patch: {
      status: patch.status,
      errors: patch.response.errors,
      notesLength: (patch.response.data?.attributes?.notes || "").length
    },
    after: {
      status: after.status,
      notes: after.response.data?.attributes?.notes,
      errors: after.response.errors
    }
  }, null, 2);
})();
