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
TMP_SCRIPT = Path("/private/tmp/appstore_replace_iphone65_screenshots.js")

TARGETS = [
    {
        "name": "MindVault",
        "appId": "6776897058",
        "versionString": "1.0",
        "locale": "ja",
        "displayType": "APP_IPHONE_65",
        "sourceDir": "AppStoreAssets/AttachedScreenStylePreviews/MindVault/iPhone65",
        "stems": [
            "01-graph",
            "02-notes",
            "03-ai-search",
            "04-note-detail-ai",
            "05-ai-proposals",
            "06-ai-export",
            "07-settings-plan",
            "08-storekit-subscription",
            "09-new-note",
            "10-markdown-editor",
        ],
    },
    {
        "name": "SmallThanksDiary",
        "appId": "6766864082",
        "versionString": "1.0.1",
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
    },
]


def build_targets() -> list[dict]:
    targets: list[dict] = []
    for target in TARGETS:
        files = []
        source_dir = Path(target["sourceDir"])
        for stem in target["stems"]:
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
        prepared = dict(target)
        prepared["files"] = files
        prepared.pop("sourceDir")
        prepared.pop("stems")
        targets.append(prepared)
    return targets


def run_safari_js(script: str):
    TMP_SCRIPT.write_text(script, encoding="utf-8")
    output = subprocess.check_output(
        ["osascript", "-l", "JavaScript", str(RUNNER), str(TMP_SCRIPT)],
        cwd=ROOT,
        text=True,
    )
    return json.loads(output)


def create_reservations_script(targets: list[dict]) -> str:
    payload = json.dumps(targets, ensure_ascii=False)
    return f"""
(() => {{
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const targets = {payload};

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

  function getVersionAndLocalization(target) {{
    const versions = request(
      "GET",
      `${{base}}/apps/${{target.appId}}/appStoreVersions?include=appStoreVersionLocalizations&limit=20&limit[appStoreVersionLocalizations]=10`
    );
    const locsById = Object.fromEntries((versions.included || [])
      .filter((item) => item.type === "appStoreVersionLocalizations")
      .map((item) => [item.id, item]));

    const version = (versions.data || []).find((item) =>
      item.attributes?.versionString === target.versionString &&
      item.attributes?.platform === "IOS"
    );
    if (!version) {{
      throw new Error(`Version not found for ${{target.name}} ${{target.versionString}}`);
    }}

    const locRef = (version.relationships?.appStoreVersionLocalizations?.data || [])
      .find((ref) => locsById[ref.id]?.attributes?.locale === target.locale);
    if (!locRef) {{
      throw new Error(`Localization not found for ${{target.name}} locale ${{target.locale}}`);
    }}
    return {{ version, localizationId: locRef.id }};
  }}

  function getOrCreateSet(localizationId, displayType) {{
    const listing = request(
      "GET",
      `${{base}}/appStoreVersionLocalizations/${{localizationId}}/appScreenshotSets?include=appScreenshots&limit[appScreenshots]=50`
    );
    let set = (listing.data || []).find((item) => item.attributes?.screenshotDisplayType === displayType);
    if (!set) {{
      set = request("POST", `${{base}}/appScreenshotSets`, {{
        data: {{
          type: "appScreenshotSets",
          attributes: {{ screenshotDisplayType: displayType }},
          relationships: {{
            appStoreVersionLocalization: {{
              data: {{ type: "appStoreVersionLocalizations", id: localizationId }}
            }}
          }}
        }}
      }}).data;
      return {{ set, screenshots: [] }};
    }}

    const screenshotIds = new Set((set.relationships?.appScreenshots?.data || []).map((item) => item.id));
    const screenshots = (listing.included || [])
      .filter((item) => item.type === "appScreenshots" && screenshotIds.has(item.id));
    return {{ set, screenshots }};
  }}

  function deleteExistingScreenshots(screenshots) {{
    const deleted = [];
    for (const screenshot of screenshots) {{
      request("DELETE", `${{base}}/appScreenshots/${{screenshot.id}}`);
      deleted.push({{
        id: screenshot.id,
        fileName: screenshot.attributes?.fileName,
        state: screenshot.attributes?.assetDeliveryState?.state
      }});
    }}
    return deleted;
  }}

  function reserveScreenshot(setId, file) {{
    const screenshot = request("POST", `${{base}}/appScreenshots`, {{
      data: {{
        type: "appScreenshots",
        attributes: {{
          fileName: file.fileName,
          fileSize: file.fileSize
        }},
        relationships: {{
          appScreenshotSet: {{
            data: {{ type: "appScreenshotSets", id: setId }}
          }}
        }}
      }}
    }}).data;
    return {{
      screenshotId: screenshot.id,
      setId,
      localPath: file.localPath,
      fileName: file.fileName,
      fileSize: file.fileSize,
      uploadOperations: screenshot.attributes?.uploadOperations,
      assetDeliveryState: screenshot.attributes?.assetDeliveryState
    }};
  }}

  const results = [];
  for (const target of targets) {{
    const {{ version, localizationId }} = getVersionAndLocalization(target);
    const {{ set, screenshots }} = getOrCreateSet(localizationId, target.displayType);
    const deleted = deleteExistingScreenshots(screenshots);
    const reservations = target.files.map((file) => reserveScreenshot(set.id, file));
    results.push({{
      name: target.name,
      appId: target.appId,
      versionId: version.id,
      versionString: version.attributes?.versionString,
      appStoreState: version.attributes?.appStoreState,
      localizationId,
      displayType: target.displayType,
      setId: set.id,
      deleted,
      reservations
    }});
  }}
  return JSON.stringify(results, null, 2);
}})();
"""


