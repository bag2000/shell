# shell

Установщик [fish](https://fishshell.com/) + [starship](https://starship.rs/) +
[atuin](https://atuin.sh/) + [zoxide](https://github.com/ajeetdsouza/zoxide) +
[lsd](https://github.com/lsd-rs/lsd) и шрифта
[JetBrainsMono Nerd Font](https://github.com/NikSneMC/JetBrainsMono-Nerd-Font)
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

После установки откройте новый терминал или выполните:

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

Прокси используется для скачивания fish, starship, atuin, zoxide и lsd, а также
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
8. Скачивает `lsd` с GitHub Releases в `~/.local/bin` (только готовый бинарник,
   не из пакетного репозитория дистрибутива). Для неподдерживаемых архитектур
   шаг пропускается.
9. Скачивает шрифт JetBrainsMono Nerd Font Mono с GitHub и ставит его в
   `~/.local/share/fonts/JetBrainsMonoNerdFontMono` (без пакетных репозиториев).
10. Устанавливает конфиги:
   - `~/.config/fish/conf.d/00-shell-setup.fish`
   - `~/.config/starship.toml`
   - `~/.config/atuin/config.toml`
   (с учётом `XDG_CONFIG_HOME`, если он задан).
11. Регистрирует fish в `/etc/shells` и меняет login shell через `chsh`.

При повторном запуске fish, starship, atuin, zoxide и lsd проверяются на GitHub:
если установлена не последняя версия, она обновляется. Если GitHub временно
недоступен, уже установленные бинарники остаются нетронутыми.

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

# Поставить только fish, без starship, atuin, zoxide, lsd, шрифта и конфигов
bash install.sh --no-starship --no-atuin --no-zoxide --no-lsd --no-font --no-config

# Не менять login shell (например, на сервере)
bash install.sh --no-chsh

# Конкретная версия starship
STARSHIP_VERSION=1.26.0 bash install.sh

# Без atuin, zoxide и lsd
bash install.sh --no-atuin --no-zoxide --no-lsd

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
| `--no-lsd` | Не устанавливать lsd |
| `--no-font` | Не устанавливать шрифт JetBrainsMono Nerd Font |
| `--force` | Переустановить starship, atuin, zoxide, lsd и шрифт, даже если они уже есть |
| `--dry-run` | Показать план и выйти, ничего не меняя |
| `--check` | Показать установленные и последние версии, ничего не меняя |
| `--update` | Обновить только уже установленные утилиты |
| `--config-dir DIR` | Взять конфиги из локального каталога `DIR` |
| `--font-dir DIR` | Установить шрифт в каталог `DIR` |
| `--starship-version V` | Установить указанную версию starship |
| `--atuin-version V` | Установить указанную версию atuin |
| `--zoxide-version V` | Установить указанную версию zoxide |
| `--lsd-version V` | Установить указанную версию lsd |
| `--fish-version V` | Установить указанную версию fish |
| `--proxy URL` | Использовать указанный HTTP(S)/SOCKS-прокси |
| `--no-proxy` | Игнорировать прокси из окружения и `.env` |
| `--env-file FILE` | Загрузить настройки прокси из файла `FILE` |
| `-h`, `--help` | Справка |
| `--version` | Версия установщика |

Переменные окружения: `STARSHIP_VERSION`, `ATUIN_VERSION`, `ZOXIDE_VERSION`,
`LSD_VERSION`, `FISH_VERSION`, `ENV_FILE`.

## Шрифт и иконки в промпте

Промпт использует тему **Arch OS** (Nord)
([murkl/starship-theme-arch-os](https://github.com/murkl/starship-theme-arch-os)).
В ней есть символы Nerd Font.

Установщик скачивает семейство **JetBrainsMono Nerd Font Mono** с GitHub
([NikSneMC/JetBrainsMono-Nerd-Font](https://github.com/NikSneMC/JetBrainsMono-Nerd-Font)):
16 начертаний (все веса и курсивы) в
`~/.local/share/fonts/JetBrainsMonoNerdFontMono`. Пакетные репозитории не
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
zi             # интерактивный выбор (требуется fzf)
```

Данные хранятся в `~/.local/share/zoxide`. Отдельного конфига у zoxide нет.
Для `zi` установите `fzf` (`sudo apt install fzf`, `sudo dnf install fzf`,
`sudo pacman -S fzf`).

## lsd

lsd — современная замена `ls` с цветами и иконками. Бинарник ставится в
`~/.local/bin/lsd` **только с GitHub Releases** ([lsd-rs/lsd](https://github.com/lsd-rs/lsd)),
пакетный репозиторий дистрибутива не используется.

```bash
lsd            # список файлов
lsd -lah       # подробно, включая скрытые
lsd --tree     # дерево каталогов
```

Отдельного конфига у lsd нет. При желании замените `ls` на lsd, добавив в
`~/.config/fish/config.fish`:

```fish
abbr --add --global ls 'lsd'
```

## Проверка версий и обновление

```bash
bash install.sh --check    # только сравнить версии, ничего не менять
bash install.sh --update   # обновить уже установленные утилиты
```

`--check` сравнивает установленные версии fish, starship, atuin, zoxide и lsd
с последними на GitHub и печатает таблицу. Коды возврата:

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

Установщик сверит версии fish, starship, atuin, zoxide и lsd с GitHub и обновит
их при необходимости. Конфиги будут обновлены с бэкапами, если они изменились.
Локальный `.env` при `git pull` не затрагивается.

## Проверка

Тест поднимает чистый контейнер, создаёт пользователя с passwordless sudo,
выполняет установку, проверяет fish/starship/atuin/zoxide/lsd, шрифт и конфиги,
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
rm -f ~/.local/bin/starship
rm -f ~/.local/bin/atuin
rm -f ~/.local/bin/zoxide
rm -f ~/.local/bin/lsd
rm -rf ~/.local/share/fonts/JetBrainsMonoNerdFontMono
fc-cache -f
sudo rm -f /usr/local/bin/fish
rm -f ~/.local/bin/fish
# при желании:
rm -f ~/.config/starship.toml
rm -f ~/.config/atuin/config.toml
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
config/fish/conf.d/00-shell-setup.fish      # PATH, starship, atuin, zoxide, аббревиатуры
config/starship.toml                        # тема Arch OS (Nord)
config/atuin.toml                           # локальная история, настройки поиска
THIRD_PARTY_NOTICES.md                      # лицензия темы Arch OS (MIT)
tests/ubuntu.sh                             # smoke-тест в Docker
```

Локальный `.env` с рабочим прокси уже создан и в git не попадёт. При клонировании
на другой машине скопируйте `.env.example` в `.env` и укажите свой прокси.
