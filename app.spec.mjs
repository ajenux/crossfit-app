// End-to-end check of everything the week viewer promises, against the real
// thing: the published page, its workouts.json, the Apps Script and the sheet.
//
// Writes only to the sheet's "E2E" tab (a sandbox week the page never shows
// on its own) and to that tab's rows in "Notas"/"Ediciones". Month tabs are
// only read. See README.md for the one-time setup.
import { test, expect } from '@playwright/test';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const HERE = path.dirname(fileURLToPath(import.meta.url));
// The crossfit-app checkout: its parser, venv and service-account key are reused.
const APP_DIR = path.resolve(process.env.APP_DIR || path.join(HERE, '..', 'crossfit-app'));
const PYTHON = process.env.PYTHON || path.join(APP_DIR, '.venv', 'bin', 'python');
const API = process.env.APPS_SCRIPT_URL ||
  'https://script.google.com/macros/s/AKfycbxpoPbMTXToj1dfSaOStwFZvC4dtqlT_S24Hv-O4DnJAQcLeY1C1I-dO8YSJ7SAfNWJxg/exec';
const PIN = process.env.COACH_PIN || '';
const E2E_TAB = 'E2E';
const E2E_WEEK = 'Semana 1';
const RUN = Date.now().toString(36); // makes this run's writes recognisable

// ---- helpers: sheet, script, expected rendering ------------------------------

function sheet(...args) {
  return JSON.parse(execFileSync(PYTHON, [path.join(HERE, 'sheet.py'), ...args],
    { encoding: 'utf8', env: { ...process.env, APP_DIR } }));
}

/** Calls the Apps Script; retries the odd Google error page it sometimes returns. */
async function api(body) {
  for (let attempt = 1; ; attempt++) {
    const res = body
      ? await fetch(API, { method: 'POST', headers: { 'Content-Type': 'text/plain;charset=utf-8' }, body: JSON.stringify(body) })
      : await fetch(`${API}?action=data`);
    const text = await res.text();
    try {
      return JSON.parse(text);
    } catch {
      if (attempt >= 5) throw new Error(`Apps Script returned non-JSON: ${text.slice(0, 120)}`);
      await new Promise((r) => setTimeout(r, 3000 * attempt));
    }
  }
}

const SECTION_TITLES = { '[WARMUP]': 'Estructura', '[FUERZA]': 'Fuerza', '[WOD]': 'WOD' };

function splitSections(content) {
  const blocks = [];
  for (const raw of content.split('\n')) {
    const t = raw.trim();
    if (!t) continue;
    if (SECTION_TITLES[t]) blocks.push([t, []]);
    else {
      if (!blocks.length) blocks.push(['[WARMUP]', []]);
      blocks.at(-1)[1].push(t);
    }
  }
  return blocks;
}

function joinSections(estructura, fuerza, wod) {
  const out = [];
  for (const [m, text] of [['[WARMUP]', estructura], ['[FUERZA]', fuerza], ['[WOD]', wod]]) {
    const lines = text.split('\n').map((l) => l.trim()).filter(Boolean);
    if (lines.length) out.push(m, ...lines);
  }
  return out.join('\n');
}

/** weightIndex: -1 Ambos, 0 Ale (heavier), 1 Fabita (lighter) — as the page does. */
function applyWeights(text, weightIndex) {
  if (weightIndex < 0) return text;
  return text.replace(/\(([\d,.]+)\/([\d,.]+)\)/g, (_, a, b) => {
    const na = parseFloat(a.replace(',', '.')) || 0;
    const nb = parseFloat(b.replace(',', '.')) || 0;
    const [heavy, light] = na >= nb ? [a, b] : [b, a];
    return `(${weightIndex === 0 ? heavy : light})`;
  });
}

/** The text a day card must show (its accessible name), minus the notes. */
function expectedCardText(day, weightIndex) {
  const rxc = /\b(\d+\s*RxC)\b/i.exec(day.content)?.[1];
  const body = applyWeights(day.content.replace(/\b(\d+\s*RxC)\b/i, '').trim(), weightIndex);
  const parts = [`Día ${day.day}`];
  if (rxc) parts.push(rxc);
  for (const [marker, lines] of splitSections(body)) {
    if (lines.length) parts.push(SECTION_TITLES[marker], ...lines);
  }
  return norm(parts.join(' '));
}

