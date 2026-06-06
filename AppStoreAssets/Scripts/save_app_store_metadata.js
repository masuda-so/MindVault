(() => {
  const VERSION_ID = "9f074ce3-67e3-4dc0-98b4-e6a92b0893e6";
  const LOCALIZATION_ID = "0ef30351-d1ba-41ab-81ee-b20b8105a4ff";
  const APP_INFO_ID = "3cf0a3b3-ab0c-4e4e-9da0-c3b1bd0c1176";
  const APP_INFO_LOCALIZATION_ID = "9879e24d-0e22-4b7e-9425-f79e24473e32";
  const AGE_RATING_ID = "3cf0a3b3-ab0c-4e4e-9da0-c3b1bd0c1176";
  const REVIEW_DETAIL_ID = "6928991a-00b2-4652-a3f2-b50095930102";

  const supportUrl = "https://masuda-so.github.io/MindVault/support/";
  const marketingUrl = "https://masuda-so.github.io/MindVault/";
  const privacyUrl = "https://masuda-so.github.io/MindVault/privacy/";

  const description = `MindVaultは、Markdownメモをローカル優先で保存し、リンクやタグ、オンデバイスAIの提案を知識グラフとして見渡せる個人用ノートアプリです。

起動するとすぐにグラフビューが表示され、メモ同士のつながりを視覚的に確認できます。思いつき、調査メモ、会議メモ、学習記録、日記の断片をためながら、「なぜこのメモがつながるのか」を追いやすい形で整理できます。

主な機能:
・Markdownメモの作成と編集
・[[wiki link]] とMarkdownリンクによるメモ間リンク
・タグ、明示リンク、AI提案を使った知識グラフ
・ノードをタップして関連メモへ移動
・ローカル検索とAIチャット検索の導線
・対応デバイスでは Apple Foundation Models を使ったオンデバイスAI整理
・AI対象外にしたメモを整理、埋め込み、関連候補、AI検索から除外
・Markdown / JSON / CSV のインポート・エクスポート導線
・広告なし

メモ本文はローカル保存を基本とし、外部AIサービスや独自サーバーへ送信しません。オンデバイスAIが利用できない環境では、通常のメモ編集、リンク解析、グラフ表示、ローカル検索をそのまま利用できます。

MindVaultは、メモをただ保存するだけでなく、自分の考えがどのようにつながっているかを見直したい人のための知識ノートです。

利用規約（Apple標準EULA）: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`;

  const reviewNotes = `First submission for MindVault 1.0 build 1.

This app does not require sign-in.

MindVault is a local-first Markdown note and knowledge graph app. Users can create Markdown notes, link notes with wiki links or Markdown links, view an explainable graph of note relationships, and use on-device organization features when supported by the device.

Privacy and AI behavior:
- User notes are stored locally by default.
- The app does not send note content to an external AI service or custom server.
- On-device AI features use Apple Foundation Models only when available.
- If on-device AI is unavailable, the app shows an unavailable state and continues to support note editing, graph viewing, and local search.
- Notes marked as AI-ineligible are excluded from AI organization, embeddings, related-note candidates, and AI chat search.
- The app does not include ads.

The Privacy Policy URL in App Store Connect is functional:
https://masuda-so.github.io/MindVault/privacy/

The app description includes the Apple Standard EULA link. The app includes a privacy explanation in Settings / Plan.

Please review these first auto-renewable subscriptions with this app version:
- mindvault.pro.monthly
- mindvault.team.monthly

Review steps:
1. Launch the app.
2. Confirm that the graph view is visible on launch.
3. Tap a graph node to open the related Markdown note.
4. Open the Notes tab and create or edit a Markdown note.
5. Add a wiki link such as [[MindVault welcome note]] or a Markdown link, then return to the graph to confirm that explicit links are reflected.
6. Open the Search tab and confirm that local note candidates are shown.
7. Open Settings and confirm the privacy explanation and plan information.
8. Confirm that the Pro and Team subscription options load from StoreKit.
9. If the test device supports Apple Foundation Models, open the AI organization or AI chat search flow. If unsupported, confirm that the app shows an explanatory unavailable state and does not offer an external AI fallback.`;

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

  const base = "https://appstoreconnect.apple.com/iris/v1";
  const results = [];

  results.push(request("PATCH", `${base}/appStoreReviewDetails/${REVIEW_DETAIL_ID}`, {
    data: {
      type: "appStoreReviewDetails",
      id: REVIEW_DETAIL_ID,
      attributes: {
        contactFirstName: "So",
        contactLastName: "Masuda",
        contactPhone: "+819073620981",
        contactEmail: "so.masuda.2003@pm.me",
        demoAccountRequired: false,
        demoAccountName: null,
        demoAccountPassword: null,
        notes: reviewNotes
      }
    }
  }));

  results.push(request("PATCH", `${base}/appStoreVersionLocalizations/${LOCALIZATION_ID}`, {
    data: {
      type: "appStoreVersionLocalizations",
      id: LOCALIZATION_ID,
      attributes: {
        description,
        keywords: "メモ,ノート,Markdown,知識グラフ,AI,検索,タグ,リンク,日記,学習,仕事",
        marketingUrl,
        promotionalText: "Markdownメモを起動直後の知識グラフで見渡せます。リンク、タグ、オンデバイスAI提案を使い、考えのつながりをローカル優先で育てるノートアプリです。",
        supportUrl
      }
    }
  }));

  results.push(request("PATCH", `${base}/appInfoLocalizations/${APP_INFO_LOCALIZATION_ID}`, {
    data: {
      type: "appInfoLocalizations",
      id: APP_INFO_LOCALIZATION_ID,
      attributes: {
        subtitle: "思考をつなぐ知識グラフノート",
        privacyPolicyUrl: privacyUrl,
        privacyChoicesUrl: null,
        privacyPolicyText: null
      }
    }
  }));

  results.push(request("PATCH", `${base}/appStoreVersions/${VERSION_ID}`, {
    data: {
      type: "appStoreVersions",
      id: VERSION_ID,
      attributes: {
        copyright: "2026 Ether LLC",
        usesIdfa: false
      }
    }
  }));

  results.push(request("PATCH", `${base}/appInfos/${APP_INFO_ID}`, {
    data: {
      type: "appInfos",
      id: APP_INFO_ID,
      relationships: {
        primaryCategory: {
          data: { type: "appCategories", id: "PRODUCTIVITY" }
        },
        secondaryCategory: {
          data: { type: "appCategories", id: "UTILITIES" }
        }
      }
    }
  }));

  results.push(request("PATCH", `${base}/ageRatingDeclarations/${AGE_RATING_ID}`, {
    data: {
      type: "ageRatingDeclarations",
      id: AGE_RATING_ID,
      attributes: {
        advertising: false,
        alcoholTobaccoOrDrugUseOrReferences: "NONE",
        contests: "NONE",
        gambling: false,
        gamblingSimulated: "NONE",
        gunsOrOtherWeapons: "NONE",
        healthOrWellnessTopics: false,
        lootBox: false,
        medicalOrTreatmentInformation: "NONE",
        messagingAndChat: false,
        parentalControls: false,
        profanityOrCrudeHumor: "NONE",
        ageAssurance: false,
        sexualContentGraphicAndNudity: "NONE",
        sexualContentOrNudity: "NONE",
        horrorOrFearThemes: "NONE",
        matureOrSuggestiveThemes: "NONE",
        unrestrictedWebAccess: false,
        userGeneratedContent: false,
        violenceCartoonOrFantasy: "NONE",
        violenceRealisticProlongedGraphicOrSadistic: "NONE",
        violenceRealistic: "NONE",
        koreaAgeRatingOverride: "NONE"
      }
    }
  }));

  return JSON.stringify(results, null, 2);
})();
