#!/usr/bin/env python3
"""
Reads the coach's training Google Sheet and writes a static workouts.json.

No backend involved: this runs in a GitHub Action (or locally) with the
service account credentials and the output is published next to the
Flutter web build on GitHub Pages.

Usage:
    GOOGLE_CREDENTIALS_JSON='{...}' python3 tools/sheet_to_json.py out/workouts.json
    python3 tools/sheet_to_json.py --credentials .google-credentials.json out/workouts.json

The parsing rules mirror GoogleSheetsService.java: one month per tab, weeks
start at a "Dia 1" header row (optionally preceded by a "Semana N" label),
each day uses two columns (main block + WOD block), and section markers
[WARMUP] / [FUERZA] / [WOD] are inserted by content heuristics.
"""
import argparse
import datetime as dt
import json
import os
import re
import sys

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

SPREADSHEET_ID = os.environ.get("GOOGLE_SHEETS_SPREADSHEET_ID", "1LUksfUebyzp2ZeplLAFEmOlvwbgBOOlw25JU7ivbUgk")
SCOPES = ["https://www.googleapis.com/auth/spreadsheets.readonly"]
API = "https://sheets.googleapis.com/v4/spreadsheets"

WOD_HEADER = re.compile(r".*(amrap|emom|for time|rxt|a completar|chipper|\d+(-\d+){2,}).*", re.I)
SEMANA_LABEL = re.compile(r"^semana\s*\d+.*$", re.I)

MONTH_NAMES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
               "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
MONTH_ALIASES = {"maio": 5, "setiembre": 9}


def month_of_tab(title):
    """Returns (month, year) for a tab title, or None.

    The coach abbreviates freely ('Sep', 'Sept', 'Septi', 'Agos', 'Juni'), so
    any first word of 3+ letters that is a prefix of a month name matches.
    """
    parts = title.strip().lower().split()
    if not parts:
        return None
    word = parts[0]
    month = MONTH_ALIASES.get(word)
    if month is None and len(word) >= 3:
        for i, name in enumerate(MONTH_NAMES, start=1):
            if name.startswith(word):
                month = i
                break
    if month is None:
        return None
    year = None
    for p in parts[1:]:
        if p.isdigit() and len(p) == 4:
            year = int(p)
    return month, year


def load_credentials(path):
    if path:
        with open(path) as f:
            info = json.load(f)
    else:
        raw = os.environ.get("GOOGLE_CREDENTIALS_JSON", "")
        if not raw.strip():
            sys.exit("GOOGLE_CREDENTIALS_JSON is not set and no --credentials file given")
        info = json.loads(raw)
    creds = service_account.Credentials.from_service_account_info(info, scopes=SCOPES)
    creds.refresh(Request())
    return creds


def api_get(creds, url, params=None):
    r = requests.get(url, params=params, headers={"Authorization": f"Bearer {creds.token}"}, timeout=30)
    r.raise_for_status()
    return r.json()


def sheet_titles(creds):
    data = api_get(creds, f"{API}/{SPREADSHEET_ID}", {"fields": "sheets.properties.title"})
    return [s["properties"]["title"] for s in data.get("sheets", [])]


def sheet_rows(creds, title):
    data = api_get(creds, f"{API}/{SPREADSHEET_ID}/values/{requests.utils.quote(title + '!A1:H600', safe='')}")
    return data.get("values", [])


def cell(row, i):
    return row[i].strip() if i < len(row) else ""


def add_section_markers(raw):
    if not raw.strip():
        return raw
    out = ["[WARMUP]"]
    fuerza = wod = False
    for line in raw.split("\n"):
        t = line.strip()
        low = t.lower()
        if not fuerza and not wod and low == "fuerza":
            fuerza = True
            out.append("[FUERZA]")
            continue
        if not wod and WOD_HEADER.match(low):
            wod = True
            out.append("[WOD]")
        out.append(t)
    return "\n".join(out).strip()


