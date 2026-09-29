/**
 * @OnlyCurrentDoc Limits the OAuth scope to this spreadsheet only.
 */

/**
 * Write-back for the week viewer, bound to the coach's training sheet.
 *
 * Install: in the sheet, Extensions > Apps Script, paste this file, set the
 * script property COACH_PIN, then Deploy > New deployment > Web app
 * (Execute as: Me, Who has access: Anyone). See README "Notes and coach edits".
 *
 * The page keeps reading workouts.json for the training itself. This script
 * only adds what a static page can't do:
 *   - weight notes per day and person, in the "Notas" tab;
 *   - coach edits of a day, written into the month tab's cells and logged in
 *     the "Ediciones" tab so the page shows them before the next daily build.
 *
 * GET  ?action=data                        -> {notes: [...], edits: [...]}
 * POST {action:"checkPin", pin}             -> {ok}
 * POST {action:"note", tab, week, day, person, text, pin?}
 * POST {action:"editDay", pin, tab, week, day, estructura, fuerza, wod}
 * POST bodies are sent as text/plain so the browser skips the CORS preflight.
 */

var NOTES_TAB = 'Notas';
var EDITS_TAB = 'Ediciones';
var NOTES_HEADER = ['Mes', 'Semana', 'Dia', 'Persona', 'Nota', 'Actualizado'];
var EDITS_HEADER = ['Mes', 'Semana', 'Dia', 'Estructura', 'Fuerza', 'WOD', 'Actualizado'];
var PEOPLE = ['Ale', 'Fabita'];
var MAX_TEXT = 2000;
var SEMANA_LABEL = /^semana\s*\d+.*$/i;

function doGet(e) {
  return handle_(function () {
    var action = (e && e.parameter && e.parameter.action) || 'data';
    if (action !== 'data') throw new Error('unknown action ' + action);
    return { notes: readNotes_(), edits: readEdits_() };
  });
}

function doPost(e) {
  return handle_(function () {
    var req = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    if (req.action === 'checkPin') return { ok: isCoach_(req.pin) };
    if (req.action === 'note') return saveNote_(req);
    if (req.action === 'editDay') return editDay_(req);
    throw new Error('unknown action ' + req.action);
  });
}

function handle_(fn) {
  var out;
  try {
    out = fn();
  } catch (err) {
    out = { error: String(err && err.message || err) };
  }
  return ContentService.createTextOutput(JSON.stringify(out))
      .setMimeType(ContentService.MimeType.JSON);
}

function isCoach_(pin) {
  var expected = PropertiesService.getScriptProperties().getProperty('COACH_PIN');
  return !!expected && String(pin || '') === expected;
}

// ---- notes -----------------------------------------------------------------

function saveNote_(req) {
  if (PEOPLE.indexOf(req.person) < 0) throw new Error('unknown person ' + req.person);
  var text = String(req.text || '').trim().slice(0, MAX_TEXT);
  var key = weekKey_(req);
  findWeek_(key.tab, key.week); // rejects notes for weeks that don't exist

  var lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    var sheet = tab_(NOTES_TAB, NOTES_HEADER);
    var rows = sheet.getDataRange().getDisplayValues();
    var row = -1;
    for (var i = 1; i < rows.length; i++) {
      if (rows[i][0] === key.tab && rows[i][1] === key.week &&
          Number(rows[i][2]) === key.day && rows[i][3] === req.person) {
        row = i + 1;
        break;
      }
    }
    var now = new Date().toISOString();
    var values = [[key.tab, key.week, key.day, req.person, asText_(text), now]];
    if (row > 0) {
      sheet.getRange(row, 1, 1, values[0].length).setValues(values);
    } else if (text) {
      sheet.appendRow(values[0]);
    }
    return { ok: true, updated: now };
  } finally {
    lock.releaseLock();
  }
}

function readNotes_() {
  var sheet = SpreadsheetApp.getActive().getSheetByName(NOTES_TAB);
  if (!sheet) return [];
  return sheet.getDataRange().getDisplayValues().slice(1)
      .filter(function (r) { return r[0] && r[4]; })
      .map(function (r) {
        return { tab: r[0], week: r[1], day: Number(r[2]), person: r[3], text: r[4], updated: r[5] };
      });
}

// ---- coach edits -----------------------------------------------------------

function editDay_(req) {
  if (!isCoach_(req.pin)) throw new Error('PIN incorrecto');
  var key = weekKey_(req);
  var parts = {
    estructura: lines_(req.estructura),
    fuerza: lines_(req.fuerza),
    wod: lines_(req.wod),
  };
  var content = parts.estructura
      .concat(parts.fuerza.length ? ['Fuerza'].concat(parts.fuerza) : [])
      .concat(parts.wod.length ? ['WOD'].concat(parts.wod) : []);

  var lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    var w = findWeek_(key.tab, key.week);
    if (key.day > w.days) throw new Error('la semana no tiene Dia ' + key.day);
    var sheet = SpreadsheetApp.getActive().getSheetByName(key.tab);
    writeDay_(sheet, w, key.day, content);

    var now = new Date().toISOString();
    tab_(EDITS_TAB, EDITS_HEADER).appendRow([
      key.tab, key.week, key.day,
      asText_(parts.estructura.join('\n')),
      asText_(parts.fuerza.join('\n')),
      asText_(parts.wod.join('\n')),
      now,
    ]);
    return { ok: true, updated: now };
  } finally {
    lock.releaseLock();
  }
}

