# shell

Установщик [fish](https://fishshell.com/) + [starship](https://starship.rs/) +
[atuin](https://atuin.sh/) + [zoxide](https://github.com/ajeetdsouza/zoxide) +
[fzf](https://github.com/junegunn/fzf) + [lsd](https://github.com/lsd-rs/lsd) +
[zellij](https://github.com/zellij-org/zellij) и шрифта JetBrainsMono Nerd Font
с темой [Arch OS](https://github.com/murkl/starship-theme-arch-os)
и готовой конфигурацией истории команд. Идемпотентно, с бэкапами существующих
конфигов.

Поддерживаются Debian 12/13, Ubuntu 22.04/24.04/26.04,
Fedora/RHEL-совместимые и Arch-совместимые дистрибутивы. Проверено на Debian 12,
Debian 13, Ubuntu 22.04, 24.04 и 26.04, Fedora и Arch.

## Быстрый старт

```bash
git clone https://github.com/bag2000/shell.git
cd shell
cp .env.example .env    # при необходимости укажите прокси
bash install.sh
```

Скрипт запускается из клонированного репозитория: конфиги берутся из каталога
`config/` рядом с `install.sh`.

Если GitHub заблокирован, клонируйте репозиторий через прокси — см. раздел
[«Прокси и блокировки»](#прокси-и-блокировки).

Запускайте **обычным пользователем**, не через `sudo`. Установщик сам вызовет `sudo`
для установки пакетов, fish в `/usr/local/bin` и смены login shell.

После установки откройте новый терминал — он запустится внутри zellij (см.
раздел [«zellij»](#zellij)) — или выполните:

```bash
exec fish
```

## Прокси и блокировки

Установщик читает настройки прокси из `.env` в текущем каталоге (или рядом с
`install.sh`) и из переменных окружения. Сам `.env` добавлен в `.gitignore`.

```bash
git clone https://github.com/bag2000/shell.git
cd shell
cp .env.example .env
$EDITOR .env
```

Минимальный `.env`:

```dotenv
HTTP_PROXY=http://proxy.example.com:8080
HTTPS_PROXY=http://proxy.example.com:8080
NO_PROXY=localhost,127.0.0.1,::1,192.168.0.0/16
```

Можно указать один адрес — `PROXY=proxy.example.com:8080`. Схема `http://` добавится
автоматически, значение применится к HTTP, HTTPS и ALL.

Прокси используется для скачивания fish, starship, atuin, zoxide, fzf, lsd и zellij, а также
передаётся пакетным менеджерам:

- `apt` — через `Acquire::http::Proxy` / `Acquire::https::Proxy`;
- `dnf` — через `--setopt=proxy=...`;
- `pacman` — через `http_proxy` / `https_proxy` / `all_proxy`.

Прокси для самого `git clone` задаётся до клонирования — `.env` появится только
после него. Используйте один из вариантов:

```bash
# HTTPS-клон через прокси
git -c http.proxy=http://proxy.example.com:8080 \
  clone https://github.com/bag2000/shell.git

# или через переменные окружения
HTTPS_PROXY=http://proxy.example.com:8080 \
  git clone https://github.com/bag2000/shell.git
```

После клонирования настройте `.env` — его уже использует `bash install.sh`.
Если прокси нужно проигнорировать: `--no-proxy`. Другой файл настроек:
`--env-file /path/to/file.env` или `ENV_FILE=/path/to/file.env`.

Из `.env` импортируются только `PROXY`, `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`,
`NO_PROXY` и их строчные варианты — остальные переменные игнорируются. Пароли в
URL прокси не попадают в лог: выводится `http://***@host:8080`.

## Что делает установщик

1. Определяет дистрибутив и пакетный менеджер (`apt`, `dnf`, `pacman`).
2. Ставит `curl`, CA-сертификаты, `tar`, `gzip` и `xz`.
3. Скачивает standalone `fish` с GitHub и ставит в `/usr/local/bin/fish`
   (если для архитектуры нет готового бинарника или GitHub недоступен —
   используется пакет дистрибутива).
4. Скачивает актуальный `starship` с GitHub и кладёт его в `~/.local/bin`.
5. Ставит тему **Arch OS** (Nord) для starship — вендорнутый `starship.toml` из
   [murkl/starship-theme-arch-os](https://github.com/murkl/starship-theme-arch-os).
6. Скачивает `atuin` в `~/.local/bin` и включает поиск по истории в fish
   (`Ctrl-R` / стрелка вверх). Для неподдерживаемых архитектур шаг пропускается.
7. Скачивает `zoxide` в `~/.local/bin` и включает `z` / `zi` для быстрого
   перехода по каталогам.
8. Скачивает `fzf` с GitHub Releases в `~/.local/bin` (только готовый бинарник,
   не из пакетного репозитория дистрибутива) — нужен для интерактивного `zi`.
9. Скачивает `lsd` с GitHub Releases в `~/.local/bin` (только готовый бинарник,
   не из пакетного репозитория дистрибутива). Для неподдерживаемых архитектур
   шаг пропускается.
10. Скачивает `zellij` с GitHub Releases в `~/.local/bin` (только готовый
    бинарник, не из пакетного репозитория дистрибутива). Для неподдерживаемых
    архитектур шаг пропускается.
11. Ставит вендорный шрифт JetBrainsMono Nerd Font Mono из `fonts/` в
    `~/.local/share/fonts/JetBrainsMonoNerdFontMono` (без сети и пакетных
    репозиториев).
12. Устанавливает конфиги:
    - `~/.config/fish/conf.d/00-shell-setup.fish` (PATH, starship, atuin, zoxide,
      lsd)
    - `~/.config/fish/conf.d/80-zellij-main.fish` (bare `zellij` → сессия `main`)
    - `~/.config/fish/conf.d/90-zellij-autostart.fish` (автозапуск zellij)
    - `~/.config/starship.toml`
    - `~/.config/atuin/config.toml`
    - `~/.config/zellij/config.kdl` и `~/.config/zellij/themes/nord-gap.kdl`
      (тема Nord с «зазорами» между панелями)
    (с учётом `XDG_CONFIG_HOME`, если он задан).
13. Регистрирует fish в `/etc/shells` и меняет login shell через `chsh`.

При повторном запуске fish, starship, atuin, zoxide, fzf, lsd и zellij
проверяются на GitHub: если установлена не последняя версия, она обновляется.
Если GitHub временно недоступен, уже установленные бинарники остаются нетронутыми.

По умолчанию Atuin хранит историю только локально: `auto_sync = false`,
`update_check = false`. Синхронизация настраивается вручную (`atuin register`
или `atuin login`).

Существующие файлы не теряются: перед перезаписью создаётся копия
`<файл>.bak.YYYYMMDD-HHMMSS`.

Ваш собственный `~/.config/fish/config.fish` не изменяется — установщик использует
отдельный файл в `conf.d/`, который fish подхватывает автоматически.

## Параметры

Все примеры выполняются из клонированного каталога `shell`:

```bash
# Посмотреть план без изменений в системе
bash install.sh --dry-run

# Поставить только fish, без starship, atuin, zoxide, fzf, lsd, zellij, шрифта и конфигов
bash install.sh --no-starship --no-atuin --no-zoxide --no-fzf --no-lsd --no-zellij --no-font --no-config

# Не менять login shell (например, на сервере)
bash install.sh --no-chsh

# Конкретная версия starship
STARSHIP_VERSION=1.26.0 bash install.sh

# Без atuin, zoxide, fzf, lsd и zellij
bash install.sh --no-atuin --no-zoxide --no-fzf --no-lsd --no-zellij

# Прокси можно передать флагом вместо .env
bash install.sh --proxy http://proxy.example.com:8080

# Проверить версии (0 — всё актуально, 1 — есть обновления)
bash install.sh --check

# Обновить только уже установленные утилиты
bash install.sh --update
```

| Флаг | Описание |
| --- | --- |
| `--no-chsh` | Не менять login shell на fish |
| `--no-config` | Не устанавливать конфиги fish/starship/atuin |
| `--no-starship` | Не устанавливать starship |
| `--no-atuin` | Не устанавливать atuin |
| `--no-zoxide` | Не устанавливать zoxide |
| `--no-fzf` | Не устанавливать fzf |
| `--no-lsd` | Не устанавливать lsd |
| `--no-zellij` | Не устанавливать zellij |
| `--no-zellij-autostart` | Не включать автозапуск zellij в новых терминалах |
| `--no-zellij-mouse` | Не перехватывать мышь в zellij (выделение делает терминал) |
| `--no-font` | Не устанавливать шрифт JetBrainsMono Nerd Font |
| `--force` | Переустановить starship, atuin, zoxide, fzf, lsd, zellij и шрифт, даже если они уже есть |
| `--dry-run` | Показать план и выйти, ничего не меняя |
| `--check` | Показать установленные и последние версии, ничего не меняя |
| `--update` | Обновить только уже установленные утилиты |
| `--config-dir DIR` | Взять конфиги из локального каталога `DIR` (fish/, starship.toml, atuin.toml, zellij/) |
| `--font-dir DIR` | Установить шрифт в каталог `DIR` |
| `--starship-version V` | Установить указанную версию starship |
| `--atuin-version V` | Установить указанную версию atuin |
| `--zoxide-version V` | Установить указанную версию zoxide |
| `--fzf-version V` | Установить указанную версию fzf |
| `--lsd-version V` | Установить указанную версию lsd |
| `--zellij-version V` | Установить указанную версию zellij |
| `--fish-version V` | Установить указанную версию fish |
| `--proxy URL` | Использовать указанный HTTP(S)/SOCKS-прокси |
| `--no-proxy` | Игнорировать прокси из окружения и `.env` |
| `--env-file FILE` | Загрузить настройки прокси из файла `FILE` |
| `-h`, `--help` | Справка |
| `--version` | Версия установщика |

Переменные окружения: `STARSHIP_VERSION`, `ATUIN_VERSION`, `ZOXIDE_VERSION`,
`FZF_VERSION`, `LSD_VERSION`, `ZELLIJ_VERSION`, `FISH_VERSION`, `ENV_FILE`.

## Шрифт и иконки в промпте

Промпт использует тему **Arch OS** (Nord)
([murkl/starship-theme-arch-os](https://github.com/murkl/starship-theme-arch-os)).
В ней есть символы Nerd Font.

Установщик берёт вендорное семейство **JetBrainsMono Nerd Font Mono** из
`fonts/JetBrainsMonoNerdFontMono`: 16 начертаний (все веса и курсивы) ставятся в
`~/.local/share/fonts/JetBrainsMonoNerdFontMono`. Сеть и пакетные репозитории не
используются. После установки выберите **JetBrainsMono Nerd Font Mono** в
настройках терминала.

Если `fc-cache` недоступен, установите `fontconfig` и обновите кэш:

```bash
fc-cache -f
```

Пропустить установку шрифта: `--no-font`. Свой каталог: `--font-dir DIR`.

Если шрифт ставить не хочется, замените символы в `~/.config/starship.toml`
(например, `symbol = " "` у `git_branch`) на обычный текст. Тема распространяется
по лицензии MIT — текст в `THIRD_PARTY_NOTICES.md`.

## Atuin

Atuin заменяет стандартную историю fish на локальную SQLite-базу с быстрым
поиском: `Ctrl-R` или стрелка вверх. Бинарник ставится в `~/.local/bin/atuin`,
интеграция — в `conf.d/00-shell-setup.fish`.

Синхронизация по умолчанию выключена (`auto_sync = false`), проверка обновлений
тоже. Включить синхронизацию можно вручную:

```bash
atuin register   # новый аккаунт на api.atuin.sh
# или
atuin login
```

После этого установите `auto_sync = true` в `~/.config/atuin/config.toml`.
История хранится в `~/.local/share/atuin`.

## zoxide

zoxide — умная замена `cd`. Бинарник ставится в `~/.local/bin/zoxide`,
интеграция (`z`, `zi`) — в `conf.d/00-shell-setup.fish`.

```bash
z projects     # перейти в часто используемый каталог
zi             # интерактивный выбор через fzf
```

Данные хранятся в `~/.local/share/zoxide`. Отдельного конфига у zoxide нет.
Установщик ставит `fzf` в `~/.local/bin`, так что `zi` работает сразу. Пропустить
установку fzf: `--no-fzf`. При установленном zoxide команда `cd` заменяется
аббревиатурой на `z` (см. `conf.d/00-shell-setup.fish`).

## fzf

fzf — нечёткий поиск в терминале. Бинарник ставится в `~/.local/bin/fzf`
**только с GitHub Releases** ([junegunn/fzf](https://github.com/junegunn/fzf)),
пакетный репозиторий дистрибутива не используется. Он нужен для `zi` (zoxide);
отдельной интеграции в fish установщик не включает, чтобы не конфликтовать с
поиском истории Atuin (`Ctrl-R`).

```bash
fzf --version
```

Пропустить установку: `--no-fzf`. Конкретная версия: `--fzf-version V` или
`FZF_VERSION=V bash install.sh`.

## lsd

lsd — современная замена `ls` с цветами и иконками. Бинарник ставится в
`~/.local/bin/lsd` **только с GitHub Releases** ([lsd-rs/lsd](https://github.com/lsd-rs/lsd)),
пакетный репозиторий дистрибутива не используется.

```bash
lsd            # список файлов
lsd -lah       # подробно, включая скрытые
lsd --tree     # дерево каталогов
```

Отдельного конфига у lsd нет. При установленном lsd установщик добавляет
аббревиатуру `ls` → `lsd`, так что привычный `ls` сразу использует lsd.
Аббревиатуры `ll` и `la` тоже переключаются на lsd (`lsd -lah`, `lsd -A`);
если lsd не установлен, они остаются на обычном `ls`.
Отключить можно, удалив строку из `~/.config/fish/conf.d/00-shell-setup.fish`
или добавив в `~/.config/fish/config.fish`:

```fish
abbr --erase ls
```

## zellij

zellij — терминальный мультиплексор и рабочие пространства (сессии, панели,
вкладки). Бинарник ставится в `~/.local/bin/zellij` **только с GitHub Releases**
([zellij-org/zellij](https://github.com/zellij-org/zellij)), пакетный репозиторий
дистрибутива не используется.

Установщик также включает автозапуск: при открытии нового терминала fish
запускает zellij вместо обычной оболочки. Вложенные сессии (когда `ZELLIJ` уже
задан) и нетерминальные запуски fish пропускаются, поэтому `fish -c ...` и
скрипты работают как раньше.

Zellij всегда использует сессию **main**: если она уже существует — происходит
attach, если нет — она создаётся и сразу открывается. Так же работает и ручной
запуск: команда `zellij` без аргументов в fish прикрепляется к `main` (функция-
обёртка в `80-zellij-main.fish`). Остальные вызовы передаются как есть:
`zellij list-sessions`, `zellij attach other`, `zellij --version` и т.д.

```bash
zellij              # сессия main: attach или создание
zellij attach       # подключиться к существующей сессии (выбор из списка)
zellij --version
```

Отключить автозапуск при установке: `--no-zellij-autostart` — файл
`~/.config/fish/conf.d/90-zellij-autostart.fish` не устанавливается, а если он
уже был, при повторном запуске удаляется с бэкапом `.bak.*`.

Отключить автозапуск для уже установленной системы:

```fish
# в ~/.config/fish/config.fish
set -gx ZELLIJ_AUTO_START 0
```

или разово для одного терминала:

```bash
ZELLIJ_AUTO_START=0 fish
```

Установщик ставит готовый конфиг `~/.config/zellij/config.kdl` и тему
`~/.config/zellij/themes/nord-gap.kdl`. В теме неактивные рамки панелей окрашены
в цвет фона, поэтому между панелями остаются пустые поля — «зазоры» как в i3wm;
активная панель обведена синим (`#81A1C1`, как `border_active` в i3).
Для этого используется `pane_frame_style "full"` (Zellij 0.46+). Существующий
конфиг при установке сохраняется в `config.kdl.bak.YYYYMMDD-HHMMSS`.
В конфиге `mouse_mode true`: клик фокусирует панель, колесо прокручивает
панель (`Ctrl+s` — режим скролла и поиска), рамки тянутся мышью, протяжка
мышью сразу копирует (`copy_on_select true`). Нативное выделение терминала —
`Shift`+протяжка.

Копирование идёт встроенным путём zellij через OSC 52: на headless-хосте нет
ни X11/Wayland, ни `xclip`/`wl-copy`, поэтому `copy_command` в конфиге нет.
Вставка — `Ctrl+Shift+V` в Ghostty/kitty, `Cmd+V` в iTerm; клиентский терминал
должен разрешать OSC 52. Если появится помощник `clip-both`, `copy_command`
можно вернуть — строка есть в комментарии.

Если мышь должна обрабатывать терминал (старое поведение), установите с
`--no-zellij-mouse` — в конфиг записывается `mouse_mode false`.

Пропустить установку zellij вместе с его конфигом: `--no-zellij`.
Не трогать конфиги (все): `--no-config`. Конкретная версия:
`--zellij-version V` или `ZELLIJ_VERSION=V bash install.sh`.

Свой конфиг можно положить в `~/.config/zellij/config.kdl` после установки —
при следующем запуске `install.sh` он будет заменён вендорным (с бэкапом).

## Проверка версий и обновление

```bash
bash install.sh --check    # только сравнить версии, ничего не менять
bash install.sh --update   # обновить уже установленные утилиты
```

`--check` сравнивает установленные версии fish, starship, atuin, zoxide, fzf,
lsd и zellij с последними на GitHub и печатает таблицу. Коды возврата:

- `0` — всё актуально;
- `1` — есть обновления или какая-то утилита не установлена;
- `2` — не удалось проверить версии (например, GitHub недоступен).

`--update` обновляет только уже установленные компоненты. Отсутствующие утилиты
он не ставит, конфиги и шрифт не трогает, login shell не меняет — для полной
установки запустите `bash install.sh`. Флаги `--no-*`, `--force` и `--*-version`
работают и в этом режиме.

## Обновление

```bash
cd shell
git pull
bash install.sh
```

Установщик сверит версии fish, starship, atuin, zoxide, fzf, lsd и zellij с GitHub
и обновит их при необходимости. Конфиги будут обновлены с бэкапами, если они изменились.
Локальный `.env` при `git pull` не затрагивается.

## Проверка

Тест поднимает чистый контейнер, создаёт пользователя с passwordless sudo,
выполняет установку, проверяет fish/starship/atuin/zoxide/fzf/lsd/zellij, шрифт и конфиги,
идемпотентный повторный запуск, загрузку прокси из `.env`/`--env-file`,
маскирование пароля, `--dry-run`, `--check` и `--update`.

```bash
./tests/ubuntu.sh
IMAGE=ubuntu:22.04 ./tests/ubuntu.sh
IMAGE=debian:12 ./tests/ubuntu.sh
IMAGE=debian:13 ./tests/ubuntu.sh
IMAGE=ubuntu:26.04 ./tests/ubuntu.sh
```

Требуется Docker. Скрипт проверен на Debian 12, Debian 13, Ubuntu 22.04,
Ubuntu 24.04, Ubuntu 26.04, Fedora и Arch.

Линтер:

```bash
docker run --rm -v "$PWD:/mnt:ro" koalaman/shellcheck:stable /mnt/install.sh
```

## Удаление

```bash
chsh -s /bin/bash
rm -f ~/.config/fish/conf.d/00-shell-setup.fish
rm -f ~/.config/fish/conf.d/80-zellij-main.fish
rm -f ~/.config/fish/conf.d/90-zellij-autostart.fish
rm -f ~/.local/bin/starship
rm -f ~/.local/bin/atuin
rm -f ~/.local/bin/zoxide
rm -f ~/.local/bin/fzf
rm -f ~/.local/bin/lsd
rm -f ~/.local/bin/zellij
rm -rf ~/.local/share/fonts/JetBrainsMonoNerdFontMono
fc-cache -f
sudo rm -f /usr/local/bin/fish
rm -f ~/.local/bin/fish
# при желании:
rm -f ~/.config/starship.toml
rm -f ~/.config/atuin/config.toml
rm -f ~/.config/zellij/config.kdl
rm -f ~/.config/zellij/themes/nord-gap.kdl
sudo apt remove fish        # Debian/Ubuntu
# sudo dnf remove fish      # Fedora
# sudo pacman -Rns fish     # Arch
```

История Atuin остаётся в `~/.local/share/atuin`, данные zoxide — в
`~/.local/share/zoxide`; удалите эти каталоги вручную, если они больше не нужны.

Если fish ставился в `/usr/local/bin`, при необходимости удалите
`/usr/local/bin/fish` из `/etc/shells`.

Бэкапы `*.bak.*` остаются рядом с конфигами — их можно удалить вручную.

## Структура

```
install.sh                                  # установщик (запуск из репозитория)
.env.example                                # шаблон настроек прокси
.gitignore                                  # .env и бэкапы не попадают в git
config/fish/conf.d/00-shell-setup.fish      # PATH, starship, atuin, zoxide, lsd (cd→z, ls→lsd)
config/fish/conf.d/80-zellij-main.fish      # bare zellij → attach --create main
config/fish/conf.d/90-zellij-autostart.fish # автозапуск zellij в новых терминалах
config/starship.toml                        # тема Arch OS (Nord)
config/atuin.toml                           # локальная история, настройки поиска
config/zellij/config.kdl                    # Zellij: полные рамки, зазоры, мышь, автозапуск
config/zellij/themes/nord-gap.kdl          # Nord-тема с невидимыми неактивными рамками
fonts/JetBrainsMonoNerdFontMono/            # вендорный Nerd Font (16 .ttf + OFL.txt)
THIRD_PARTY_NOTICES.md                      # лицензии тем (MIT) и шрифта (OFL)
tests/ubuntu.sh                             # smoke-тест в Docker
```

Локальный `.env` с рабочим прокси уже создан и в git не попадёт. При клонировании
на другой машине скопируйте `.env.example` в `.env` и укажите свой прокси.
