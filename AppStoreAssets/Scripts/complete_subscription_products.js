(() => {
  try {
    const GROUP_ID = "22136604";
    const TEAM_ID = "6777126997";
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

    function listGroup() {
      return request(
        "GET",
        `${base}/subscriptionGroups/${GROUP_ID}/subscriptions?include=subscriptionLocalizations&limit[subscriptionLocalizations]=10`
      );
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

    function addLocalizations(subscriptionId, spec) {
      const results = [];
      results.push(createLocalization(subscriptionId, "ja", spec.jaName, spec.jaDescription));
      results.push(createLocalization(subscriptionId, "en-US", spec.enName, spec.enDescription));
      return results;
    }

    const teamSpec = {
      productId: "mindvault.team.monthly",
      referenceName: "Team Monthly",
      groupLevel: 1,
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

    const before = listGroup();
    const existing = new Map((before.data || []).map((item) => [item.attributes.productId, item]));
    const results = { before, actions: [] };

    const team = existing.get(teamSpec.productId);
    if (team) {
      results.actions.push({
        productId: teamSpec.productId,
        subscriptionId: team.id,
        localizations: addLocalizations(team.id, teamSpec)
      });
    }

    if (!existing.has(proSpec.productId)) {
      const pro = createSubscription(proSpec);
      results.actions.push({
        productId: proSpec.productId,
        subscriptionId: pro.id,
        subscription: pro,
        localizations: addLocalizations(pro.id, proSpec)
      });
    }

    results.after = listGroup();
    return JSON.stringify({ ok: true, results }, null, 2);
  } catch (error) {
    return JSON.stringify({ ok: false, error: String(error && error.message ? error.message : error) }, null, 2);
  }
})();
