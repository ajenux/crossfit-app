#!/usr/bin/env python3
"""
Read-only view of the coach's training sheet for the end-to-end test,
through crossfit-app's own parser and service account (read-only scope).

    sheet.py snapshot   -> [{"title", "rows", "weeks"}] for every month tab

APP_DIR points at the crossfit-app checkout (default ../crossfit-app); the
key is GOOGLE_CREDENTIALS_FILE or APP_DIR/.google-credentials.json.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.abspath(os.environ.get("APP_DIR", os.path.join(HERE, "..", "crossfit-app")))
sys.path.insert(0, os.path.join(APP_DIR, "tools"))
import sheet_to_json as s  # noqa: E402


def main():
    if sys.argv[1:] != ["snapshot"]:
        sys.exit("usage: sheet.py snapshot")
    creds = s.load_credentials(os.environ.get(
        "GOOGLE_CREDENTIALS_FILE", os.path.join(APP_DIR, ".google-credentials.json")))
    tabs = []
    for title in s.sheet_titles(creds):
        if s.month_of_tab(title) is None:
            continue
        rows = s.sheet_rows(creds, title)
        weeks = s.parse_weeks(rows)
        if weeks:
            tabs.append({"title": title, "rows": rows, "weeks": weeks})
    json.dump(tabs, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
