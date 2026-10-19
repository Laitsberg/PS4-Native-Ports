<h1 align="center">PS4 Native Ports</h1>

<p align="center">
  <a href="#english"><b>English below</b></a> ·
  <a href="https://github.com/Laitsberg/PS4-Native-Ports/releases/latest">Скачать / Download</a> ·
  <a href="docs/SECOND_SON.md">inFAMOUS Second Son (upstream guide)</a>
</p>

<p align="center"><a href="https://github.com/Laitsberg/PS4-Native-Ports/actions/workflows/build.yml"><img src="https://github.com/Laitsberg/PS4-Native-Ports/actions/workflows/build.yml/badge.svg?branch=first-light" alt="Build"></a></p>

> **Экспериментальная версия.** Игры запускаются и проходятся, но это ранняя сборка: возможны вылеты, подтормаживания и графические ошибки. Смотрите [Известные проблемы](#известные-проблемы).

**PS4 Native Ports** — форк [iss_pc](https://github.com/HayatoG/iss_pc) (нативный порт inFAMOUS Second Son от **HayatoG**), который запускает на ПК ещё несколько игр с PS4 на том же движке порта, и лаунчер с библиотекой игр.

Это не эмулятор процессора. PS4 построена на x86-64, поэтому код игры (`eboot.bin`) выполняется прямо на вашем процессоре. Системные библиотеки PS4 переписаны заново (`port/src/`), а графика GNM и шейдеры GCN переводятся в Vulkan/SPIR-V ядром [shadPS4](https://github.com/shadps4-emu/shadPS4).

> **Файлы игр в проект не входят.** Чтобы играть, нужна ваша собственная копия игры, снятая с вашей PS4.

## Поддерживаемые игры

| Игра | Версия, с которой проверено | Состояние |
|---|---|---|
| **inFAMOUS First Light** | CUSA00897 (EU), `eboot.bin` с APP_VER 01.04 | ✅ Проходится; 30–55 FPS, сохранения работают. Таблицы рекордов (Score Attack) не работают |
| **J-STARS Victory VS+** | CUSA01661 (EU) 1.00 | ✅ Играбельно; геймпад, сохранения и видеоролики работают. Онлайн-бои, PSN и Share Play отключены |
| **inFAMOUS Second Son** | CUSA00223 (US) 1.00 + обновление 1.07 (CUSA00004 тоже запускается) | ✅ Основная игра upstream; подробности в [руководстве Second Son](docs/SECOND_SON.md) |

Другие версии (иной регион или патч) могут не запуститься: лаунчер предупредит, если `eboot.bin` не совпадает с проверенным. Можно добавить в библиотеку и другую игру с PS4: лаунчер разрешит запуск с пометкой «не проверено», но, скорее всего, игра остановится на системной функции, которой в порте ещё нет.

## Что нужно

**Ваш дамп игры** (GoldHEN + Itemzflow на вашей PS4), собранный в одну папку (базовая игра, сверху обновление, если оно есть):

| Файл | Для чего |
|---|---|
| `eboot.bin` | код игры |
| `sce_module/libc.prx`, `sce_module/libSceFios2.prx` | собственные библиотеки игры |
| `sce_sys/` (`param.sfo`, `icon0.png`, `pic1.png`…) | данные о версии; обложка и фон в лаунчере |
| остальные папки и файлы игры (`art/`, `data/`, `*.pgm`, `*.plt`…) | содержимое игры |

Из прошивки консоли ничего не нужно. Подробная инструкция по сборке папки (на примере Second Son) — в [`docs/ARQUIVOS_NECESSARIOS.md`](docs/ARQUIVOS_NECESSARIOS.md).

**Компьютер:**
- Windows 10 (1903+) / 11, 64 бита (сборка для Linux x86-64 тоже есть, но новые игры проверены только на Windows);
- видеокарта с Vulkan 1.3, рекомендуется 6 ГБ видеопамяти;
- свободно около **6 ГБ виртуальной памяти** сверх того, что уже занято: порт сразу резервирует память, которую игра ожидает от PS4. При 16 ГБ ОЗУ включите файл подкачки и не держите открытыми другие тяжёлые игры.

## Как играть

1. Скачайте [последний релиз](https://github.com/Laitsberg/PS4-Native-Ports/releases/latest) (`ps4-native-ports-windows-x86_64.zip`) и распакуйте его.
2. Запустите **PS4 Native Ports.exe**. Если Windows покажет «Система Windows защитила ваш компьютер», нажмите *Подробнее* → *Выполнить в любом случае*: программа не подписана.
3. На экране **Library** нажмите **«+»** и выберите папку с игрой. Игра появится плиткой с обложкой из вашего дампа. Интерфейс лаунчера пока на английском (или португальском).
4. Нажмите на плитку, затем **Play**. Первые минуты возможны подтормаживания: шейдеры компилируются и кешируются.

В игре **F10** показывает счётчик FPS, **Insert** (или R3 + L2 на геймпаде) открывает меню порта. Работают DualSense, DualShock 4, Xbox и другие геймпады через SDL3, а также клавиатура и мышь.

**Данные:** сохранения и кеш шейдеров лежат в папке данных (по умолчанию `Документы\PS4-Native-Ports`), отдельно для каждой игры. Настройки — в `%APPDATA%\ps4-native-ports`. Лаунчер не пересекается с оригинальным лаунчером Second Son: их можно держать оба.

## Известные проблемы

| Ситуация | Что происходит | Что делать |
|---|---|---|
| Первый запуск, новые локации | короткие фризы, при загрузке иногда до 10–15 секунд | кеш шейдеров заполняется; при следующих запусках будет плавнее |
| Мало виртуальной памяти | игра сразу закрывается, лаунчер пишет про виртуальную память (код Windows 1450/1455) | закройте другие игры и тяжёлые программы, увеличьте файл подкачки |
| Онлайн-функции | рекорды First Light, онлайн и Share Play в J-STARS, магазин PSN недоступны | так и задумано: порт работает без PSN |
| Другая версия игры | предупреждение «не проверено» или остановка при запуске | используйте версию из таблицы выше |

Проблемы Second Son (RX 580, 4 ГБ видеопамяти и т. д.) описаны в [руководстве Second Son](docs/SECOND_SON.md#problemas-conhecidos).

## Что нового

- **First Light и J-STARS:** заглушки сетевых сервисов (NpScore, NpTus, WebApi, Matching2, Signaling, диалоги PSN, Share Play, ScreenShot и др.) и парсер `sce::Json` в рантайме, чтобы игры не останавливались на неизвестных системных функциях.
- **Лаунчер PS4 Native Ports:** библиотека игр, распознавание игры по `param.sfo`, проверка версии `eboot.bin`, отдельные сохранения и настройки для каждой игры. Графика, управление, сохранения и экспериментальные исправления BP01–BP12 из upstream сохранены.
- **Понятная ошибка при нехватке памяти** вместо молчаливого вылета.
- **Своё имя и иконка:** `PS4 Native Ports.exe`; проверка обновлений и отчёты о проблемах ведут в этот репозиторий, а не в upstream.

## Сборка из исходников

```bash
git clone --recursive -b first-light https://github.com/Laitsberg/PS4-Native-Ports.git && cd PS4-Native-Ports
cd port && ISS_LTO=OFF bash build.sh     # Linux; Windows — MSYS2 CLANG64, см. port/packaging/windows/README.md
cd .. && ./ps4_native_ports.sh           # лаунчер на Qt (нужен PySide6)
```

Полный процесс для обеих систем — в [`.github/workflows/build.yml`](.github/workflows/build.yml).

## Авторы и правовая информация

**Основа — [iss_pc](https://github.com/HayatoG/iss_pc) от HayatoG** (YouTube [@hayatog-dev](https://www.youtube.com/@hayatog-dev), Discord [discord.gg/UMkdMYZh9g](https://discord.gg/UMkdMYZh9g), [поддержать](https://github.com/sponsors/HayatoG)). Весь движок порта, лаунчер и исправления — его работа; этот форк только добавляет поддержку других игр. Если вам нравится результат, поддержите в первую очередь его.

Код, на котором построен iss_pc: [tlg_pc](https://github.com/HayatoG/tlg_pc) и [gr2_pc](https://github.com/HayatoG/gr2_pc) (HayatoG), [gow3_pc](https://github.com/FelipePrado0/gow3_pc) (FelipePrado0), [bloodborne_pc](https://github.com/deadinside28/bloodborne_pc) (deadinside28), [shadPS4](https://github.com/shadps4-emu/shadPS4) и его форк [shadPS4-Infamous-FixBuild](https://github.com/rayhlancaner-png/shadPS4-Infamous-FixBuild) (Eye Of The Ruins/rayhlancaner-png, TOXIC-KID, 0xDeftones), нативный порт [ShadowOfTheColossus-PC](https://github.com/AjncSystem/ShadowOfTheColossus-PC) (AjncSystem; с частями Pink-shadPS4 от luizgustavs). Исправления BP01–BP12 взяты также из [bloodborne_pc_windows_port](https://github.com/Mrsuss60/bloodborne_pc_windows_port) (Mrsuss), [bloodborne_pc](https://github.com/0xCydral/bloodborne_pc) (0xCydral) и [CTR](https://github.com/T3CHNOLOG1C/CTR); точные коммиты — в [`docs/EXPERIMENTAL_FIXES.md`](docs/EXPERIMENTAL_FIXES.md). Звук ATRAC9 — [LibAtrac9](https://github.com/Thealexbarney/LibAtrac9), шрифты — [FreeType](https://freetype.org); шрифты лаунчера Unbounded и Golos Text (лицензия OFL). Имена системных функций PS4 сверены с таблицами shadPS4. Благодарности тестерам upstream — в [руководстве Second Son](docs/SECOND_SON.md#acknowledgements).

Лицензия: **GPL-2.0**, как и у всех проектов выше ([LICENSE](port/LICENSE)).

Проект не связан с Sony Interactive Entertainment, Sucker Punch Productions, Bandai Namco Entertainment, Spike Chunsoft или Shueisha. inFAMOUS, J-STARS и другие названия — товарные знаки их владельцев. Здесь не распространяются код, файлы или графика игр: порт работает только с копией, которую вы сами сняли со своей консоли.

---

<a id="english"></a>

# PS4 Native Ports

> **Experimental.** The games start and can be played through, but this is an early build: crashes, stutter and graphics glitches can happen. See [Known problems](#known-problems).

**PS4 Native Ports** is a fork of [iss_pc](https://github.com/HayatoG/iss_pc) (the native inFAMOUS Second Son port by **HayatoG**) that runs a few more PS4 games on the same port runtime, with a launcher that keeps a game library.

It is not a CPU emulator. The PS4 is x86-64, so the game's code (`eboot.bin`) runs directly on your processor. The PS4 system libraries are reimplemented (`port/src/`), and GNM graphics and GCN shaders are translated to Vulkan/SPIR-V by the [shadPS4](https://github.com/shadps4-emu/shadPS4) video core.

> **No game files are included.** You need your own copy of the game, dumped from your own PS4.

## Supported games

| Game | Tested version | State |
|---|---|---|
| **inFAMOUS First Light** | CUSA00897 (EU), `eboot.bin` with APP_VER 01.04 | ✅ Playable to the end; 30–55 FPS, saves work. Leaderboards (Score Attack) are offline |
| **J-STARS Victory VS+** | CUSA01661 (EU) 1.00 | ✅ Playable; controller, saves and videos work. Online battles, PSN and Share Play are off |
| **inFAMOUS Second Son** | CUSA00223 (US) 1.00 + update 1.07 (CUSA00004 also boots) | ✅ The upstream game; details in the [Second Son guide](docs/SECOND_SON.md#english) |

Other versions (another region or patch) may not start: the launcher warns when the `eboot.bin` is not the tested one. Any other PS4 game can be added to the library too; the launcher lets it start as "untested", but it will most likely stop at a system function the port does not have yet.

## What you need

**Your own game dump** (GoldHEN + Itemzflow on your PS4), merged into one folder (base game, with the update on top if there is one):

| File | Purpose |
|---|---|
| `eboot.bin` | the game code |
| `sce_module/libc.prx`, `sce_module/libSceFios2.prx` | the game's own libraries |
| `sce_sys/` (`param.sfo`, `icon0.png`, `pic1.png`…) | version info; cover and background in the launcher |
| the rest of the game's folders and files (`art/`, `data/`, `*.pgm`, `*.plt`…) | game content |

Nothing from the console firmware is needed. A step-by-step guide to building the folder (using Second Son as the example) is in [`docs/ARQUIVOS_NECESSARIOS.md`](docs/ARQUIVOS_NECESSARIOS.md#required-game-files).

**PC:**
- 64-bit Windows 10 (1903+) / 11 (a Linux x86-64 build exists too, but the new games were only tested on Windows);
- a graphics card with Vulkan 1.3, 6 GB of VRAM recommended;
- about **6 GB of free virtual memory** on top of what is already in use: the port reserves up front the memory the game expects from a PS4. With 16 GB of RAM, keep the page file on and don't run other heavy games at the same time.

## How to play

1. Download the [latest release](https://github.com/Laitsberg/PS4-Native-Ports/releases/latest) (`ps4-native-ports-windows-x86_64.zip`) and extract it.
2. Run **PS4 Native Ports.exe**. If "Windows protected your PC" appears, click *More info* → *Run anyway*: the program is not signed.
3. On the **Library** screen click **"+"** and pick the game folder. The game shows up as a tile with the cover from your dump.
4. Click the tile, then **Play**. Expect some stutter in the first minutes while shaders are compiled and cached.

In game, **F10** toggles the FPS counter and **Insert** (or R3 + L2 on a controller) opens the port's menu. DualSense, DualShock 4, Xbox and other controllers work through SDL3, as do keyboard and mouse.

**Data:** saves and the shader cache live in the data folder (`Documents\PS4-Native-Ports` by default), separately for each game. Settings are in `%APPDATA%\ps4-native-ports`. The launcher does not share anything with the original Second Son launcher, so you can keep both.

## Known problems

| Situation | What happens | What to do |
|---|---|---|
| First run, new areas | short freezes, sometimes 10–15 seconds during loading | the shader cache is filling up; later runs are smoother |
| Not enough virtual memory | the game closes right away and the launcher says so (Windows error 1450/1455) | close other games and heavy programs, enlarge the page file |
| Online features | First Light leaderboards, J-STARS online and Share Play, the PSN store are unavailable | by design: the port runs without PSN |
| Another game version | an "untested" warning or a stop at start | use the version from the table above |

Second Son problems (RX 580, 4 GB VRAM, etc.) are in the [Second Son guide](docs/SECOND_SON.md#known-problems).

## What's new

- **First Light and J-STARS:** stubs for network services (NpScore, NpTus, WebApi, Matching2, Signaling, PSN dialogs, Share Play, ScreenShot and others) and an `sce::Json` parser in the runtime, so the games no longer stop at unknown system functions.
- **PS4 Native Ports launcher:** a game library, game detection from `param.sfo`, an `eboot.bin` version check, separate saves and settings per game. The upstream graphics, controls, saves and BP01–BP12 experimental fixes are kept.
- **A clear error when memory runs out** instead of a silent crash.
- **Own name and icon:** `PS4 Native Ports.exe`; the update check and problem reports go to this repository, not upstream.

## Building from source

```bash
git clone --recursive -b first-light https://github.com/Laitsberg/PS4-Native-Ports.git && cd PS4-Native-Ports
cd port && ISS_LTO=OFF bash build.sh     # Linux; on Windows use MSYS2 CLANG64, see port/packaging/windows/README.md
cd .. && ./ps4_native_ports.sh           # the Qt launcher (needs PySide6)
```

The full process for both platforms is in [`.github/workflows/build.yml`](.github/workflows/build.yml).

## Credits and legal notice

**Built on [iss_pc](https://github.com/HayatoG/iss_pc) by HayatoG** (YouTube [@hayatog-dev](https://www.youtube.com/@hayatog-dev), Discord [discord.gg/UMkdMYZh9g](https://discord.gg/UMkdMYZh9g), [sponsor](https://github.com/sponsors/HayatoG)). The whole port runtime, the launcher and the fixes are his work; this fork only adds support for other games. If you like the result, support him first.

Code iss_pc is built on: [tlg_pc](https://github.com/HayatoG/tlg_pc) and [gr2_pc](https://github.com/HayatoG/gr2_pc) (HayatoG), [gow3_pc](https://github.com/FelipePrado0/gow3_pc) (FelipePrado0), [bloodborne_pc](https://github.com/deadinside28/bloodborne_pc) (deadinside28), [shadPS4](https://github.com/shadps4-emu/shadPS4) and its [shadPS4-Infamous-FixBuild](https://github.com/rayhlancaner-png/shadPS4-Infamous-FixBuild) fork (Eye Of The Ruins/rayhlancaner-png, TOXIC-KID, 0xDeftones), the native [ShadowOfTheColossus-PC](https://github.com/AjncSystem/ShadowOfTheColossus-PC) port (AjncSystem; with parts of Pink-shadPS4 by luizgustavs). The BP01–BP12 fixes also come from [bloodborne_pc_windows_port](https://github.com/Mrsuss60/bloodborne_pc_windows_port) (Mrsuss), [bloodborne_pc](https://github.com/0xCydral/bloodborne_pc) (0xCydral) and [CTR](https://github.com/T3CHNOLOG1C/CTR); exact commits are in [`docs/EXPERIMENTAL_FIXES.md`](docs/EXPERIMENTAL_FIXES.md). ATRAC9 audio via [LibAtrac9](https://github.com/Thealexbarney/LibAtrac9), fonts via [FreeType](https://freetype.org); launcher fonts Unbounded and Golos Text (OFL). PS4 system function names were checked against shadPS4's tables. Upstream tester acknowledgements are in the [Second Son guide](docs/SECOND_SON.md#acknowledgements).

License: **GPL-2.0**, like every project above ([LICENSE](port/LICENSE)).

This project is not affiliated with Sony Interactive Entertainment, Sucker Punch Productions, Bandai Namco Entertainment, Spike Chunsoft or Shueisha. inFAMOUS, J-STARS and other names are trademarks of their owners. No game code, files or art are distributed here: the port only works with a copy you dumped from your own console.