const norm = (s) => s.replace(/\s+/g, ' ').trim();
const iso = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const MONTHS = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

function dateRange(startIso, endIso) {
  const s = new Date(`${startIso}T00:00:00`), e = new Date(`${endIso}T00:00:00`);
  return s.getMonth() === e.getMonth()
    ? `${s.getDate()} – ${e.getDate()} ${MONTHS[e.getMonth()]}`
    : `${s.getDate()} ${MONTHS[s.getMonth()]} – ${e.getDate()} ${MONTHS[e.getMonth()]}`;
}

/** Flattens workouts.json the way the page does, oldest first. */
function flatWeeks(json) {
  return json.tabs.flatMap((t) => t.weeks.map((w) => ({ ...w, tab: t.name ?? t.title, title: t.title, month: t.month })));
}

/** Same rule as _currentWeekIndex: today's week, else last of this month, else newest. */
function currentWeek(weeks) {
  const today = iso(new Date());
  let i = weeks.findLastIndex((w) => w.start <= today && today <= w.end);
  if (i < 0) i = weeks.findLastIndex((w) => w.month === new Date().getMonth() + 1);
  return weeks[i < 0 ? weeks.length - 1 : i];
}

/** Applies coach edits newer than the build, like the page does. */
function withEdits(weeks, edits, generatedAt) {
  const built = new Date(generatedAt);
  for (const e of edits) {
    if (!(new Date(e.updated) > built)) continue;
    const w = weeks.find((x) => x.title === e.tab && x.label === e.week);
    const d = w?.days.find((x) => x.day === e.day);
    if (d) d.content = joinSections(e.estructura, e.fuerza, e.wod);
  }
  return weeks;
}

// ---- helpers: driving the page ---------------------------------------------------

const WHO = { Ambos: -1, Ale: 0, Fabita: 1 };

/**
 * Opens the page in a fresh context (a separate "device"). `who` pre-selects
 * the profile as a returning visitor; omit it to get the first-visit prompt.
 * `inject` appends a week to workouts.json (used for the E2E sandbox tab).
 */
async function openApp(browser, { who, coachPin, inject } = {}) {
  const context = await browser.newContext();
  if (inject) {
    await context.route('**/workouts.json*', async (route) => {
      const res = await route.fetch();
      const json = await res.json();
      json.tabs.push(inject.tab);
      json.generatedAt = inject.generatedAt;
      await route.fulfill({ response: res, json });
    });
  }
  const page = await context.newPage();
  await page.goto('./');
  if (who !== undefined || coachPin) {
    await page.evaluate(({ w, pin }) => {
      if (w !== undefined) localStorage.setItem('flutter.week.weightIndex', String(w));
      if (pin) localStorage.setItem('flutter.week.coachPin', JSON.stringify(pin));
    }, { w: who === undefined ? undefined : WHO[who], pin: coachPin });
    await page.reload();
  }
  await enableSemantics(page);
  return { context, page };
}

/** Flutter draws on a canvas; its accessibility tree is what Playwright can read. */
async function enableSemantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 30_000 });
  await placeholder.evaluate((el) => el.click());
  await expect(page.getByRole('heading').or(page.getByRole('alertdialog')).first()).toBeVisible();
}

async function reload(page) {
  await page.reload();
  await enableSemantics(page);
}

const dayCard = (page, n) => page.getByRole('checkbox', { name: new RegExp(`^Día ${n}\\b`) });
const cardText = async (page, n) => norm((await dayCard(page, n).getAttribute('aria-label')) ?? '');

/** Waits for notes/edits from the Apps Script to arrive. */
async function notesLoaded(page) {
  await expect(page.getByText('Cargando notas…')).toHaveCount(0, { timeout: 60_000 });
}

async function saved(page) {
  await expect(page.getByText('Guardado', { exact: true })).toBeVisible({ timeout: 60_000 });
  await expect(page.getByText('Guardado', { exact: true })).toHaveCount(0, { timeout: 15_000 });
}

