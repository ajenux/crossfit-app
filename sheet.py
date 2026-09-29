#!/usr/bin/env python3
"""
Read-only sheet access for the end-to-end test, reusing the production parser.

    sheet.py tab <title>    -> {"rows": [[A..H], ...], "weeks": parse_weeks(rows)}
    sheet.py range <A1>     -> raw values of a range (e.g. "Notas!A1:F200")

Uses crossfit-app's parser and the same service account as the deploy
(read-only scope). APP_DIR points at the crossfit-app checkout (default
../crossfit-app); the key is GOOGLE_CREDENTIALS_FILE or APP_DIR/.google-credentials.json.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.abspath(os.environ.get("APP_DIR", os.path.join(HERE, "..", "crossfit-app")))
sys.path.insert(0, os.path.join(APP_DIR, "tools"))
import sheet_to_json as s  # noqa: E402


def main():
    what, arg = sys.argv[1], sys.argv[2]
    creds = s.load_credentials(os.environ.get(
        "GOOGLE_CREDENTIALS_FILE", os.path.join(APP_DIR, ".google-credentials.json")))
    if what == "tab":
        rows = s.sheet_rows(creds, arg)
        out = {"rows": [[s.cell(r, j) for j in range(8)] for r in rows],
               "weeks": s.parse_weeks(rows)}
    elif what == "range":
        url = f"{s.API}/{s.SPREADSHEET_ID}/values/{s.requests.utils.quote(arg, safe='')}"
        out = s.api_get(creds, url).get("values", [])
    else:
        sys.exit(f"unknown command {what}")
    json.dump(out, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
