# PS4 Native Ports

[Русский](#русский) · [English](#english)

**Файлы игр в пакет не входят.** Нужна ваша собственная копия игры, снятая с вашей PS4. / **No game files are included.** You need your own copy of the game, dumped from your own PS4.

Экспериментальная сборка на основе [iss_pc](https://github.com/HayatoG/iss_pc) от HayatoG. / Experimental build based on [iss_pc](https://github.com/HayatoG/iss_pc) by HayatoG.

## Русский

### Игры

| Игра | Проверенная версия | Не работает |
|---|---|---|
| inFAMOUS First Light | CUSA00897 (EU), APP_VER 01.04 | таблицы рекордов |
| J-STARS Victory VS+ | CUSA01661 (EU) 1.00 | онлайн-бои, PSN, Share Play |
| inFAMOUS Second Son | CUSA00223 (US) 1.00 + обновление 1.07 | — |

### Папка с игрой

Снимите дамп игры со своей PS4 (GoldHEN + Itemzflow) и соберите его в одну папку: базовая игра, сверху (с заменой файлов) обновление, если оно есть. В папке должны быть `eboot.bin`, `sce_module/libc.prx`, `sce_module/libSceFios2.prx`, `sce_sys/param.sfo` и всё остальное содержимое игры. Из прошивки консоли ничего не нужно.

Подробно для Second Son (где взять `param.sfo` версии 1.07 и т. д.): https://github.com/Laitsberg/PS4-Native-Ports/blob/first-light/docs/ARQUIVOS_NECESSARIOS.md

### Компьютер

Windows 10 (1903+) / 11, 64 бита; видеокарта с Vulkan 1.3 (рекомендуется 6 ГБ видеопамяти); около 6 ГБ свободной виртуальной памяти. При 16 ГБ ОЗУ оставьте включённым файл подкачки и закройте другие тяжёлые игры.

### Как играть

1. Распакуйте архив в любую папку (не запускайте из самого .zip).
2. Запустите **PS4 Native Ports.exe**. Если появится «Система Windows защитила ваш компьютер» — *Подробнее* → *Выполнить в любом случае* (программа не подписана).
3. **Library** → **«+»** → выберите папку с игрой → нажмите на плитку → **Play**. Интерфейс лаунчера пока на английском (или португальском).

В игре: **F10** — счётчик FPS, **Insert** (или R3 + L2) — меню порта. Геймпады PlayStation, Xbox, 8BitDo и другие через SDL3, по USB или Bluetooth; клавиатура и мышь тоже работают.

Сохранения и кеш шейдеров хранятся в папке данных (по умолчанию `Документы\PS4-Native-Ports`), отдельно для каждой игры; экран **Saves & data** делает резервные копии и экспорт в `.zip`. «PS4 Native Ports (classic)» — запасной простой лаунчер, если основной не открывается.

### Проблемы

- **Фризы в первые минуты и в новых местах** — компилируются шейдеры, в следующий раз будет плавнее.
- **Игра сразу закрывается, лаунчер пишет про виртуальную память** — закройте другие игры и программы, увеличьте файл подкачки.
- **Вылет или зависание** — экран **Support** → **Report a problem** собирает отчёт и лог без личных путей. Логи лежат в `out/logs/run-*.log`. Если игра зависла с открытым окном, через 10 секунд в `out/last_run.log` появится блок `FREEZE:`.
- Проблемы, которые касаются только Second Son (RX 580, 4 ГБ видеопамяти, датчик движения и тачпад): https://github.com/Laitsberg/PS4-Native-Ports/blob/first-light/docs/SECOND_SON.md#english

## English

### Games

| Game | Tested version | Not working |
|---|---|---|
| inFAMOUS First Light | CUSA00897 (EU), APP_VER 01.04 | leaderboards |
| J-STARS Victory VS+ | CUSA01661 (EU) 1.00 | online battles, PSN, Share Play |
| inFAMOUS Second Son | CUSA00223 (US) 1.00 + update 1.07 | — |

### Game folder

Dump the game from your own PS4 (GoldHEN + Itemzflow) and merge it into one folder: the base game, with the update copied over it (replacing files) if there is one. The folder must have `eboot.bin`, `sce_module/libc.prx`, `sce_module/libSceFios2.prx`, `sce_sys/param.sfo` and the rest of the game's content. Nothing from the console firmware is needed.

Step by step for Second Son (where to get the 1.07 `param.sfo`, etc.): https://github.com/Laitsberg/PS4-Native-Ports/blob/first-light/docs/ARQUIVOS_NECESSARIOS.md#required-game-files

### PC

64-bit Windows 10 (1903+) / 11; a graphics card with Vulkan 1.3 (6 GB of VRAM recommended); about 6 GB of free virtual memory. With 16 GB of RAM, keep the page file on and close other heavy games.

### How to play

1. Extract the archive anywhere (don't run it from inside the .zip).
2. Run **PS4 Native Ports.exe**. If "Windows protected your PC" appears, click *More info* → *Run anyway* (the program is not signed).
3. **Library** → **"+"** → pick the game folder → click the tile → **Play**.

In game: **F10** toggles the FPS counter, **Insert** (or R3 + L2) opens the port's menu. PlayStation, Xbox, 8BitDo and other controllers work through SDL3 over USB or Bluetooth; keyboard and mouse work too.

Saves and the shader cache live in the data folder (`Documents\PS4-Native-Ports` by default), separately for each game; the **Saves & data** screen makes backups and `.zip` exports. "PS4 Native Ports (classic)" is a simple fallback launcher in case the main one does not open.

### Problems

- **Stutter in the first minutes and in new areas**: shaders are being compiled; it is smoother next time.
- **The game closes right away and the launcher mentions virtual memory**: close other games and programs, enlarge the page file.
- **Crash or freeze**: **Support** → **Report a problem** builds a report and a log without personal paths. Logs are in `out/logs/run-*.log`. If the game freezes with the window open, after 10 seconds `out/last_run.log` gets a `FREEZE:` block.
- Problems that only affect Second Son (RX 580, 4 GB of VRAM, motion sensor and touchpad): https://github.com/Laitsberg/PS4-Native-Ports/blob/first-light/docs/SECOND_SON.md#english

---

GPL-2.0 ([LICENSE](LICENSE)). Not affiliated with Sony Interactive Entertainment, Sucker Punch Productions, Bandai Namco Entertainment, Spike Chunsoft or Shueisha. inFAMOUS, J-STARS and other names are trademarks of their owners. / Проект не связан с Sony Interactive Entertainment, Sucker Punch Productions, Bandai Namco Entertainment, Spike Chunsoft или Shueisha.
