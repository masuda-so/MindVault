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

    function createSubscriptionLocalization(subscriptionId, locale, name, description) {
      return request("POST", `${base}/subscriptionLocalizations`, {
        data: {
          type: "subscriptionLocalizations",
          attributes: {
            locale,
            name,
            description
          },
          relationships: {
            subscription: {
              data: { type: "subscriptions", id: subscriptionId }
            }
          }
        }
      }).data;
    }

    const specs = [
      {
        productId: "mindvault.team.monthly",
        referenceName: "Team Monthly",
        groupLevel: 1,
        reviewNote: "MindVault Team monthly subscription. Unlocks the highest tier with shared knowledge-base roadmap access, administrator controls, higher AI organization limits, AI chat search, and advanced graph features.",
        jaName: "MindVault AI Team",
        jaDescription: "共有ナレッジベース、管理者機能、共同編集ロードマップを含むTeamプランです。",
        enName: "MindVault AI Team",
        enDescription: "Team knowledge base, administrator controls, and shared workspace roadmap access."
      },
      {
        productId: "mindvault.pro.monthly",
        referenceName: "Pro Monthly",
        groupLevel: 2,
        reviewNote: "MindVault Pro monthly subscription. Unlocks higher AI organization limits, AI chat search, advanced graph analysis, and cloud sync roadmap access.",
        jaName: "MindVault AI Pro",
        jaDescription: "AI整理回数増加、AIチャット検索、高度グラフ分析、クラウド同期ロードマップを含むProプランです。",
        enName: "MindVault AI Pro",
        enDescription: "More AI organization runs, AI chat search, advanced graph analysis, and cloud sync roadmap access."
      }
    ];

    const results = [];
    for (const spec of specs) {
      const subscription = createSubscription(spec);
      const localizations = [
        createSubscriptionLocalization(subscription.id, "ja", spec.jaName, spec.jaDescription),
        createSubscriptionLocalization(subscription.id, "en-US", spec.enName, spec.enDescription)
      ];
      results.push({ spec, subscription, localizations });
    }

    return JSON.stringify({ ok: true, results }, null, 2);
  } catch (error) {
    return JSON.stringify({ ok: false, error: String(error && error.message ? error.message : error) }, null, 2);
  }
})();
