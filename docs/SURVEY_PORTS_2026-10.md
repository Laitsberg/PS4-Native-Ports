# Обзор других нативных портов PS4 (октябрь 2026)

Источник списка: [framesgames.com — «Волна нативных PC-портов PS4»](https://framesgames.com/ru/ps4-native-pc-ports-wave-ru/).
Проверено 18.10.2026 по свежим клонам (последний коммит каждого репозитория — 10–19 октября).

## Кто есть кто

Почти все порты — из одной семьи с нашим: загрузчик bbport (Bloodborne) → tlg_pc / gow3_pc → остальные.
Та же раскладка `src/` (HLE-рантайм на C), `gpu/` (видеоядро shadPS4), `launcher/` (Python), поэтому
код переносится почти напрямую. Лицензия у всех — **GPL-2.0**, как у нас (кроме P.T. — MIT): брать можно,
сохраняя авторство и указывая источник в коммите и README.

| Порт | Репозиторий | Родство | Что интересного |
|---|---|---|---|
| Bloodborne | deadinside28/bloodborne_pc | bbport (исходный) | FSR 3.1/4/4.1.1 с векторами движения; доки upscaler/motion_vectors |
| Bloodborne | Supermedo/bloodborne_pc | bbport | **резерв памяти с ленивым коммитом (ошибка 1450)**; DLSS; автообновление |
| Uncharted Collection | Supermedo/uncharted_pc | bbport | **«Добавить в Steam»**, **автообновление**, DLSS/FSR, Videodec2 |
| God of War III | FelipePrado0/gow3_pc | gow3 (наш предок) | фоновая загрузка кеша шейдеров; ярлык; 120 FPS |
| Killzone Shadow Fall | lesca-191204/killzone-shadowfall-pc | gow3 | 79 системных функций, которых у нас нет |
| The Order: 1886 | mateussmeneses/theorder1886-port | gow3 | **«горячий» прогрев шейдеров, фоновые compute-конвейеры, отсев гигантских текстур** |
| The Order: 1886 | lxnis/Order1886-PC | gow3 | 89 новых функций; мост DLSS |
| Shadow of the Colossus | AjncSystem/ShadowOfTheColossus-PC | gow3 | (уже частично у нас: BP06) |
| UFC 3 | GNSB/UFC-3-PS4-PORT-LINUX-WINDOWS | bbport | **детерминированные RCPPS/RSQRTPS** (Intel = AMD); 84 новых функции |
| MediEvil | bc160201983/medievil_2019_pc_port | gow3 | 142 новых функции |
| Unicorn Overlord / Odin Sphere | hachi23/unicorn_overlord_pc | gow3 | 186 новых функций (больше всех) |
| Dragon's Crown Pro | saulob/dragons-crown-pro-pc | свой CMake, ядро shadPS4 | 79 новых функций; соотношения сторон |
| DriveClub | OverkillLabs3/driveclub-recomp | bbport | DLSS/FSR 3.1 как сглаживание |
| DriveClub | qnfn/Driveclub-Port | своя архитектура | мало пригодного |
| Gran Turismo Sport | mlgprorektm8/RyGT | своя (конвертер eboot → exe) | мало пригодного |
| P.T. | LoreanXavier/pt-pc | свой движок, не порт бинарника | не применимо |
| Crash Team Racing | T3CHNOLOG1C/SacredFire | — | **репозиторий удалён (404)**: код оттуда не берём |
| The Last Guardian, Gravity Rush 2 | HayatoG/tlg_pc, gr2_pc | наши «братья» | 60 FPS для TLG (`docs/60fps.md`) |

Патчей сообщества для First Light и J-STARS нет ни в GoldHEN_Patch_Repository, ни в
illusion0001/PS4-PS5-Game-Patch, так что готовых «60 FPS»-патчей под наши игры не найдено.

## Что взять — по приоритету

### 1. Память: ленивый коммит вместо отказа (ошибка 1450) — высокий приоритет, ~40 строк

**Откуда:** Supermedo/bloodborne_pc, `src/runtime_memory.c` (`pool()`, `commit_backing()`, `commit_on_map`).

Сейчас мы просим у Windows сразу ~6 ГБ (`CreateFileMapping2(... SEC_COMMIT ...)`). На 16 ГБ ОЗУ с открытыми
браузером и другой игрой Windows отказывает, и порт закрывается с кодом 25. У Supermedo при ошибке
`ERROR_COMMITMENT_LIMIT` / `ERROR_NO_SYSTEM_RESOURCES` секция создаётся с `SEC_RESERVE`, а память
коммитится кусками (`VirtualAlloc(MEM_COMMIT)`) только когда игра её реально отображает. Наш
`runtime_memory.c` из той же семьи: перенос почти один в один. Код 25 останется только для случая,
когда памяти действительно не хватает.

### 2. Долгие фризы при загрузках — высокий приоритет, сначала диагностика

**Откуда:** mateussmeneses/theorder1886-port (`docs/PROGRESS.md`, записи 15–17.10).

У The Order были те же симптомы, что и наши 13-секундные фризы в First Light. Помогли три вещи:
- compute-конвейеры, которые игра раньше не использовала, собираются в фоне, а их dispatch пропускается,
  пока сборка не закончится. Задержки упали с 9,4 с до 0,1 с за 40 с игры. У нас есть похожий
  `ISS_COMPUTE_ASYNC_BUILD`, нужно сравнить с их `THEORDER_ASYNC_COMPUTE` и `FallbackComputePipeline`;
- текстуры с вычисленным размером больше 512 МБ (мусорные дескрипторы) привязываются как null,
  иначе в видеопамять заливалось 1,3–3,3 ГБ и игра замирала на 1–3 с;
- строки `Stall:` в логе раскладывают время компиляции: перевод / SPIR-V / драйвер.

**Шаг 0:** открыть лог First Light (`out/logs/run-*.log` с CUSA00897) и найти, что происходило во время
фриза (строки `Frame stats` с `worst frame` в тысячи мс, `FREEZE:`). От этого зависит, какое из трёх
исправлений нужно.

### 3. «Горячий» прогрев шейдеров — средний приоритет

**Откуда:** тот же порт The Order, `vk_pipeline_serialization.cpp` (`StartHotWarmUp`, `NoteHot`,
`hot_pipelines.txt`).

Наш фоновый прогрев (`StartBackgroundWarmUp`) уже работает для всех игр, начиная со второго запуска.
Но он прогревает весь кеш подряд. В The Order каждая сессия записывает конвейеры, которые реально
использовались (последние 2000), и следующая прогревает сначала их, начиная с самых свежих: место,
где закончилась прошлая сессия, обычно оказывается первым в новой. Когда кеш вырастет, это даст
меньше фризов в начале игры.

### 4. Лаунчер — средний приоритет, мало риска

- **Добавить в Steam** (не-Steam ярлык через `shortcuts.vdf`): Supermedo/uncharted_pc,
  `launcher/bbport_steam.py`. Это 144 строки на чистом Python, переносится в наш Qt-бэкенд как есть.
- **Настоящее автообновление** (скачать zip, дождаться выхода лаунчера, заменить файлы, перезапустить):
  Supermedo, `install_update()` в `bbport_launcher_win.py`. Сейчас наш экран «Updates» только открывает
  страницу релиза.
- **Ярлык на рабочем столе**: gow3_pc, killzone, The Order.
- **Русский интерфейс**: у Supermedo, AjncSystem, UFC и других есть ru-строки, их формулировки можно
  взять за основу; в `strings.json` нужно добавить язык `ru`.

### 5. Запас системных функций для новых игр — по мере надобности

У других портов есть **402 функции PS4**, которых нет у нас. Больше всего у hachi23 (186), MediEvil (142),
lxnis/Order (89), UFC (84), Dragon's Crown (79), Killzone (79). Чаще всего встречаются PlayGo
(`scePlayGoPrefetch`), служебные функции ядра (`sceKernelUtimes`, `sceKernelChmod`,
`sceKernelAvailableDirectMemorySize`), колбэки UserService/NpToolkit, NpWebApi, NpAuth, WordFilter,
InGameMessage, WebBrowserDialog, VideoRecording, GameLiveStreaming, Ime и Font.

Как пользоваться: когда новая игра останавливается на `STOP` из-за неизвестной функции, сначала ищем её
реализацию здесь, а не пишем с нуля. Полный список с источниками можно пересобрать скриптом из этого
обзора: функции в таблицах `{"имя", функция}` в `src/` каждого порта, минус наши.

### 6. Детерминированные RCPPS/RSQRTPS — «страховка», низкий приоритет

**Откуда:** GNSB/UFC-3, `src/runtime_fp.c`.

Процессоры Intel и AMD дают разный результат для приблизительных `rcpps`/`rsqrtps`. PS4 — это AMD,
и игра рассчитана на его ответы. UFC при загрузке заменяет каждую такую инструкцию переходом на заглушку,
которая выдаёт результат в формате AMD, одинаковый на любом процессоре. В First Light таких мест 4537,
в J-STARS — 395. Брать имеет смысл только если на Intel появятся баги, которых нет на AMD (физика,
анимации), и как опцию: это чуть замедляет игру.

### 7. FSR 3.1 / FSR 4 / DLSS — низкий приоритет, большая работа

Временным апскейлерам нужны векторы движения и джиттер камеры, а это разбор каждой конкретной игры.
У нас в ядре уже есть временной апскейлер от GoW3 (`vk_temporal_upscaler.cpp`, `vk_camera_motion.cpp`),
но для inFAMOUS он выключен (`ISS_UPSCALER=off`, «изображение дрожало»). Если браться, то начинать с
`docs/upscaler.md` и `docs/motion_vectors.md` у deadinside28/bloodborne_pc.

## Чего не брать

- Установку игры из PKG (как в Dragon's Crown Pro): юридически скользко. Оставляем только свой дамп
  через GoldHEN + Itemzflow.
- Код из удалённого репозитория CTR (SacredFire) и его копий. Лаунчер UFC 3 (`sacredfire_launcher.py`,
  `README.SacredFire.md`) происходит оттуда же, поэтому из UFC берём только `runtime_fp.c` после проверки,
  что он написан для UFC.
- Патчи и настройки, привязанные к чужим играм (разрешение, FPS, эффекты): у нас другие eboot.

## Что делать дальше (предлагаемый порядок)

1. Ленивый коммит памяти (пункт 1) — маленькое изменение, которое сразу избавляет от вылетов на 16 ГБ.
2. Разобрать лог First Light и перенести нужное исправление фризов (пункт 2).
3. Лаунчер: «Добавить в Steam», ярлык, русский язык (пункт 4); затем автообновление.
4. «Горячий» прогрев (пункт 3), когда кеш First Light станет большим.
