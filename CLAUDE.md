# PS4 Native Ports — notes for Claude

Fork of [HayatoG/iss_pc](https://github.com/HayatoG/iss_pc) (native inFAMOUS Second Son port) that runs more
PS4 games on the same runtime and ships a launcher with a game library. The owner (Laitsberg) speaks
Russian: answer in Russian; code, comments and commit messages in English.

## Repository

- `origin` = `Laitsberg/PS4-Native-Ports`, working branch **`first-light`** (the default branch). `main`
  mirrors upstream; `upstream` = `HayatoG/iss_pc`. Merge upstream into `first-light` only after checking
  it does not break First Light / J-STARS.
- Merging upstream (last: `fb7e452`, 2026-10-19): keep **our** `.github/workflows/build.yml` (upstream
  releases by hand from `main`; we release on every push to `first-light`), our README / README-player and
  our launcher design (port their functional changes into it). After a merge check
  `qt/updater.py` `ASSET_NAMES` (our `ps4-native-ports-*` package names) and give new strings a line in
  `ru.json`. Never `git stash` in the middle of a merge: it drops the merge state.
- Every push to `first-light` runs `.github/workflows/build.yml` (Linux + Windows packages, launcher
  `--selftest`, then a release `vYYYY.MM.DD-<sha>` marked Latest). A new push cancels the running build,
  so batch commits. ~30–40 min per build.
- Package: `ps4-native-ports-windows-x86_64.zip` → `PS4 Native Ports.exe` (Qt), `PS4 Native Ports (classic).exe`
  (Tk), `Play PS4 Native Ports.exe`, `out/tlg-probe.exe`. Names come from `port/packaging/port.env`.

## How the port works

The eboot is x86-64 and runs natively; `tlg-probe` is the HLE runtime (C, `port/src/runtime_*.c`) plus
the shadPS4 video core (`port/gpu/`, GNM → Vulkan, GCN → SPIR-V).

Pipeline (driven by `port/launcher/infamous_run.py`): `port/scripts/prepare.py` → `link_modules.py`
(game's own `libc.prx`, `libSceFios2.prx`) → `content_profile.py` → `infamous_patches.py` →
`isa_rewrite.py --red-zone` → `tlg-probe boot-linked.bin --app0 <game> --user <user> ...`.

Imports resolve NID#library → name through `port/src/import_names.inc`, then name → host function
through the `{"name", func}` tables (`RUNTIME_LOOKUP`). **An unresolved import stops the game with exit
code 20** and a `STOP` line naming it.

### Bringing up a new game / fixing a STOP

1. Read the `STOP` line in `out/logs/run-*.log` (`out/last_run.log`).
2. Find the NID's name in shadPS4's `aerolib.inl`; add it to `import_names.inc`.
3. Implement or stub it (network/PSN things go in `runtime_services.c`: helpers `ok_void`,
   `np_signed_out`, `np_request_ctx`, `np_poll`; JSON in `runtime_gr2_json.c`). Offline is the rule:
   return "signed out"/"not available" codes the game already handles.
4. Add a profile to `port/launcher/games.py` (title ids, save serial, tested eboot `(entry, image size)`,
   `motion_toggle`) and a test in `port/tests/test_games.py`.

## Games

| Game | Title id | Tested eboot (entry, image size) | Notes |
|---|---|---|---|
| inFAMOUS Second Son | CUSA00223 / CUSA00004 | `0x61dfd0`, 133846143 (1.07) | upstream game; xpps shader precompile, mods |
| inFAMOUS First Light | CUSA00897 (EU) | `0x6ffd70`, 136535375 (APP_VER 01.04) | 30–55 FPS, two ~13 s freezes on loads, saves OK; leaderboards offline; L3+R3 sensor mode kept |
| J-STARS Victory VS+ | CUSA01661 (EU 1.00) | `0x305890`, 8583040 | locked 30 FPS, stable; online/Share Play offline; L3+R3 sensor mode off (`ISS_MOTION_TOGGLE=off`) |

Unknown games get an "untested" profile from `param.sfo` and may still be launched.

## Launcher (`port/launcher/`)

Qt Quick (PySide6) in `qt/` (QML in `qt/qml/Launcher/`, strings in `qt/i18n/strings.json` — pt/en only,
append keys at the end, keep the file's formatting). Russian (`ru_RU`) is `qt/i18n/ru.json`: English text →
Russian, used for every (en, pt) pair the Qt launcher shows (strings.json, Tk texts, fix tables); a text
without a line there stays English, so a new key needs a line in ru.json too (`test_qt_russian` lists the
missing ones). The in-game Insert menu and the Tk launcher stay pt/en. `games.py` = profiles and detection;
`userdata.py` = data folder (`Documents/PS4-Native-Ports`, pointer `%APPDATA%/PS4-Native-Ports/launcher.json`);
settings `%APPDATA%/ps4-native-ports/settings.json` — deliberately separate from the upstream Second Son
launcher. Update check and problem reports point to `Laitsberg/PS4-Native-Ports` (`qt/releases.py`, `qt/report.py`).
Runtime exit code 25 = Windows refused the ~6 GB memory reservation (error 1450/1455) → `err_virtual_memory`.

## Tests

`cd port/tests && python3 -m unittest test_games test_userdata test_qt_support test_backports_table test_qt_russian test_steam_shortcuts`.
`test_qt_launcher` has two failures that also fail upstream (`TranslationTests`); ignore them.
C runtime needs SDL3 headers to compile; CI is the real build check.

## Rules

- Never commit game files (eboot, prx, sfo, psarc, art, saves, dumps); `port/packaging/check_package.sh` guards the package.
- Players use their own dump from their own console (GoldHEN + Itemzflow). Never mention or link any
  other source of game files, in code, docs, commits or chat.
- GPL-2.0; keep upstream credits (README, `docs/SECOND_SON.md`, `docs/EXPERIMENTAL_FIXES.md`).
- Commits: `Area: what changed`, short body explaining why.

## Open work

See `docs/SURVEY_PORTS_2026-10.md` (what other native PS4 ports have that we can take, by priority).

- First Light: shader stutter (the xpps precompile is built from Second Son 1.07 tables; adapting it is the
  main lever), the two long load freezes.
- Ideas: The Order: 1886 (a separate native port already exists: mateussmeneses/theorder1886-port).
