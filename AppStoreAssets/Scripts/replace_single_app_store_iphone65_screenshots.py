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
TMP_SCRIPT = Path("/private/tmp/appstore_replace_single_iphone65.js")

TARGETS = {
    "SmallThanksDiary": {
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
}


def build_target(name: str) -> dict:
    target = dict(TARGETS[name])
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


def replace_script(target: dict) -> str:
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

  try {{
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
              data: {{ type: "appStoreVersionLocalizations", id: locRef.id }}
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
      appStoreState: version.attributes?.appStoreState,
      versionId: version.id,
      localizationId: locRef.id,
      setId: set.id,
      deleted,
      reservations
    }}, null, 2);
  }} catch (error) {{
    return JSON.stringify({{
      ok: false,
      target: target.name,
      error: String(error),
      logTail: log.slice(-5)
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

    target = build_target(argv[1])
    replacement = run_safari_js(replace_script(target))
    print(json.dumps({"replacement": replacement}, ensure_ascii=False, indent=2))
    if not replacement.get("ok"):
        return 1

    uploaded = []
    for reservation in replacement["reservations"]:
        operations = reservation.get("uploadOperations") or []
        if not operations:
            raise RuntimeError(f"No upload operation for {reservation['fileName']}")
        status, headers = upload_file(ROOT / reservation["localPath"], operations[0])
        uploaded.append(
            {
                "screenshotId": reservation["screenshotId"],
                "fileName": reservation["fileName"],
                "status": status,
                "etag": headers.get("ETag") or headers.get("Etag"),
            }
        )
    print(json.dumps({"uploaded": uploaded}, ensure_ascii=False, indent=2))

    marked = run_safari_js(mark_uploaded_script(replacement["reservations"]))
    print(json.dumps({"markedUploaded": marked}, ensure_ascii=False, indent=2))

    for _ in range(12):
        resumed = subprocess.run(
            [sys.executable, str(ROOT / "AppStoreAssets" / "Scripts" / "resume_app_store_iphone65_uploads.py"), argv[1]],
            cwd=ROOT,
            text=True,
            capture_output=True,
        )
        if resumed.returncode == 0:
            print(resumed.stdout)
            return 0
        time.sleep(5)

    print("Timed out waiting for screenshot processing", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
