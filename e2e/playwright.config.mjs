import { defineConfig } from '@playwright/test';
import dotenv from 'dotenv';

// COACH_PIN (and optional overrides) live in e2e/.env, which is gitignored.
dotenv.config({ path: new URL('./.env', import.meta.url).pathname, quiet: true });

export default defineConfig({
  testDir: '.',
  testMatch: '*.spec.mjs',
  // The Apps Script answers in 2-10 s, and a run makes a few dozen calls.
  timeout: 240_000,
  expect: { timeout: 30_000 },
  workers: 1,
  reporter: [['list']],
  use: {
    baseURL: process.env.BASE_URL || 'https://ajenux.github.io/crossfit-app/',
    // The Chrome already installed on this Mac; no browser download needed.
    channel: 'chrome',
    // Tall enough that every day card of a week is laid out at once.
    viewport: { width: 430, height: 3600 },
    locale: 'es-ES',
  },
});
