#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "AppStoreAssets" / "Scripts" / "run_safari_js.jxa"
TMP_SCRIPT = Path("/private/tmp/appstore_small_thanks_102_replace.js")

TARGET = {
    "name": "SmallThanksDiary",
    "appId": "6766864082",
    "sourceVersionString": "1.0.1",
    "targetVersionString": "1.0.2",
    "locale": "ja",
    "displayType": "APP_IPHONE_65",
    "sourceDir": "AppStoreAssets/AttachedScreenStylePreviews/SmallThanksDiary/iPhone65",
    "stems": [
        "01-moments",
        "02-achievements",
        "03-badge-detail",
        "04-reflection-premium",
        "05-settings",
        "06-entry-form",
        "07-moment-detail",
        "08-export-premium",
        "09-achievements-locked",
        "10-settings-premium-info",
    ],
}


def build_target() -> dict:
    target = dict(TARGET)
    source_dir = Path(target["sourceDir"])
    files = []
    for stem in target.pop("stems"):
        path = source_dir / f"{stem}.png"
        full_path = ROOT / path
        if not full_path.exists():
            raise FileNotFoundError(full_path)
        files.append(
            {
                "localPath": str(path),
                "fileName": path.name,
                "fileSize": full_path.stat().st_size,
            }
        )
    target["files"] = files
    return target


def run_safari_js(script: str):
    TMP_SCRIPT.write_text(script, encoding="utf-8")
    output = subprocess.check_output(
        ["osascript", "-l", "JavaScript", str(RUNNER), str(TMP_SCRIPT)],
        cwd=ROOT,
        text=True,
    )
    return json.loads(output)