/** Replaces a Flutter text field's content by typing, like a person would. */
async function typeInto(page, field, text) {
  await field.click();
  await page.keyboard.press('ControlOrMeta+a');
  await page.keyboard.press('Backspace');
  if (text) await page.keyboard.type(text);
}

// ---- the published data ------------------------------------------------------------

test.describe.serial('published data', () => {
  let json;

  test.beforeAll(async ({ request, baseURL }) => {
    const res = await request.get(new URL(`workouts.json?t=${Date.now()}`, baseURL).href);
    expect(res.ok()).toBeTruthy();
    json = await res.json();
  });

  test('workouts.json is fresh and well formed', async () => {
    const ageHours = (Date.now() - new Date(json.generatedAt)) / 36e5;
    expect(ageHours, `generatedAt ${json.generatedAt}`).toBeLessThan(26); // daily build + GitHub's delay
    expect(json.tabs.length).toBeGreaterThan(0);
    for (const tab of json.tabs) {
      expect(tab.name, tab.title).toMatch(/^[A-ZÁÉÍÓÚ][a-záéíóú]+ \d{4}$/);
      for (const w of tab.weeks) {
        const start = new Date(`${w.start}T00:00:00`), end = new Date(`${w.end}T00:00:00`);
        expect(start.getDay(), `${tab.title} ${w.label} starts on Monday`).toBe(1);
        expect((end - start) / 864e5, `${tab.title} ${w.label} spans 7 days`).toBe(6);
        expect(w.days.length).toBeGreaterThan(0);
      }
    }
  });

  test('no day has an empty Fuerza block (the Día 4 EMOM bug)', async () => {
    const empty = [];
    for (const w of flatWeeks(json)) {
      for (const d of w.days) {
        const f = splitSections(d.content).find(([m]) => m === '[FUERZA]');
        if (f && !f[1].length) empty.push(`${w.title} ${w.label} Día ${d.day}`);
      }
    }
    expect(empty).toEqual([]);
  });

  test('workouts.json matches the sheet right now', async () => {
    // Same parser as the deploy, run against the live sheet. Tabs and weeks
    // must match; day contents may lag until the next daily build, so a
    // difference there is reported rather than failed.
    const fresh = JSON.parse(execFileSync(PYTHON, ['-c', `
import json, sys; sys.path.insert(0, ${JSON.stringify(path.join(APP_DIR, 'tools'))})
import sheet_to_json as s
c = s.load_credentials(${JSON.stringify(path.join(APP_DIR, '.google-credentials.json'))})
tabs = []
for t in s.sheet_titles(c):
    my = s.month_of_tab(t)
    if my is None: continue
    w = s.parse_weeks(s.sheet_rows(c, t))
    if w: tabs.append({"title": t, "weeks": w})
print(json.dumps(tabs, ensure_ascii=False))
`], { encoding: 'utf8' }));
    const shape = (tabs) => tabs.map((t) => `${t.title}: ${t.weeks.map((w) => `${w.label}(${w.days.length})`).join(', ')}`);
    expect(shape(json.tabs)).toEqual(shape(fresh));
    const stale = [];
    json.tabs.forEach((t, i) => t.weeks.forEach((w, j) => w.days.forEach((d, k) => {
      if (d.content !== fresh[i].weeks[j].days[k].content) stale.push(`${t.title} ${w.label} Día ${d.day}`);
    })));
    if (stale.length) test.info().annotations.push({ type: 'sheet changed since last build', description: stale.join('; ') });
  });
});

// ---- the page, read-only -------------------------------------------------------

