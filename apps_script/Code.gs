/**
 * @OnlyCurrentDoc Limits the OAuth scope to this spreadsheet only.
 */

/**
 * Write side of the week viewer. Bound to our own spreadsheet
 * ("Mi semana — datos"), never to the coach's training sheet: that one is
 * only ever read, by the daily build. With @OnlyCurrentDoc this script can't
 * even open another spreadsheet.
 *
 * Install: in the datos spreadsheet, Extensions > Apps Script, paste this
 * file, set the script property COACH_PIN, then Deploy > New deployment >
 * Web app (Execute as: Me, Who has access: Anyone). See README.
 *
 * It stores:
 *   - weight notes per day and person, in the "Notas" tab;
 *   - coach edits of a day, in the "Ediciones" tab. The page shows an edit
 *     on top of the sheet's content while that day is still as it was when
 *     the edit was made ("Base"); once the coach changes the day in his
 *     sheet, his version wins again.
 *
 * GET  ?action=data                        -> {notes: [...], edits: [...]}
 * POST {action:"checkPin", pin}             -> {ok}
 * POST {action:"note", tab, week, day, person, text}
 * POST {action:"editDay", pin, tab, week, day, estructura, fuerza, wod, base}
 * POST bodies are sent as text/plain so the browser skips the CORS preflight.
 */

var NOTES_TAB = 'Notas';
var EDITS_TAB = 'Ediciones';
var NOTES_HEADER = ['Mes', 'Semana', 'Dia', 'Persona', 'Nota', 'Actualizado'];
var EDITS_HEADER = ['Mes', 'Semana', 'Dia', 'Estructura', 'Fuerza', 'WOD', 'Base', 'Actualizado'];
var PEOPLE = ['Ale', 'Fabita'];
var MAX_TEXT = 2000;

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

/** One row per (month, week, day, person); an empty text deletes the row. */
function saveNote_(req) {
  if (PEOPLE.indexOf(req.person) < 0) throw new Error('unknown person ' + req.person);
  var key = weekKey_(req);
  var text = String(req.text || '').trim().slice(0, MAX_TEXT);

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
    var values = [key.tab, key.week, key.day, req.person, asText_(text), now];
    if (!text) {
      if (row > 0) sheet.deleteRow(row);
    } else if (row > 0) {
      sheet.getRange(row, 1, 1, values.length).setValues([values]);
    } else {
      sheet.appendRow(values);
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

/** Appends the edit; the coach's training sheet is not touched. */
function editDay_(req) {
  if (!isCoach_(req.pin)) throw new Error('PIN incorrecto');
  var key = weekKey_(req);
  var now = new Date().toISOString();
  var lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    tab_(EDITS_TAB, EDITS_HEADER).appendRow([
      key.tab, key.week, key.day,
      asText_(lines_(req.estructura).join('\n')),
      asText_(lines_(req.fuerza).join('\n')),
      asText_(lines_(req.wod).join('\n')),
      asText_(String(req.base || '').slice(0, MAX_TEXT * 3)),
      now,
    ]);
    return { ok: true, updated: now };
  } finally {
    lock.releaseLock();
  }
}

function readEdits_() {
  var sheet = SpreadsheetApp.getActive().getSheetByName(EDITS_TAB);
  if (!sheet) return [];
  // Oldest first, so the page can simply keep the last one per day.
  return sheet.getDataRange().getDisplayValues().slice(1)
      .filter(function (r) { return r[0]; })
      .map(function (r) {
        return { tab: r[0], week: r[1], day: Number(r[2]),
                 estructura: r[3], fuerza: r[4], wod: r[5], base: r[6], updated: r[7] };
      });
}

// ---- helpers -----------------------------------------------------------------

function weekKey_(req) {
  var tab = String(req.tab || '').trim();
  var week = String(req.week || '').trim();
  var day = Number(req.day);
  if (!tab || !week || tab.length > 100 || week.length > 100) throw new Error('faltan tab/week');
  if (!(day >= 1 && day <= 7 && day === Math.floor(day))) throw new Error('dia invalido');
  return { tab: tab, week: week, day: day };
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
