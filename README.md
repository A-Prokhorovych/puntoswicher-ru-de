# PuntoSwitcher RU-DE

Минимальный macOS-прототип переключателя для русской ЙЦУКЕН и немецкой QWERTZ.

## Запуск

```bash
cd ~/Downloads/puntoswicher-ru-de
chmod +x build.sh
./build.sh
./.build/puntoswicher-ru-de --hotkey 'cmd+^'
```

`build.sh` также собирает menu bar приложение:

```text
dist/PuntoSwitcherRUDE.app
```

## Install On Another Mac

Copy the project folder to the Mac and run:

```bash
cd puntoswicher-ru-de
./install.sh
```

The installer:

- builds `PuntoSwitcherRUDE.app`;
- copies it to `~/Applications`;
- adds autostart via `~/Library/LaunchAgents/com.andreyprokhorovich.puntoswicher-rude.plist`;
- starts the app immediately.

If hotkeys do not work, grant Accessibility permission to `PuntoSwitcher RU-DE`:

```text
System Settings -> Privacy & Security -> Accessibility
```

## Uninstall

```bash
cd puntoswicher-ru-de
./uninstall.sh
```

The uninstaller removes the LaunchAgent and deletes the app from `~/Applications`.

## Menu Bar

The app runs as a menu bar item named `RU-DE`, without a Dock icon. Click it to see English help:

```text
Cmd+^ / Cmd+ё: convert last typed word
Cmd+Shift+^ / Cmd+Shift+ё: toggle selected text case
Quit PuntoSwitcher RU-DE
```

Можно выбрать свою комбинацию:

```bash
./.build/puntoswicher-ru-de --hotkey 'cmd+^'
./.build/puntoswicher-ru-de --hotkey 'cmd+ё'
./.build/puntoswicher-ru-de --hotkey 'ctrl+^'
./.build/puntoswicher-ru-de --hotkey 'ctrl+ё'
./.build/puntoswicher-ru-de --hotkey ctrl+space
```

При первом запуске macOS попросит Accessibility-доступ. Разреши Terminal в:

```text
System Settings -> Privacy & Security -> Accessibility
```

Потом перезапусти команду `./.build/puntoswicher-ru-de`.

## Использование

Поставь курсор сразу после слова и нажми выбранный хоткей. Рекомендуемый вариант для MacBook:

```text
Cmd+^
```

Если приложение запущено с `--hotkey ctrl+space`, нажимай `Ctrl+Space`.
Если приложение запущено с `--hotkey 'cmd+^'` или `--hotkey 'cmd+ё'`, нажимай `Cmd+ё` в русской раскладке или `Cmd+^` в немецкой.
Если приложение запущено с `--hotkey 'ctrl+^'` или `--hotkey 'ctrl+ё'`, нажимай `Ctrl+ё` в русской раскладке или `Ctrl+^` в немецкой.
Нажимай коротко и отпускай: исправление запускается после отпускания комбинации.
Приложение запоминает последнее набранное слово, поэтому лучше нажимать хоткей сразу после ввода слова, не кликая мышью в другое место.

Чтобы поменять регистр выделенного текста, выдели букву, слово или фрагмент и нажми:

```text
Cmd+Shift+^
```

В русской раскладке это та же физическая клавиша: `Cmd+Shift+ё`.

Примеры:

```text
а -> А
А -> а
Hallo -> hALLO
Привет -> пРИВЕТ
```

Если `Cmd+ё/Cmd+^` не срабатывает, проверь реальный код клавиши:

```bash
./.build/puntoswicher-ru-de --listen-keycodes
```

Нажми `ё/^` и посмотри строку `keyCode=...` в терминале.

Примеры:

```text
руддщ -> hello
ghbdtn -> привет
ахк -> für
пкгыы -> gruss
пкг- -> gruß
```

## Ограничения прототипа

- Пока нет словарной проверки, хоткей просто меняет символы по физическим клавишам.
- Основной режим лучше работает сразу после набора слова, потому что приложение хранит последнее слово во внутреннем буфере.
- Автоматического исправления при наборе пока нет.