def build_week(block, label):
    header = block[0]
    day_count = sum(1 for c in header if c.strip().lower().startswith("dia "))
    if day_count == 0:
        day_count = 3

    main = {d: [] for d in range(1, day_count + 1)}
    wod = {d: [] for d in range(1, day_count + 1)}
    for row in block[1:]:
        if row and SEMANA_LABEL.match(cell(row, 0)):
            continue
        for d in range(1, day_count + 1):
            col_main = (d - 1) * 2
            v = cell(row, col_main)
            if v:
                main[d].append(v)
            v = cell(row, col_main + 1)
            if v:
                wod[d].append(v)

    days = []
    for d in range(1, day_count + 1):
        # WOD column is appended after the main column so the [WOD] marker lands last.
        combined = "\n".join(main[d] + wod[d]).strip()
        days.append({"day": d, "content": add_section_markers(combined)})
    return {"label": label, "days": days}


def parse_weeks(rows):
    weeks = []
    week_start = -1
    week_number = 1
    pending = current = None
    for i, row in enumerate(rows):
        a = cell(row, 0)
        if SEMANA_LABEL.match(a):
            pending = a
            continue
        if a.lower() == "dia 1":
            if week_start >= 0:
                weeks.append(build_week(rows[week_start:i], current))
                week_number += 1
            week_start = i
            current = pending if pending else f"Semana {week_number}"
            pending = None
    if week_start >= 0:
        weeks.append(build_week(rows[week_start:], current))
    return weeks


MONTH_DISPLAY = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio",
                 "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]


def assign_years(tabs):
    """Fills in `year` and a display `name` ("Septiembre 2026") for every tab.

    Tab titles rarely carry a year, but tabs are in chronological order, so:
    the newest tab belongs to the current year (or the previous one if its
    month is still ahead of today), and walking backwards the year drops by
    one each time the month number goes up (Enero <- Diciembre).
    """
    if not tabs:
        return
    today = dt.date.today()
    year = tabs[-1]["year"] or (today.year if tabs[-1]["month"] <= today.month else today.year - 1)
    prev_month = None
    for tab in reversed(tabs):
        if tab["year"] is not None:
            year = tab["year"]
        elif prev_month is not None and tab["month"] > prev_month:
            year -= 1
        tab["year"] = year
        tab["name"] = f"{MONTH_DISPLAY[tab['month'] - 1]} {year}"
        prev_month = tab["month"]


WEEK_NUMBER = re.compile(r"semana\s*(\d+)", re.I)


def assign_dates(tab):
    """Adds `start`/`end` (ISO dates, Monday to Sunday) to each week of a tab.

    The coach's "Semana 1" is the week containing the 1st of the month, and
    each following "Semana N" is 7 days later. When a label has no number,
    the week's position in the tab is used.
    """
    first = dt.date(tab["year"], tab["month"], 1)
    week1_monday = first - dt.timedelta(days=first.weekday())
    for i, week in enumerate(tab["weeks"]):
        m = WEEK_NUMBER.match(week["label"])
        n = int(m.group(1)) if m else i + 1
        start = week1_monday + dt.timedelta(days=7 * (n - 1))
        week["start"] = start.isoformat()
        week["end"] = (start + dt.timedelta(days=6)).isoformat()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("output")
    ap.add_argument("--credentials", help="path to service account JSON (defaults to GOOGLE_CREDENTIALS_JSON env)")
    args = ap.parse_args()

    creds = load_credentials(args.credentials)
    titles = sheet_titles(creds)

    tabs = []
    for title in titles:
        my = month_of_tab(title)
        if my is None:
            print(f"skipping tab {title!r}: not a month name")
            continue
        rows = sheet_rows(creds, title)
        weeks = parse_weeks(rows)
        if not weeks:
            continue
        tabs.append({"title": title, "month": my[0], "year": my[1], "weeks": weeks})

    assign_years(tabs)
    for tab in tabs:
        assign_dates(tab)

    result = {
        "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "tabs": tabs,
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "w") as f:
        json.dump(result, f, ensure_ascii=False, indent=1)
    print(f"wrote {args.output}: {len(tabs)} tabs, {sum(len(t['weeks']) for t in tabs)} weeks")


if __name__ == "__main__":
    main()
