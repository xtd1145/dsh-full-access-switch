# Changelog

## 0.1.1 (2026-08-26)

- Fix: remove the `cordis@^4.0.1` dependency - no stable `cordis` release exists on npm (DSH ships the scoped
  `@deepseek-ai/cordis`), which made `pnpm install` (and dshbase L1 verification) fail. The bundle needs no
  runtime dependency; `cordis.patch.yml` is the cordis marker. Also dropped the `install`/`uninstall` npm
  scripts (they were convenience wrappers, not lifecycle hooks).

## 0.1.0 (2026-08-24)

- First release: one-time Full access switch for DeepSeek Harness (web profile, 0.1.1-rc.2).
- `permission.defaultPreset: danger-full-access` written to `$DSH_HOME/settings.yaml` (hot-published, no restart).
- Client-bundle patches add a persistent "don't ask again" toggle covering the settings row, the composer
  permission picker and the `/permission` popup (localStorage key `dsh.permission.skipFullAccessConfirmation`).
- `install.ps1` / `uninstall.ps1` with automatic target discovery and backups; `patches.json` table is
  byte-verified; `cordis.patch.yml` makes the repo installable as a bundle via `dsh plugin add`.