def mark_uploaded_script(reservations: list[dict]) -> str:
    ids = [
        {
            "name": item["name"],
            "screenshotId": reservation["screenshotId"],
            "fileName": reservation["fileName"],
        }
        for item in reservations
        for reservation in item["reservations"]
    ]
    payload = json.dumps(ids, ensure_ascii=False)
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
    return {{ status: xhr.status, response }};
  }}
  return JSON.stringify(items.map((item) => {{
    const result = request("PATCH", `${{base}}/appScreenshots/${{item.screenshotId}}`, {{
      data: {{
        type: "appScreenshots",
        id: item.screenshotId,
        attributes: {{ uploaded: true }}
      }}
    }});
    return {{ ...item, status: result.status, state: result.response.data?.attributes?.assetDeliveryState?.state }};
  }}), null, 2);
}})();
"""


def fetch_state_script(targets: list[dict]) -> str:
    payload = json.dumps(
        [{k: target[k] for k in ("name", "appId", "versionString", "locale", "displayType")} for target in targets],
        ensure_ascii=False,
    )
    return f"""
(() => {{
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const targets = {payload};
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
  function versionAndLoc(target) {{
    const versions = request("GET", `${{base}}/apps/${{target.appId}}/appStoreVersions?include=appStoreVersionLocalizations&limit=20&limit[appStoreVersionLocalizations]=10`);
    const locsById = Object.fromEntries((versions.included || []).filter((item) => item.type === "appStoreVersionLocalizations").map((item) => [item.id, item]));
    const version = (versions.data || []).find((item) => item.attributes?.versionString === target.versionString && item.attributes?.platform === "IOS");
    const locRef = (version.relationships?.appStoreVersionLocalizations?.data || []).find((ref) => locsById[ref.id]?.attributes?.locale === target.locale);
    return {{ version, localizationId: locRef.id }};
  }}
  const result = [];
  for (const target of targets) {{
    const {{ version, localizationId }} = versionAndLoc(target);
    const listing = request("GET", `${{base}}/appStoreVersionLocalizations/${{localizationId}}/appScreenshotSets?include=appScreenshots&limit[appScreenshots]=50`);
    const set = (listing.data || []).find((item) => item.attributes?.screenshotDisplayType === target.displayType);
    const ids = new Set((set?.relationships?.appScreenshots?.data || []).map((item) => item.id));
    const screenshots = (listing.included || [])
      .filter((item) => item.type === "appScreenshots" && ids.has(item.id))
      .map((item) => ({{
        id: item.id,
        fileName: item.attributes?.fileName,
        fileSize: item.attributes?.fileSize,
        state: item.attributes?.assetDeliveryState?.state,
        uploaded: item.attributes?.uploaded
      }}));
    result.push({{
      name: target.name,
      versionString: version.attributes?.versionString,
      appStoreState: version.attributes?.appStoreState,
      localizationId,
      setId: set?.id,
      count: screenshots.length,
      screenshots
    }});
  }}
  return JSON.stringify(result, null, 2);
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


def upload_reservations(reservations: list[dict]) -> list[dict]:
    uploaded = []
    for item in reservations:
        for reservation in item["reservations"]:
            operations = reservation.get("uploadOperations") or []
            if not operations:
                raise RuntimeError(f"No upload operation for {item['name']} {reservation['fileName']}")
            path = ROOT / reservation["localPath"]
            status, headers = upload_file(path, operations[0])
            uploaded.append(
                {
                    "name": item["name"],
                    "screenshotId": reservation["screenshotId"],
                    "fileName": reservation["fileName"],
                    "status": status,
                    "etag": headers.get("ETag") or headers.get("Etag"),
                }
            )
    return uploaded


def main() -> int:
    targets = build_targets()
    reservations = run_safari_js(create_reservations_script(targets))
    print(json.dumps({"reservations": reservations}, ensure_ascii=False, indent=2))

    uploaded = upload_reservations(reservations)
    print(json.dumps({"uploaded": uploaded}, ensure_ascii=False, indent=2))

    marked = run_safari_js(mark_uploaded_script(reservations))
    print(json.dumps({"markedUploaded": marked}, ensure_ascii=False, indent=2))

    latest_state = None
    for _ in range(12):
        latest_state = run_safari_js(fetch_state_script(targets))
        states = [
            shot.get("state")
            for item in latest_state
            for shot in item.get("screenshots", [])
        ]
        if states and all(state == "COMPLETE" for state in states):
            break
        time.sleep(5)
    print(json.dumps({"finalState": latest_state}, ensure_ascii=False, indent=2))

    for item in latest_state or []:
        if item.get("count") != 10:
            raise RuntimeError(f"{item['name']} expected 10 screenshots, found {item.get('count')}")
        incomplete = [shot for shot in item.get("screenshots", []) if shot.get("state") != "COMPLETE"]
        if incomplete:
            raise RuntimeError(f"{item['name']} has incomplete screenshots: {incomplete}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