def reserve_script(target: dict) -> str:
    payload = json.dumps(target, ensure_ascii=False)
    return f"""
(() => {{
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const target = {payload};
  const log = [];

  function request(method, url, body) {{
    const xhr = new XMLHttpRequest();
    xhr.open(method, url, false);
    xhr.withCredentials = true;
    xhr.setRequestHeader("Content-Type", "application/vnd.api+json");
    xhr.setRequestHeader("Accept", "application/vnd.api+json");
    xhr.send(body ? JSON.stringify(body) : null);

    let response;
    try {{
      response = JSON.parse(xhr.responseText || "{{}}");
    }} catch {{
      response = xhr.responseText;
    }}
    const entry = {{ method, url, status: xhr.status, response }};
    log.push(entry);
    if (xhr.status < 200 || xhr.status >= 300) {{
      throw new Error(JSON.stringify(entry, null, 2));
    }}
    return response;
  }}

  function fetchVersions() {{
    return request(
      "GET",
      `${{base}}/apps/${{target.appId}}/appStoreVersions?include=appStoreVersionLocalizations&limit=20&limit[appStoreVersionLocalizations]=10`
    );
  }}

  function findVersion(versions, versionString) {{
    return (versions.data || []).find((item) =>
      item.attributes?.platform === "IOS" &&
      item.attributes?.versionString === versionString
    );
  }}

  function locsById(versions) {{
    return Object.fromEntries((versions.included || [])
      .filter((item) => item.type === "appStoreVersionLocalizations")
      .map((item) => [item.id, item]));
  }}

  function findLocalization(version, versions, locale) {{
    const byId = locsById(versions);
    const ref = (version.relationships?.appStoreVersionLocalizations?.data || [])
      .find((item) => byId[item.id]?.attributes?.locale === locale);
    return ref ? byId[ref.id] : null;
  }}

  try {{
    let versions = fetchVersions();
    const sourceVersion = findVersion(versions, target.sourceVersionString);
    if (!sourceVersion) throw new Error(`Source version not found: ${{target.sourceVersionString}}`);
    const sourceLocalization = findLocalization(sourceVersion, versions, target.locale);
    if (!sourceLocalization) throw new Error(`Source localization not found: ${{target.locale}}`);

    let targetVersion = findVersion(versions, target.targetVersionString);
    let createdVersion = false;
    if (!targetVersion) {{
      targetVersion = request("POST", `${{base}}/appStoreVersions`, {{
        data: {{
          type: "appStoreVersions",
          attributes: {{
            platform: "IOS",
            versionString: target.targetVersionString
          }},
          relationships: {{
            app: {{
              data: {{ type: "apps", id: target.appId }}
            }}
          }}
        }}
      }}).data;
      createdVersion = true;
    }}

    versions = fetchVersions();
    targetVersion = findVersion(versions, target.targetVersionString) || targetVersion;
    let targetLocalization = findLocalization(targetVersion, versions, target.locale);
    let createdLocalization = false;
    if (!targetLocalization) {{
      const source = sourceLocalization.attributes || {{}};
      const attrs = {{
        locale: target.locale,
        description: source.description,
        keywords: source.keywords,
        marketingUrl: source.marketingUrl,
        promotionalText: source.promotionalText,
        supportUrl: source.supportUrl,
        whatsNew: source.whatsNew || "App Storeのスクリーンショットを更新しました。"
      }};
      Object.keys(attrs).forEach((key) => attrs[key] === undefined && delete attrs[key]);
      targetLocalization = request("POST", `${{base}}/appStoreVersionLocalizations`, {{
        data: {{
          type: "appStoreVersionLocalizations",
          attributes: attrs,
          relationships: {{
            appStoreVersion: {{
              data: {{ type: "appStoreVersions", id: targetVersion.id }}
            }}
          }}
        }}
      }}).data;
      createdLocalization = true;
    }}

    const listing = request(
      "GET",
      `${{base}}/appStoreVersionLocalizations/${{targetLocalization.id}}/appScreenshotSets?include=appScreenshots&limit[appScreenshots]=50`
    );
    let set = (listing.data || []).find((item) =>
      item.attributes?.screenshotDisplayType === target.displayType
    );
    if (!set) {{
      set = request("POST", `${{base}}/appScreenshotSets`, {{
        data: {{
          type: "appScreenshotSets",
          attributes: {{ screenshotDisplayType: target.displayType }},
          relationships: {{
            appStoreVersionLocalization: {{
              data: {{ type: "appStoreVersionLocalizations", id: targetLocalization.id }}
            }}
          }}
        }}
      }}).data;
    }}

    const screenshotIds = new Set((set.relationships?.appScreenshots?.data || []).map((item) => item.id));
    const existing = (listing.included || [])
      .filter((item) => item.type === "appScreenshots" && screenshotIds.has(item.id));
    const deleted = [];
    for (const screenshot of existing) {{
      request("DELETE", `${{base}}/appScreenshots/${{screenshot.id}}`);
      deleted.push({{
        id: screenshot.id,
        fileName: screenshot.attributes?.fileName,
        state: screenshot.attributes?.assetDeliveryState?.state
      }});
    }}

    const reservations = [];
    for (const file of target.files) {{
      const screenshot = request("POST", `${{base}}/appScreenshots`, {{
        data: {{
          type: "appScreenshots",
          attributes: {{
            fileName: file.fileName,
            fileSize: file.fileSize
          }},
          relationships: {{
            appScreenshotSet: {{
              data: {{ type: "appScreenshotSets", id: set.id }}
            }}
          }}
        }}
      }}).data;
      reservations.push({{
        screenshotId: screenshot.id,
        setId: set.id,
        localPath: file.localPath,
        fileName: file.fileName,
        fileSize: file.fileSize,
        uploadOperations: screenshot.attributes?.uploadOperations,
        assetDeliveryState: screenshot.attributes?.assetDeliveryState
      }});
    }}

    return JSON.stringify({{
      ok: true,
      target: target.name,
      sourceVersionId: sourceVersion.id,
      targetVersionId: targetVersion.id,
      targetVersionString: target.targetVersionString,
      appStoreState: targetVersion.attributes?.appStoreState,
      createdVersion,
      targetLocalizationId: targetLocalization.id,
      createdLocalization,
      setId: set.id,
      deleted,
      reservations
    }}, null, 2);
  }} catch (error) {{
    return JSON.stringify({{
      ok: false,
      target: target.name,
      error: String(error),
      logTail: log.slice(-6)
    }}, null, 2);
  }}
}})();
"""


def mark_uploaded_script(items: list[dict]) -> str:
    payload = json.dumps(
        [{"screenshotId": item["screenshotId"], "fileName": item["fileName"]} for item in items],
        ensure_ascii=False,
    )
    return f"""
(() => {{
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const items = {payload};

  function request(method, url, body) {{
    const xhr = new XMLHttpRequest();
    xhr.open(method, url, false);
    xhr.withCredentials = true;
    xhr.setRequestHeader("Content-Type", "application/vnd.api+json");
    xhr.setRequestHeader("Accept", "application/vnd.api+json");
    xhr.send(body ? JSON.stringify(body) : null);
    let response;
    try {{
      response = JSON.parse(xhr.responseText || "{{}}");
    }} catch {{
      response = xhr.responseText;
    }}
    if (xhr.status < 200 || xhr.status >= 300) {{
      throw new Error(JSON.stringify({{ method, url, status: xhr.status, response }}, null, 2));
    }}
    return response;
  }}

  const results = [];
  for (const item of items) {{
    const response = request("PATCH", `${{base}}/appScreenshots/${{item.screenshotId}}`, {{
      data: {{
        type: "appScreenshots",
        id: item.screenshotId,
        attributes: {{ uploaded: true }}
      }}
    }});
    results.push({{
      screenshotId: item.screenshotId,
      fileName: item.fileName,
      state: response.data?.attributes?.assetDeliveryState?.state,
      uploaded: response.data?.attributes?.uploaded
    }});
  }}
  return JSON.stringify(results, null, 2);
}})();
"""