/**
 * Rewrites one day of a week. Everything goes into the day's main column
 * (the WOD column is cleared) since the page always showed both columns
 * joined anyway. Rows are inserted when the new text is longer than the
 * week's block; the extra cells stay empty for the other days.
 * "Fuerza" and "WOD" marker lines make sheet_to_json.py split it the same way.
 */
function writeDay_(sheet, w, day, content) {
  var col = (day - 1) * 2 + 1; // 1-based main column
  var available = w.end - w.start;
  if (content.length > available) {
    var missing = content.length - available;
    if (w.end <= sheet.getMaxRows()) {
      sheet.insertRowsBefore(w.end, missing);
    } else {
      sheet.insertRowsAfter(sheet.getMaxRows(), missing);
    }
    available = content.length;
  }
  var values = [];
  for (var i = 0; i < available; i++) {
    values.push([asText_(content[i] || ''), '']);
  }
  if (available > 0) sheet.getRange(w.start, col, available, 2).setValues(values);
}

function readEdits_() {
  var sheet = SpreadsheetApp.getActive().getSheetByName(EDITS_TAB);
  if (!sheet) return [];
  // Later rows win, so the page can simply keep the last one per day.
  return sheet.getDataRange().getDisplayValues().slice(1)
      .filter(function (r) { return r[0]; })
      .map(function (r) {
        return { tab: r[0], week: r[1], day: Number(r[2]),
                 estructura: r[3], fuerza: r[4], wod: r[5], updated: r[6] };
      });
}

// ---- sheet layout (mirrors parse_weeks in tools/sheet_to_json.py) ------------

/**
 * Finds a week inside a month tab by its label ("Semana 3 - DESCARGA", or
 * "Semana N" when the coach didn't write a label). Returns 1-based rows:
 * start = first row after "Dia 1", end = first row of the next week's
 * header (its "Semana" label or "Dia 1"), or one past the last data row.
 */
function findWeek_(tabName, label) {
  var sheet = SpreadsheetApp.getActive().getSheetByName(tabName);
  if (!sheet) throw new Error('no existe la pestaña ' + tabName);
  var rows = sheet.getRange(1, 1, Math.max(sheet.getLastRow(), 1), 8).getDisplayValues();
  var weeks = locateWeeks_(rows);
  for (var i = 0; i < weeks.length; i++) {
    if (weeks[i].label === label) return weeks[i];
  }
  throw new Error('no existe ' + label + ' en ' + tabName);
}

function locateWeeks_(rows) {
  var weeks = [];
  var pending = null;
  var pendingRow = -1;
  var n = 0;
  for (var i = 0; i < rows.length; i++) {
    var a = String(rows[i][0] || '').trim();
    if (SEMANA_LABEL.test(a)) {
      pending = a;
      pendingRow = i;
      continue;
    }
    if (a.toLowerCase() === 'dia 1') {
      var headerRow = pending ? pendingRow : i;
      if (weeks.length) weeks[weeks.length - 1].end = headerRow + 1;
      n++;
      var days = rows[i].filter(function (c) {
        return String(c).trim().toLowerCase().indexOf('dia ') === 0;
      }).length || 3;
      weeks.push({ label: pending || 'Semana ' + n, start: i + 2, end: rows.length + 1, days: days });
      pending = null;
    }
  }
  // A trailing "Semana N" label with no "Dia 1" yet belongs to no week.
  if (weeks.length && pending) weeks[weeks.length - 1].end = Math.min(weeks[weeks.length - 1].end, pendingRow + 1);
  return weeks;
}

// ---- helpers -----------------------------------------------------------------

function weekKey_(req) {
  var day = Number(req.day);
  if (!req.tab || !req.week || !(day >= 1)) throw new Error('faltan tab/week/day');
  return { tab: String(req.tab), week: String(req.week), day: day };
}

function lines_(text) {
  return String(text || '').slice(0, MAX_TEXT).split('\n')
      .map(function (l) { return l.trim(); })
      .filter(function (l) { return l; });
}

/** Stops the sheet from turning "=..." (or "+", "-", "@") text into a formula. */
function asText_(s) {
  return /^[=+\-@]/.test(s) ? "'" + s : s;
}

function tab_(name, header) {
  var ss = SpreadsheetApp.getActive();
  var sheet = ss.getSheetByName(name);
  if (!sheet) {
    sheet = ss.insertSheet(name);
    sheet.appendRow(header);
    sheet.setFrozenRows(1);
  }
  return sheet;
}

if (typeof module !== 'undefined') module.exports = { locateWeeks_: locateWeeks_, writeDay_: writeDay_, lines_: lines_ };
