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
TMP_SCRIPT = Path("/private/tmp/appstore_resume_iphone65_uploads.js")

TARGETS = {
    "MindVault": {
        "appId": "6776897058",
        "versionString": "1.0",
        "locale": "ja",
        "displayType": "APP_IPHONE_65",
        "sourceDir": "AppStoreAssets/AttachedScreenStylePreviews/MindVault/iPhone65",
    },
    "SmallThanksDiary": {
        "appId": "6766864082",
        "versionString": "1.0.1",
        "locale": "ja",
        "displayType": "APP_IPHONE_65",
        "sourceDir": "AppStoreAssets/AttachedScreenStylePreviews/SmallThanksDiary/iPhone65",
    },
}


def run_safari_js(script: str):
    TMP_SCRIPT.write_text(script, encoding="utf-8")
    output = subprocess.check_output(
        ["osascript", "-l", "JavaScript", str(RUNNER), str(TMP_SCRIPT)],
        cwd=ROOT,
        text=True,
    )
    return json.loads(output)


def fetch_current_uploads_script(target: dict) -> str:
    payload = json.dumps(target, ensure_ascii=False)
    return f"""
(() => {{
  const base = "https://appstoreconnect.apple.com/iris/v1";
  const target = {payload};

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
  if (!version) throw new Error(`Version not found: ${{target.versionString}}`);

  const locRef = (version.relationships?.appStoreVersionLocalizations?.data || [])
    .find((ref) => locsById[ref.id]?.attributes?.locale === target.locale);
  if (!locRef) throw new Error(`Localization not found: ${{target.locale}}`);

  const listing = request(
    "GET",
    `${{base}}/appStoreVersionLocalizations/${{locRef.id}}/appScreenshotSets?include=appScreenshots&limit[appScreenshots]=50`
  );
  const set = (listing.data || []).find((item) =>
    item.attributes?.screenshotDisplayType === target.displayType
  );
  const screenshotIds = new Set((set?.relationships?.appScreenshots?.data || []).map((item) => item.id));
  const uploads = (listing.included || [])
    .filter((item) => item.type === "appScreenshots" && screenshotIds.has(item.id))
    .map((item) => ({{
      screenshotId: item.id,
      setId: set?.id,
      displayType: target.displayType,
      fileName: item.attributes?.fileName,
      fileSize: item.attributes?.fileSize,
      localPath: `${{target.sourceDir}}/${{item.attributes?.fileName}}`,
      uploadOperations: item.attributes?.uploadOperations,
      assetDeliveryState: item.attributes?.assetDeliveryState,
      uploaded: item.attributes?.uploaded
    }}))
    .sort((a, b) => (a.fileName || "").localeCompare(b.fileName || ""));

  return JSON.stringify({{
    appId: target.appId,
    versionId: version.id,
    versionString: version.attributes?.versionString,
    appStoreState: version.attributes?.appStoreState,
    localizationId: locRef.id,
    setId: set?.id,
    uploads
  }}, null, 2);
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


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] not in TARGETS:
        print(f"Usage: {argv[0]} {'|'.join(TARGETS)}", file=sys.stderr)
        return 2

    target_name = argv[1]
    state = run_safari_js(fetch_current_uploads_script(TARGETS[target_name]))
    uploads = state.get("uploads") or []
    pending = [
        item
        for item in uploads
        if (item.get("assetDeliveryState") or {}).get("state") in {"AWAITING_UPLOAD", "UPLOAD_COMPLETE"}
    ]
    if not pending:
        print(json.dumps({"target": target_name, "message": "No pending uploads", "state": state}, ensure_ascii=False, indent=2))
        return 0

    uploaded = []
    for item in pending:
        operations = item.get("uploadOperations") or []
        if not operations:
            raise RuntimeError(f"No upload operation for {target_name} {item['fileName']}")
        path = ROOT / item["localPath"]
        status, headers = upload_file(path, operations[0])
        uploaded.append(
            {
                "screenshotId": item["screenshotId"],
                "fileName": item["fileName"],
                "status": status,
                "etag": headers.get("ETag") or headers.get("Etag"),
            }
        )

    marked = run_safari_js(mark_uploaded_script(pending))
    latest_state = None
    for _ in range(12):
        latest_state = run_safari_js(fetch_current_uploads_script(TARGETS[target_name]))
        states = [
            (item.get("assetDeliveryState") or {}).get("state")
            for item in latest_state.get("uploads", [])
        ]
        if states and all(state == "COMPLETE" for state in states):
            break
        time.sleep(5)

    print(
        json.dumps(
            {
                "target": target_name,
                "uploaded": uploaded,
                "markedUploaded": marked,
                "finalState": latest_state,
            },
            ensure_ascii=False,
            indent=2,
        )
    )

    final_uploads = latest_state.get("uploads", []) if latest_state else []
    if len(final_uploads) != 10:
        raise RuntimeError(f"{target_name} expected 10 screenshots, found {len(final_uploads)}")
    incomplete = [
        item
        for item in final_uploads
        if (item.get("assetDeliveryState") or {}).get("state") != "COMPLETE"
    ]
    if incomplete:
        raise RuntimeError(f"{target_name} still has incomplete screenshots: {incomplete}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
