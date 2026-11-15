#!/usr/bin/env python3
"""Download a GitHub Actions artifact without forwarding the auth token to Azure.

Usage: python scripts/fetch_artifact.py <artifact_id> <out_zip>
"""
import os
import sys
import urllib.request
import urllib.error
import json

REPO = "Daniel123999/KazumiLite"


def token():
    path = os.path.expanduser(r"~\.config\ios9-port-release\github.token")
    with open(path, "r", encoding="ascii") as f:
        return f.read().strip()


def main():
    artifact_id = sys.argv[1]
    out_zip = sys.argv[2]
    tok = token()

    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None

    opener = urllib.request.build_opener(NoRedirect)
    url = f"https://api.github.com/repos/{REPO}/actions/artifacts/{artifact_id}/zip"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {tok}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "KazumiLite-release-script",
    })
    try:
        opener.open(req, timeout=60)
        raise SystemExit("expected redirect, got 200")
    except urllib.error.HTTPError as e:
        if e.code not in (301, 302, 303, 307, 308):
            body = e.read().decode("utf-8", "replace")
            raise SystemExit(f"HTTP {e.code}: {body}")
        location = e.headers.get("Location")
        if not location:
            raise SystemExit("redirect without Location")
        print("got signed URL")

    # Fetch the signed URL WITHOUT any Authorization header.
    req2 = urllib.request.Request(location, headers={"User-Agent": "KazumiLite-release-script"})
    with urllib.request.urlopen(req2, timeout=300) as resp, open(out_zip, "wb") as f:
        total = int(resp.headers.get("Content-Length") or 0)
        read = 0
        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            f.write(chunk)
            read += len(chunk)
        print(f"downloaded {read} bytes (content-length {total}) to {out_zip}")


if __name__ == "__main__":
    main()