def final_state_script(target: dict, target_version_id: str, localization_id: str) -> str:
    payload = json.dumps(
        {
            "target": target["name"],
            "versionId": target_version_id,
            "localizationId": localization_id,
            "displayType": target["displayType"],
        },
        ensure_ascii=False,
    )
    return f"""
(() => {{
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const input = {payload};

  function request(method, url) {{
    const xhr = new XMLHttpRequest();
    xhr.open(method, url, false);
    xhr.withCredentials = true;
    xhr.setRequestHeader("Accept", "application/vnd.api+json");
    xhr.send(null);
    let response;
    try {{
      response = JSON.parse(xhr.responseText || "{{}}");
    }} catch {{
      response = xhr.responseText;
    }}
    if (xhr.status < 200 || xhr.status >= 300) {{
      throw new Error(JSON.stringify({{ method, url, status: xhr.status, response }}, null, 2));
    }}
    return response;
  }}

  const version = request("GET", `${{base}}/appStoreVersions/${{input.versionId}}`).data;
  const listing = request(
    "GET",
    `${{base}}/appStoreVersionLocalizations/${{input.localizationId}}/appScreenshotSets?include=appScreenshots&limit[appScreenshots]=50`
  );
  const set = (listing.data || []).find((item) =>
    item.attributes?.screenshotDisplayType === input.displayType
  );
  const ids = new Set((set?.relationships?.appScreenshots?.data || []).map((item) => item.id));
  const screenshots = (listing.included || [])
    .filter((item) => item.type === "appScreenshots" && ids.has(item.id))
    .map((item) => ({{
      id: item.id,
      fileName: item.attributes?.fileName,
      fileSize: item.attributes?.fileSize,
      state: item.attributes?.assetDeliveryState?.state,
      uploaded: item.attributes?.uploaded
    }}))
    .sort((a, b) => (a.fileName || "").localeCompare(b.fileName || ""));

  return JSON.stringify({{
    target: input.target,
    versionString: version.attributes?.versionString,
    appStoreState: version.attributes?.appStoreState,
    versionId: input.versionId,
    localizationId: input.localizationId,
    setId: set?.id,
    count: screenshots.length,
    screenshots
  }}, null, 2);
}})();
"""


def upload_file(local_path: Path, operation: dict):
    content = local_path.read_bytes()
    if len(content) != operation["length"]:
        raise ValueError(f"{local_path} has {len(content)} bytes, expected {operation['length']}")
    headers = {header["name"]: header["value"] for header in operation.get("requestHeaders", [])}
    headers["Content-Length"] = str(len(content))
    request = urllib.request.Request(
        operation["url"],
        data=content,
        method=operation["method"],
        headers=headers,
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return response.status, dict(response.headers)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Upload failed for {local_path}: {exc.code} {body}") from exc


def main() -> int:
    target = build_target()
    reservation = run_safari_js(reserve_script(target))
    print(json.dumps({"reservation": reservation}, ensure_ascii=False, indent=2))
    if not reservation.get("ok"):
        return 1

    uploaded = []
    for item in reservation["reservations"]:
        operations = item.get("uploadOperations") or []
        if not operations:
            raise RuntimeError(f"No upload operation for {item['fileName']}")
        status, headers = upload_file(ROOT / item["localPath"], operations[0])
        uploaded.append(
            {
                "screenshotId": item["screenshotId"],
                "fileName": item["fileName"],
                "status": status,
                "etag": headers.get("ETag") or headers.get("Etag"),
            }
        )
    print(json.dumps({"uploaded": uploaded}, ensure_ascii=False, indent=2))

    marked = run_safari_js(mark_uploaded_script(reservation["reservations"]))
    print(json.dumps({"markedUploaded": marked}, ensure_ascii=False, indent=2))

    latest = None
    for _ in range(12):
        latest = run_safari_js(
            final_state_script(
                target,
                reservation["targetVersionId"],
                reservation["targetLocalizationId"],
            )
        )
        states = [item.get("state") for item in latest.get("screenshots", [])]
        if states and all(state == "COMPLETE" for state in states):
            break
        time.sleep(5)
    print(json.dumps({"finalState": latest}, ensure_ascii=False, indent=2))

    if not latest or latest.get("count") != 10:
        raise RuntimeError(f"Expected 10 screenshots, found {latest.get('count') if latest else 'none'}")
    incomplete = [item for item in latest.get("screenshots", []) if item.get("state") != "COMPLETE"]
    if incomplete:
        raise RuntimeError(f"Incomplete screenshots: {incomplete}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
