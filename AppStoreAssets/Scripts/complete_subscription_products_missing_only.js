(() => {
  try {
    const GROUP_ID = "22136604";
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

    function listSubscriptions() {
      return request(
        "GET",
        `${base}/subscriptionGroups/${GROUP_ID}/subscriptions?include=subscriptionLocalizations&limit[subscriptionLocalizations]=20`
      );
    }

    function localizationsFor(response, subscriptionId) {
      const localizationIds = new Set();
      const subscription = (response.data || []).find((item) => item.id === subscriptionId);
      for (const ref of subscription?.relationships?.subscriptionLocalizations?.data || []) {
        localizationIds.add(ref.id);
      }
      return (response.included || [])
        .filter((item) => item.type === "subscriptionLocalizations" && localizationIds.has(item.id));
    }

    function createSubscription(spec) {
      return request("POST", `${base}/subscriptions`, {
        data: {
          type: "subscriptions",
          attributes: {
            name: spec.referenceName,
            productId: spec.productId,
            subscriptionPeriod: "ONE_MONTH",
            familySharable: false,
            reviewNote: spec.reviewNote,
            groupLevel: spec.groupLevel
          },
          relationships: {
            group: {
              data: { type: "subscriptionGroups", id: GROUP_ID }
            }
          }
        }
      }).data;
    }

    function createLocalization(subscriptionId, locale, name, description) {
      return request("POST", `${base}/subscriptionLocalizations`, {
        data: {
          type: "subscriptionLocalizations",
          attributes: { locale, name, description },
          relationships: {
            subscription: {
              data: { type: "subscriptions", id: subscriptionId }
            }
          }
        }
      }).data;
    }

    function addMissingLocalizations(response, subscriptionId, spec) {
      const existingLocales = new Set(
        localizationsFor(response, subscriptionId).map((item) => item.attributes.locale)
      );
      const results = [];
      const desired = [
        ["ja", spec.jaName, spec.jaDescription],
        ["en-US", spec.enName, spec.enDescription]
      ];
      for (const [locale, name, description] of desired) {
        if (!existingLocales.has(locale)) {
          results.push(createLocalization(subscriptionId, locale, name, description));
        }
      }
      return results;
    }

    const teamSpec = {
      productId: "mindvault.team.monthly",
      jaName: "MindVault AI Team",
      jaDescription: "共有と管理機能を強化します。",
      enName: "MindVault AI Team",
      enDescription: "Shared workspace and admin features."
    };

    const proSpec = {
      productId: "mindvault.pro.monthly",
      referenceName: "Pro Monthly",
      groupLevel: 2,
      reviewNote: "MindVault Pro monthly subscription. Unlocks higher AI organization limits, AI chat search, advanced graph analysis, and cloud sync roadmap access.",
      jaName: "MindVault AI Pro",
      jaDescription: "AI整理とグラフ分析を強化します。",
      enName: "MindVault AI Pro",
      enDescription: "More AI and graph features."
    };

    let before = listSubscriptions();
    const results = { before, actions: [] };
    let existing = new Map((before.data || []).map((item) => [item.attributes.productId, item]));

    const team = existing.get(teamSpec.productId);
    if (team) {
      results.actions.push({
        productId: teamSpec.productId,
        subscriptionId: team.id,
        localizations: addMissingLocalizations(before, team.id, teamSpec)
      });
    }

    if (!existing.has(proSpec.productId)) {
      const pro = createSubscription(proSpec);
      before = listSubscriptions();
      results.actions.push({
        productId: proSpec.productId,
        subscriptionId: pro.id,
        subscription: pro,
        localizations: addMissingLocalizations(before, pro.id, proSpec)
      });
    }

    results.after = listSubscriptions();
    return JSON.stringify({ ok: true, results }, null, 2);
  } catch (error) {
    return JSON.stringify({ ok: false, error: String(error && error.message ? error.message : error) }, null, 2);
  }
})();
