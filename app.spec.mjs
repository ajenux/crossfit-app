// End-to-end check of everything the week viewer promises, against the real
// thing: the published page, its workouts.json, the Apps Script and the
// coach's training sheet.
//
// The coach's sheet is only read, and the last test checks it didn't change
// by a single cell. Writes go through the Apps Script to our own "Mi semana —
// datos" spreadsheet, under a made-up "E2E" month that the page never shows
// on its own (the test injects it into workouts.json). See README.md.
import { test, expect } from '@playwright/test';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const HERE = path.dirname(fileURLToPath(import.meta.url));
// The crossfit-app checkout: its parser, venv and service-account key are reused.
const APP_DIR = path.resolve(process.env.APP_DIR || path.join(HERE, '..', 'crossfit-app'));
const PYTHON = process.env.PYTHON || path.join(APP_DIR, '.venv', 'bin', 'python');
const API = process.env.APPS_SCRIPT_URL ||
  'https://script.google.com/macros/s/AKfycbxz5ULYQTK9IKqur30MJHN7utMZxUH7XLvp2Dw9hsFjBpgZny_S8-mJHj8fClIBdHCG0A/exec';
const PIN = process.env.COACH_PIN || '';
const E2E_TAB = 'E2E';
const E2E_WEEK = 'Semana 1';
const RUN = Date.now().toString(36); // makes this run's writes recognisable

// ---- helpers: sheet, script, expected rendering ------------------------------

/** Every month tab of the coach's sheet, raw rows and parsed weeks (read-only). */
function coachSheet() {
  return JSON.parse(execFileSync(PYTHON, [path.join(HERE, 'sheet.py'), 'snapshot'],
    { encoding: 'utf8', env: { ...process.env, APP_DIR }, maxBuffer: 64 << 20 }));
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
  return json.tabs.flatMap((t) => t.weeks.map((w) => ({
    ...w, tab: t.name ?? t.title, title: t.title, month: t.month,
    days: w.days.map((d) => ({ ...d, original: d.content })),
  })));
}

/** Same rule as _currentWeekIndex: today's week, else last of this month, else newest. */
function currentWeek(weeks) {
  const today = iso(new Date());
  let i = weeks.findLastIndex((w) => w.start <= today && today <= w.end);
  if (i < 0) i = weeks.findLastIndex((w) => w.month === new Date().getMonth() + 1);
  return weeks[i < 0 ? weeks.length - 1 : i];
}

const normalized = (c) => c.split('\n').map((l) => l.trim()).filter(Boolean).join('\n');

/** Applies coach edits whose base is still the day's content, like the page does. */
function withEdits(weeks, edits) {
  for (const e of edits) {
    const w = weeks.find((x) => x.title === e.tab && x.label === e.week);
    const d = w?.days.find((x) => x.day === e.day);
    if (d && normalized(e.base ?? '') === normalized(d.original)) {
      d.content = joinSections(e.estructura, e.fuerza, e.wod);
    }
  }
  return weeks;
}

// ---- helpers: driving the page ---------------------------------------------------

const WHO = { Ambos: -1, Ale: 0, Fabita: 1 };

/**
 * Opens the page in a fresh context (a separate "device"). `who` pre-selects
 * the profile as a returning visitor; omit it to get the first-visit prompt.
 * `inject` appends a tab to workouts.json (the made-up E2E month).
 */
async function openApp(browser, { who, coachPin, inject } = {}) {
  const context = await browser.newContext();
  if (inject) {
    await context.route('**/workouts.json*', async (route) => {
      const res = await route.fetch();
      const json = await res.json();
      json.tabs.push(inject);
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

/** A snackbar. Flutter also announces it in a live region; that copy is ignored. */
const toast = (page, text) => page.locator('[id^=flt-semantic-node]').getByText(text, { exact: true });

async function saved(page) {
  await expect(toast(page, 'Guardado')).toBeVisible({ timeout: 60_000 });
  await expect(toast(page, 'Guardado')).toHaveCount(0, { timeout: 15_000 });
}

/**
 * Replaces a Flutter text field's content by typing, like a person would.
 * Flutter needs a moment to attach its text input after the tap, or the
 * first keystrokes are lost; the value is checked afterwards.
 */
async function typeInto(page, field, text) {
  await expect(field).toBeVisible();
  await field.click();
  await page.waitForTimeout(400);
  await page.keyboard.press('ControlOrMeta+a');
  await page.keyboard.press('Backspace');
  if (text) await page.keyboard.type(text, { delay: 20 });
  await expect(field).toHaveValue(text);
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
    const fresh = coachSheet();
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
    weeks = withEdits(flatWeeks(json), remote.edits);
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
    expect((await api({ action: 'note', tab: 'Septi', week: 'Semana 1', day: 9, person: 'Ale', text: 'x' })).error)
      .toMatch(/dia invalido/);
    expect((await api({ action: 'note', tab: '', week: 'Semana 1', day: 1, person: 'Ale', text: 'x' })).error)
      .toMatch(/faltan tab\/week/);
    expect((await api({ action: 'note', tab: 'Septi', week: 'Semana 1', day: 1, person: 'Nadie', text: 'x' })).error)
      .toMatch(/unknown person/);
    expect((await api({ action: 'nope' })).error).toMatch(/unknown action/);
    expect(await api()).toEqual(before);
  });
});

// ---- notes and coach edits, end to end, never touching the coach's sheet ---------

// Unique per run: edits from earlier runs stay in "Ediciones" and, by design,
// would still apply to an E2E day whose content matched their base.
const BASE = {
  estructura: `4 RxC\nbase estructura ${RUN}`,
  fuerza: '5x3 back squat (100/70)',
  wod: 'amrap 10\n10 burpees',
};
const BASE_CONTENT = joinSections(BASE.estructura, BASE.fuerza, BASE.wod);

/** The made-up E2E month: one week dated this week, appended last so the page opens on it. */
function e2eTab(day1 = BASE_CONTENT) {
  const now = new Date();
  const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - ((now.getDay() + 6) % 7));
  const sunday = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + 6);
  return {
    title: E2E_TAB, name: E2E_TAB, month: now.getMonth() + 1, year: now.getFullYear(),
    weeks: [{
      label: E2E_WEEK, start: iso(monday), end: iso(sunday),
      days: [{ day: 1, content: day1 }, { day: 2, content: '[WARMUP]\n3 RxC\notro dia' }],
    }],
  };
}