test.describe.serial('viewer', () => {
  let json, weeks, current, remote;

  test.beforeAll(async ({ request, baseURL }) => {
    json = await (await request.get(new URL(`workouts.json?t=${Date.now()}`, baseURL).href)).json();
    remote = await api();
    weeks = withEdits(flatWeeks(json), remote.edits, json.generatedAt);
    current = currentWeek(weeks);
  });

  test('first visit asks who is reading and remembers it', async ({ browser }) => {
    const { context, page } = await openApp(browser);
    const dialog = page.getByRole('alertdialog');
    await expect(dialog).toContainText('¿Quién eres?');
    for (const name of ['Ale', 'Fabita Rumana Portillo', 'Entrenador']) {
      await expect(dialog.getByRole('button', { name, exact: true })).toBeVisible();
    }
    await dialog.getByRole('button', { name: 'Fabita Rumana Portillo' }).click();
    await expect(page.getByRole('checkbox', { name: 'Fabita Rumana Portillo' })).toBeChecked();
    await reload(page);
    await expect(page.getByRole('alertdialog')).toHaveCount(0);
    await expect(page.getByRole('checkbox', { name: 'Fabita Rumana Portillo' })).toBeChecked();
    await context.close();
  });

  test('opens on the week containing today, with its dates, and browses weeks', async ({ browser }) => {
    const { context, page } = await openApp(browser, { who: 'Ale' });
    const heading = page.getByRole('heading');
    await expect(heading).toHaveAccessibleName(`${current.label} · ${dateRange(current.start, current.end)} ${current.tab}`);

    const i = weeks.indexOf(current);
    if (i > 0) {
      const prev = weeks[i - 1];
      await page.getByRole('button', { name: 'Semana anterior' }).click();
      await expect(heading).toHaveAccessibleName(`${prev.label} · ${dateRange(prev.start, prev.end)} ${prev.tab}`);
      await page.getByRole('button', { name: 'Semana siguiente' }).click();
      await expect(heading).toHaveAccessibleName(new RegExp(`^${current.label}`));
    }
    if (i === weeks.length - 1) {
      await expect(page.getByRole('button', { name: 'Semana siguiente' })).toBeDisabled();
    }
    await context.close();
  });

  for (const who of ['Ale', 'Fabita', 'Ambos']) {
    test(`every day of this week shows what the sheet says, with ${who}'s weights`, async ({ browser }) => {
      const { context, page } = await openApp(browser, { who });
      await notesLoaded(page);
      for (const day of current.days) {
        expect(await cardText(page, day.day), `Día ${day.day}`).toContain(expectedCardText(day, WHO[who]));
      }
      await context.close();
    });
  }

  test('the weight chips switch weights in place and are remembered', async ({ browser }) => {
    const day = current.days.find((d) => /\([\d,.]+\/[\d,.]+\)/.test(d.content));
    test.skip(!day, 'no (X/Y) weights in this week');
    const { context, page } = await openApp(browser, { who: 'Ambos' });
    for (const [chip, idx] of [['Ale', 0], ['Fabita Rumana Portillo', 1], ['Ambos', -1]]) {
      await page.getByRole('checkbox', { name: chip, exact: true }).click();
      await expect.poll(() => cardText(page, day.day)).toContain(expectedCardText(day, idx));
    }
    await page.getByRole('checkbox', { name: 'Ale', exact: true }).click();
    await reload(page);
    await expect(page.getByRole('checkbox', { name: 'Ale', exact: true })).toBeChecked();
    await context.close();
  });

  test('a day can be marked done and stays done after reloading', async ({ browser }) => {
    const { context, page } = await openApp(browser, { who: 'Ale' });
    const card = dayCard(page, current.days[0].day);
    await expect(card).not.toBeChecked();
    await card.click();
    await expect(card).toBeChecked();
    await reload(page);
    await expect(dayCard(page, current.days[0].day)).toBeChecked();
    await dayCard(page, current.days[0].day).click();
    await expect(dayCard(page, current.days[0].day)).not.toBeChecked();
    await context.close();
  });
});

// ---- the Apps Script on its own ------------------------------------------------------

test.describe.serial('apps script', () => {
  test('reads notes and edits', async () => {
    const data = await api();
    expect(Array.isArray(data.notes)).toBe(true);
    expect(Array.isArray(data.edits)).toBe(true);
  });

  test('rejects bad input without writing', async () => {
    const before = await api();
    expect(await api({ action: 'checkPin', pin: `wrong-${RUN}` })).toEqual({ ok: false });
    expect((await api({ action: 'editDay', pin: `wrong-${RUN}`, tab: 'Septi', week: 'Semana 1', day: 1, estructura: 'x' })).error)
      .toBe('PIN incorrecto');
    expect((await api({ action: 'note', tab: 'Septi', week: 'Semana 99', day: 1, person: 'Ale', text: 'x' })).error)
      .toMatch(/no existe Semana 99/);
    expect((await api({ action: 'note', tab: 'Septi', week: 'Semana 1', day: 1, person: 'Nadie', text: 'x' })).error)
      .toMatch(/unknown person/);
    expect((await api({ action: 'nope' })).error).toMatch(/unknown action/);
    expect(await api()).toEqual(before);
  });
});

