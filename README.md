# PuntoSwitcher RU-DE

Минимальный macOS-прототип переключателя для русской ЙЦУКЕН и немецкой QWERTZ.

## Запуск

```bash
cd ~/Downloads/puntoswicher-ru-de
chmod +x build.sh
./build.sh
./.build/puntoswicher-ru-de --hotkey 'cmd+^'
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
Cmd+Shift+Y
```

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
