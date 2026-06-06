#!/usr/bin/env python3
import json
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "AppStoreAssets" / "Scripts" / "run_safari_js.jxa"
FETCH_UPLOADS = ROOT / "AppStoreAssets" / "Scripts" / "fetch_screenshot_uploads.js"


def run_safari_script(script_path: Path):
    output = subprocess.check_output(
        ["osascript", "-l", "JavaScript", str(RUNNER), str(script_path)],
        cwd=ROOT,
        text=True,
    )
    return json.loads(output)


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


def main():
    uploads = run_safari_script(FETCH_UPLOADS)
    if not uploads:
        print("No screenshot reservations found", file=sys.stderr)
        return 1

    results = []
    for item in uploads:
        state = (item.get("assetDeliveryState") or {}).get("state")
        if state not in {"AWAITING_UPLOAD", "UPLOAD_COMPLETE"}:
            print(f"Skipping {item['fileName']} in state {state}", file=sys.stderr)
            continue

        operations = item.get("uploadOperations") or []
        if not operations:
            print(f"Skipping {item['fileName']} because there are no upload operations", file=sys.stderr)
            continue

        local_path = ROOT / item["localPath"]
        status, headers = upload_file(local_path, operations[0])
        results.append({
            "screenshotId": item["screenshotId"],
            "fileName": item["fileName"],
            "status": status,
            "etag": headers.get("ETag") or headers.get("Etag"),
        })

    print(json.dumps(results, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