test.describe.serial('notes and coach edits', () => {
  let coachBefore; // the coach's sheet before any write of this group

  test.beforeAll(async () => {
    test.skip(!PIN, 'COACH_PIN missing in .env');
    coachBefore = coachSheet();
    for (const person of ['Ale', 'Fabita']) {
      await api({ action: 'note', tab: E2E_TAB, week: E2E_WEEK, day: 1, person, text: '' });
    }
  });

  test('Ale notes weights from ready-made exercise rows; everyone sees them', async ({ browser }) => {
    const ale = await openApp(browser, { who: 'Ale', inject: e2eTab() });
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
    // Rows: Back squat [0], WOD · amrap 10 [1]. Fields lose their hint name
    // once filled, so they are addressed by position.
    await expect(dialog.getByRole('textbox', { name: 'kg' })).toHaveCount(1);
    await expect(dialog.getByRole('textbox', { name: 'vueltas' })).toHaveCount(1);
    await typeInto(ale.page, dialog.getByRole('textbox').nth(0), '120');
    await dialog.getByRole('button', { name: 'Guardar' }).click();
    await expect(toast(ale.page, 'Guardando…')).toBeVisible();
    await saved(ale.page);
    await expect.poll(() => cardText(ale.page, 1)).toContain('Ale: Back squat: 120');

    // Stored as plain text in the datos spreadsheet's Notas tab.
    const note = (await api()).notes.find((n) => n.tab === E2E_TAB && n.week === E2E_WEEK && n.day === 1 && n.person === 'Ale');
    expect(note?.text).toBe('Back squat: 120');

    // Another device, as Fabita: sees Ale's note, may only edit her own.
    const fabita = await openApp(browser, { who: 'Fabita', inject: e2eTab() });
    await notesLoaded(fabita.page);
    const fcard = dayCard(fabita.page, 1);
    expect(await cardText(fabita.page, 1)).toContain('Ale: Back squat: 120');
    await expect(fcard.getByRole('button', { name: 'Anotar pesos de Ale' })).toHaveCount(0);
    await fcard.getByRole('button', { name: 'Anotar pesos de Fabita' }).click();
    const fdialog = fabita.page.getByRole('alertdialog');
    await typeInto(fabita.page, fdialog.getByRole('textbox').nth(1), `6 rondas + 3 ${RUN}`);
    await fdialog.getByRole('button', { name: 'Otro ejercicio' }).click();
    // The new row adds a name field [2] and its value field [3].
    await expect(fdialog.getByRole('textbox')).toHaveCount(4);
    await typeInto(fabita.page, fdialog.getByRole('textbox').nth(2), 'plank');
    await typeInto(fabita.page, fdialog.getByRole('textbox').nth(3), '90s');
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
    // Flutter only mirrors a field's value into the DOM once it has focus.
    const saved120 = ale.page.getByRole('alertdialog').getByRole('textbox').nth(0);
    await saved120.click();
    await ale.page.waitForTimeout(400);
    await expect(saved120).toHaveValue('120');
    // Emptying every row deletes the note.
    await typeInto(ale.page, ale.page.getByRole('alertdialog').getByRole('textbox').nth(0), '');
    await ale.page.getByRole('alertdialog').getByRole('button', { name: 'Guardar' }).click();
    await saved(ale.page);
    await expect.poll(() => cardText(ale.page, 1)).toContain('Ale: —');
    expect((await api()).notes.some((n) => n.tab === E2E_TAB && n.person === 'Ale')).toBe(false);

    await ale.context.close();
    await fabita.context.close();
  });

  test('a wrong coach PIN is refused', async ({ browser }) => {
    const { context, page } = await openApp(browser, { who: 'Ale', inject: e2eTab() });
    await page.getByRole('button', { name: 'Soy el entrenador' }).click();
    await typeInto(page, page.getByRole('alertdialog').getByRole('textbox'), `wrong-${RUN}`);
    await page.getByRole('alertdialog').getByRole('button', { name: 'Entrar' }).click();
    await expect(toast(page, 'PIN incorrecto')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Soy el entrenador' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Editar día' })).toHaveCount(0);
    await context.close();
  });

  test('the coach edits a day from the page; it shows on top of the sheet until the sheet changes', async ({ browser }) => {
    const { context, page } = await openApp(browser, { who: 'Ambos', inject: e2eTab() });
    await notesLoaded(page);

    // Entering the PIN through the page, like the coach would.
    await page.getByRole('button', { name: 'Soy el entrenador' }).click();
    await typeInto(page, page.getByRole('alertdialog').getByRole('textbox'), PIN);
    await page.getByRole('alertdialog').getByRole('button', { name: 'Entrar' }).click();
    await expect(page.getByRole('button', { name: /Modo entrenador/ })).toBeVisible({ timeout: 60_000 });
    const card = dayCard(page, 1);
    await expect(card.getByRole('button', { name: 'Anotar pesos de Ale' })).toBeVisible();
    await expect(card.getByRole('button', { name: 'Anotar pesos de Fabita' })).toBeVisible();

    const edit = {
      estructura: `3 RxC\ne2e estructura ${RUN}`,
      fuerza: `e2e fuerza ${RUN} (80/55)\nfuerza 2`,
      wod: `amrap 7\ne2e wod ${RUN}`,
    };
    await card.getByRole('button', { name: 'Editar día' }).click();
    const dialog = page.getByRole('alertdialog');
    await expect(dialog).toContainText('el Sheet del entrenador no cambia');
    for (const [name, value] of [[/Estructura/, BASE.estructura], ['Fuerza', BASE.fuerza], ['WOD', BASE.wod]]) {
      const field = dialog.getByRole('textbox', { name });
      await field.click(); // Flutter mirrors the value into the DOM on focus
      await page.waitForTimeout(400);
      await expect(field).toHaveValue(value);
    }
    await typeInto(page, dialog.getByRole('textbox', { name: /Estructura/ }), edit.estructura);
    await typeInto(page, dialog.getByRole('textbox', { name: 'Fuerza' }), edit.fuerza);
    await typeInto(page, dialog.getByRole('textbox', { name: 'WOD' }), edit.wod);
    await dialog.getByRole('button', { name: 'Guardar' }).click();
    await saved(page);
    const edited = { day: 1, content: joinSections(edit.estructura, edit.fuerza, edit.wod) };
    await expect.poll(() => cardText(page, 1)).toContain(expectedCardText(edited, -1));

    // Logged in "Ediciones" with the day as it was ("base").
    const log = (await api()).edits.filter((e) => e.tab === E2E_TAB).at(-1);
    expect(log).toMatchObject({ week: E2E_WEEK, day: 1, ...edit });
    expect(normalized(log.base)).toBe(normalized(BASE_CONTENT));

    // Another device, same sheet content: sees the edit, can't edit.
    const other = await openApp(browser, { who: 'Ale', inject: e2eTab() });
    await notesLoaded(other.page);
    await expect.poll(() => cardText(other.page, 1)).toContain(expectedCardText(edited, 0));
    await expect(dayCard(other.page, 1).getByRole('button', { name: 'Editar día' })).toHaveCount(0);
    await other.context.close();

    // The coach later changes that day in his sheet: his version wins.
    const changed = BASE_CONTENT.replace('base estructura', `cambiado en el sheet ${RUN}`);
    const later = await openApp(browser, { who: 'Ale', inject: e2eTab(changed) });
    await notesLoaded(later.page);
    const text = await cardText(later.page, 1);
    expect(text).toContain(`cambiado en el sheet ${RUN}`);
    expect(text).not.toContain(`e2e fuerza ${RUN}`);
    await later.context.close();

    // Leaving coach mode hides the edit buttons again.
    await page.getByRole('button', { name: /Modo entrenador/ }).click();
    await expect(page.getByRole('button', { name: 'Soy el entrenador' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Editar día' })).toHaveCount(0);
    await context.close();
  });

  test("the coach's sheet did not change by a single cell", async () => {
    expect(coachSheet()).toEqual(coachBefore);
  });

  test.afterAll(async () => {
    if (!PIN) return;
    for (const person of ['Ale', 'Fabita']) {
      await api({ action: 'note', tab: E2E_TAB, week: E2E_WEEK, day: 1, person, text: '' });
    }
  });
});