// ---- notes and coach edits, end to end, in the E2E sandbox tab -----------------------

const BASE = {
  estructura: '4 RxC\nbase estructura',
  fuerza: '5x3 back squat (100/70)',
  wod: 'amrap 10\n10 burpees',
};

test.describe.serial('notes and coach edits (E2E tab)', () => {
  let inject;          // the sandbox week, as the page will receive it
  let before;          // E2E tab rows before this run's edits
  const T0 = new Date().toISOString();

  test.beforeAll(async () => {
    test.skip(!PIN, 'COACH_PIN missing in e2e/.env');
    // Reset the sandbox: baseline day 1, no notes.
    const reset = await api({ action: 'editDay', pin: PIN, tab: E2E_TAB, week: E2E_WEEK, day: 1, ...BASE });
    expect(reset, 'E2E tab missing? see README "End-to-end check"').toMatchObject({ ok: true });
    for (const person of ['Ale', 'Fabita']) {
      await api({ action: 'note', tab: E2E_TAB, week: E2E_WEEK, day: 1, person, text: '' });
    }
    before = sheet('tab', E2E_TAB);
    const now = new Date();
    const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - ((now.getDay() + 6) % 7));
    const sunday = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + 6);
    const week = before.weeks.find((w) => w.label === E2E_WEEK);
    // Appended last and dated this week, so the page opens on it.
    inject = {
      generatedAt: T0,
      tab: {
        title: E2E_TAB, name: E2E_TAB, month: now.getMonth() + 1, year: now.getFullYear(),
        weeks: [{ ...week, start: iso(monday), end: iso(sunday) }],
      },
    };
  });

  test('the sandbox baseline reads back through the production parser', async () => {
    const day1 = inject.tab.weeks[0].days[0];
    expect(day1.content).toBe(joinSections(BASE.estructura, BASE.fuerza, BASE.wod));
  });

  test('Ale notes weights from ready-made exercise rows; everyone sees them', async ({ browser }) => {
    const ale = await openApp(browser, { who: 'Ale', inject });
    await expect(ale.page.getByRole('heading')).toHaveAccessibleName(new RegExp(`^${E2E_WEEK} .* ${E2E_TAB}$`));
    await notesLoaded(ale.page);
    const card = dayCard(ale.page, 1);
    await expect(card.getByRole('button', { name: 'Anotar pesos de Ale' })).toBeVisible();
    await expect(card.getByRole('button', { name: 'Anotar pesos de Fabita' })).toHaveCount(0);

    await card.getByRole('button', { name: 'Anotar pesos de Ale' }).click();
    const dialog = ale.page.getByRole('alertdialog');
    await expect(dialog).toContainText('Pesos de Ale · Día 1');
    // The day's exercises are already there, reduced to their names.
    await expect(dialog).toContainText('Back squat');
    await expect(dialog).not.toContainText('5x3');
    await expect(dialog).not.toContainText('(100/70)');
    await expect(dialog).toContainText('WOD · amrap 10');
    await typeInto(ale.page, dialog.getByRole('textbox', { name: 'kg' }), '120');
    await dialog.getByRole('button', { name: 'Guardar' }).click();
    await expect(ale.page.getByText('Guardando…')).toBeVisible();
    await saved(ale.page);
    await expect.poll(() => cardText(ale.page, 1)).toContain('Ale: Back squat: 120');

    // Stored in the sheet, as plain text in the Notas tab.
    const note = (await api()).notes.find((n) => n.tab === E2E_TAB && n.week === E2E_WEEK && n.day === 1 && n.person === 'Ale');
    expect(note?.text).toBe('Back squat: 120');
    const rows = sheet('range', 'Notas!A1:F500');
    expect(rows).toContainEqual(expect.arrayContaining([E2E_TAB, E2E_WEEK, '1', 'Ale', 'Back squat: 120']));

    // Another device, as Fabita: sees Ale's note, may only edit her own.
    const fabita = await openApp(browser, { who: 'Fabita', inject });
    await notesLoaded(fabita.page);
    const fcard = dayCard(fabita.page, 1);
    expect(await cardText(fabita.page, 1)).toContain('Ale: Back squat: 120');
    await expect(fcard.getByRole('button', { name: 'Anotar pesos de Ale' })).toHaveCount(0);
    await fcard.getByRole('button', { name: 'Anotar pesos de Fabita' }).click();
    const fdialog = fabita.page.getByRole('alertdialog');
    await typeInto(fabita.page, fdialog.getByRole('textbox', { name: 'vueltas' }), `6 rondas + 3 ${RUN}`);
    await fdialog.getByRole('button', { name: 'Otro ejercicio' }).click();
    await typeInto(fabita.page, fdialog.getByRole('textbox', { name: 'Ejercicio' }), 'plank');
    await typeInto(fabita.page, fdialog.getByRole('textbox', { name: 'kg' }).last(), '90s');
    await fdialog.getByRole('button', { name: 'Guardar' }).click();
    await saved(fabita.page);
    await expect.poll(() => cardText(fabita.page, 1)).toContain(`Fabita: WOD · amrap 10: 6 rondas + 3 ${RUN} plank: 90s`);

    // Back on Ale's device: both notes after reloading.
    await reload(ale.page);
    await notesLoaded(ale.page);
    const both = await cardText(ale.page, 1);
    expect(both).toContain('Ale: Back squat: 120');
    expect(both).toContain(`Fabita: WOD · amrap 10: 6 rondas + 3 ${RUN} plank: 90s`);

    // Reopening the editor brings the saved value back into its row.
    await dayCard(ale.page, 1).getByRole('button', { name: 'Anotar pesos de Ale' }).click();
    await expect(ale.page.getByRole('alertdialog').getByRole('textbox', { name: 'kg' })).toHaveValue('120');
    // Emptying every row deletes the note.
    await typeInto(ale.page, ale.page.getByRole('alertdialog').getByRole('textbox', { name: 'kg' }), '');
    await ale.page.getByRole('alertdialog').getByRole('button', { name: 'Guardar' }).click();
    await saved(ale.page);
    await expect.poll(() => cardText(ale.page, 1)).toContain('Ale: —');
    expect((await api()).notes.some((n) => n.tab === E2E_TAB && n.person === 'Ale')).toBe(false);

    await ale.context.close();
    await fabita.context.close();
  });

  test('a wrong coach PIN is refused', async ({ browser }) => {
    const { context, page } = await openApp(browser, { who: 'Ale', inject });
    await page.getByRole('button', { name: 'Soy el entrenador' }).click();
    await typeInto(page, page.getByRole('alertdialog').getByRole('textbox'), `wrong-${RUN}`);
    await page.getByRole('alertdialog').getByRole('button', { name: 'Entrar' }).click();
    await expect(page.getByText('PIN incorrecto')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Soy el entrenador' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Editar día' })).toHaveCount(0);
    await context.close();
  });

  test('the coach edits a day from the page and it lands in the sheet', async ({ browser }) => {
    const { context, page } = await openApp(browser, { who: 'Ambos', inject });
    await notesLoaded(page);

    // Entering the PIN through the page, like the coach would.
    await page.getByRole('button', { name: 'Soy el entrenador' }).click();
    await typeInto(page, page.getByRole('alertdialog').getByRole('textbox'), PIN);
    await page.getByRole('alertdialog').getByRole('button', { name: 'Entrar' }).click();
    await expect(page.getByRole('button', { name: /Modo entrenador/ })).toBeVisible({ timeout: 60_000 });
    const card = dayCard(page, 1);
    await expect(card.getByRole('button', { name: 'Anotar pesos de Ale' })).toBeVisible();
    await expect(card.getByRole('button', { name: 'Anotar pesos de Fabita' })).toBeVisible();

    // Longer than the block, so rows must be inserted without touching the rest.
    const edit = {
      estructura: `3 RxC\ne2e estructura ${RUN}`,
      fuerza: `e2e fuerza ${RUN} (80/55)\nfuerza 2\nfuerza 3\nfuerza 4\nfuerza 5`,
      wod: `amrap 7\ne2e wod ${RUN}`,
    };
    await card.getByRole('button', { name: 'Editar día' }).click();
    const dialog = page.getByRole('alertdialog');
    await expect(dialog.getByRole('textbox', { name: /Estructura/ })).toHaveValue(BASE.estructura);
    await expect(dialog.getByRole('textbox', { name: 'Fuerza' })).toHaveValue(BASE.fuerza);
    await expect(dialog.getByRole('textbox', { name: 'WOD' })).toHaveValue(BASE.wod);
    await typeInto(page, dialog.getByRole('textbox', { name: /Estructura/ }), edit.estructura);
    await typeInto(page, dialog.getByRole('textbox', { name: 'Fuerza' }), edit.fuerza);
    await typeInto(page, dialog.getByRole('textbox', { name: 'WOD' }), edit.wod);
    await dialog.getByRole('button', { name: 'Guardar' }).click();
    await saved(page);
    const edited = { day: 1, content: joinSections(edit.estructura, edit.fuerza, edit.wod) };
    await expect.poll(() => cardText(page, 1)).toContain(expectedCardText(edited, -1));

    // The sheet cells: day 1 rewritten into its first column, markers
    // included; its second column, day 2 and the next week untouched.
    const after = sheet('tab', E2E_TAB);
    const w0 = before.weeks.findIndex((w) => w.label === E2E_WEEK);
    const start = before.rows.findIndex((r) => r[0].toLowerCase() === 'dia 1') + 1;
    const colA = after.rows.slice(start).map((r) => r[0]);
    const expectedA = [...edit.estructura.split('\n'), 'Fuerza', ...edit.fuerza.split('\n'), 'WOD', ...edit.wod.split('\n')];
    expect(colA.slice(0, expectedA.length)).toEqual(expectedA);
    const block = (rows, from, col) => rows.slice(from).map((r) => r[col]).filter(Boolean);
    const untilNextWeek = (rows) => rows.slice(start).findIndex((r) => /^semana/i.test(r[0]));
    expect(after.rows.slice(start, start + untilNextWeek(after.rows)).map((r) => r[1]).filter(Boolean)).toEqual([]);
    expect(block(after.rows, start, 2)).toEqual(block(before.rows, start, 2)); // Dia 2
    expect(after.weeks.map((w) => w.label)).toEqual(before.weeks.map((w) => w.label));
    expect(after.weeks.slice(w0 + 1)).toEqual(before.weeks.slice(w0 + 1));

    // The production parser reads it back exactly as the coach wrote it.
    expect(after.weeks[w0].days[0].content).toBe(edited.content);
    expect(after.weeks[w0].days.slice(1)).toEqual(before.weeks[w0].days.slice(1));

    // Logged in "Ediciones", and another device sees it before any rebuild.
    const log = (await api()).edits.filter((e) => e.tab === E2E_TAB).at(-1);
    expect(log).toMatchObject({ week: E2E_WEEK, day: 1, ...edit });
    const other = await openApp(browser, { who: 'Ale', inject });
    await notesLoaded(other.page);
    await expect.poll(() => cardText(other.page, 1)).toContain(expectedCardText(edited, 0));
    await expect(dayCard(other.page, 1).getByRole('button', { name: 'Editar día' })).toHaveCount(0);
    await other.context.close();

    // Leaving coach mode hides the edit buttons again.
    await page.getByRole('button', { name: /Modo entrenador/ }).click();
    await expect(page.getByRole('button', { name: 'Soy el entrenador' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Editar día' })).toHaveCount(0);
    await context.close();
  });

  test.afterAll(async () => {
    if (!PIN) return;
    await api({ action: 'editDay', pin: PIN, tab: E2E_TAB, week: E2E_WEEK, day: 1, ...BASE });
    for (const person of ['Ale', 'Fabita']) {
      await api({ action: 'note', tab: E2E_TAB, week: E2E_WEEK, day: 1, person, text: '' });
    }
  });
});
