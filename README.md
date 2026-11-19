# NixOS 26.05 reference config

Flake для **NixOS 26.05**: **niri** (Wayland) + **noctalia**, home-manager, Zen Browser, Zed,
Catppuccin/starship, yazi/Thunar, udiskie. Десктопных окружений (KDE/GNOME) нет —
сессия одна, niri.

## Что внутри

| Файл | Назначение |
|---|---|
| `flake.nix` | inputs: nixpkgs 26.05, home-manager, niri-flake, noctalia (cachix), zen-browser; установщики `install` / `install-iso` |
| `user.nix` | имя пользователя по умолчанию (установщик пишет `user-local.nix`, который этот файл перекрывает) |
| `configuration.nix` | система: boot, сеть, niri, pipewire, кеши, GC (SSH выключен) |
| `home.nix` | пользователь: zsh/starship/zoxide, niri, noctalia (бар, лаунчер, обои), терминалы, Zen, Zed, yazi/Thunar, udiskie, `nh` |
| обои | не хранятся в репозитории: их показывает noctalia, папка по умолчанию `~/Pictures` |
| `hardware-configuration.nix` | **не хранится в репозитории** — генерируется на каждой машине (`nixos-generate-config`) |
| `user-local.nix` | **не хранится в репозитории** — машино-специфичное имя пользователя |
| `themes.nix` | палитры тем (catppuccin mocha/latte, everforest, gruvbox, ascii) |
| `theme-local.nix` | **не хранится в репозитории** — выбранная тема (пишется `theme <name>`) |
| `starship-catppuccin-powerline.toml` | пресет Starship |
| `scripts/install`-скрипты | `rebuild.sh` (пересборка), `nix-caches.sh` (выбор живого кеша), `adopt-git.sh` (перевести уже установленную систему на git), `cached-build.sh` |

Пользователь создаётся при установке: имя вводится в установщике и пишется в `user-local.nix`
(по умолчанию `nixos`), группы `wheel`/`networkmanager`, шелл zsh, пароль задаётся там же.
SSH по умолчанию **выключен**.

## Установка одной командой (NixOS уже установлена)

Если NixOS (в том числе minimal) уже стоит и есть сеть:

```bash
sudo nix --extra-experimental-features 'nix-command flakes' \
  run github:SPdrErgo/nixos-config#install
```

Установщик:

- требует, чтобы на машине уже был `/etc/nixos/hardware-configuration.nix`, и **сохраняет его**;
- бэкапит текущий `/etc/nixos` в `/etc/nixos.bak-<дата>`;
- **клонирует** репозиторий в `/etc/nixos` (это git-репозиторий, а не просто копия файлов);
- пишет `user-local.nix` с выбранным именем и отдаёт `/etc/nixos` пользователю, чтобы `git pull`
  работал без sudo;
- делает `nixos-rebuild switch` с уже проверенными бинарными кешами;
- создаёт `~/nixos-config` → `/etc/nixos`, чтобы работали алиасы `rebuild` / `update` / `upgrade`.

## Minimal ISO: установка одной командой

С флешки **NixOS minimal ISO 26.05**, загруженной **в UEFI** (конфиг использует `systemd-boot`);
поднимите сеть (обычно DHCP сам; иначе `nmtui`).

```bash
sudo nix --extra-experimental-features 'nix-command flakes' \
  run github:SPdrErgo/nixos-config#install-iso -- /dev/vda
```

Скрипт спрашивает:

1. `Type YES to continue` — подтверждение, что диск будет стёрт;
2. `Encrypt the root partition with LUKS? [y/N]` — шифрование корня (btrfs лежит внутри LUKS2,
   пароль спрашивается дважды);
3. `Username` — имя пользователя;
4. `Root password` — пароль root (дважды);
5. `Password for <user>` — пароль пользователя (дважды).

Оба пароля применяются в конце установки через `chpasswd` (а не через интерактивный `passwd`
в chroot), поэтому они гарантированно попадают в `/etc/shadow` целевой системы.

Что делает:

- проверяет, что ISO загружен в UEFI, и что с диска ничего не смонтировано (защита от затирания
  live-флешки);
- GPT: ESP 512 MiB + btrfs с subvolumes `@`, `@home`, `@nix` (опционально — внутри LUKS2);
- `nixos-generate-config` + `nixos-install` с вашим flake;
- перед сборкой проверяет, какие бинарные кеши реально отвечают, и передаёт только их;
- после установки задаёт пароли root и пользователя и делает `/etc/nixos` git-чекаутом.

После установки: `reboot`, вынуть флешку. Требуется публичный репозиторий.

> Диск будет полностью стёрт. При LUKS пароль спрашивается при каждой загрузке (initrd).

## Установка с нуля (вручную, с ISO)

1. Загрузиться с NixOS ISO **26.05** в UEFI, подключить сеть.
2. Разметить диск и смонтировать в `/mnt` (например btrfs subvolumes `@`, `home`, `nix` + EFI в `/boot`).
   Если нужен LUKS: `cryptsetup luksFormat /dev/...`, `cryptsetup open ... cryptroot`, дальше
   работать с `/dev/mapper/cryptroot`.
3. Сгенерировать hardware-конфиг:

   ```bash
   nixos-generate-config --root /mnt
   ```

   LUKS-устройство `nixos-generate-config` определит сам и добавит
   `boot.initrd.luks.devices` в `hardware-configuration.nix`.

4. Наложить репозиторий **поверх** `/mnt/etc/nixos`, не затирая сгенерированный hardware-конфиг:

   ```bash
   git clone https://github.com/SPdrErgo/nixos-config /tmp/nixos-config
   cp -a /tmp/nixos-config/. /mnt/etc/nixos/
   ```

   В репозитории нет `hardware-configuration.nix`, поэтому сгенерированный файл останется на месте.

5. Установить:

   ```bash
   nixos-install --flake /mnt/etc/nixos#nixos
   ```

6. Задать пароль пользователю (имя — из `/mnt/etc/nixos/user-local.nix`, по умолчанию `nixos`):

   ```bash
   nixos-enter --root /mnt -c 'passwd nixos'
   ```

7. Перезагрузка. Логин-менеджер `ly` запускает сессию **niri**.

## SSH

В этом снимке SSH **выключен**. Чтобы включить, сначала добавьте свой ключ и только потом включайте
сервис (одним rebuild, иначе потеряете доступ):

```nix
users.users.<username>.openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA...ваш ключ..."
];
services.openssh = {
  enable = true;
  settings.PasswordAuthentication = false;
  settings.KbdInteractiveAuthentication = false;
  settings.PermitRootLogin = "no";
};
```

## Горячие клавиши (niri)

| Клавиши | Действие |
|---|---|
| `Super+Return` | терминал (`alacritty`) |
| `Super+D` | поиск/меню приложений от noctalia |
| `Super+E` | файловый менеджер (`yazi`) |
| `Super+Shift+B` | панель выбора обоев noctalia |
| `Super+Shift+W` | случайные обои (`noctalia msg wallpaper-random`) |
| `Super+X` | панель noctalia |
| `Ctrl+Alt+L` | заблокировать (`swaylock`) |

## Обои (noctalia)

Обоями полностью управляет noctalia: свой рендерер, переходы (fade/wipe/pixel/crt…),
панель выбора и IPC. `swaybg` больше не используется.

- папка по умолчанию — `~/Pictures` (в конфиге `wallpaper.directory = ""` = XDG Pictures);
- выбор обоев: `Super+Shift+B` (панель) или `noctalia msg panel-toggle wallpaper`;
- случайные: `Super+Shift+W` (`noctalia msg wallpaper-random`);
- вперёд/назад: `noctalia msg wallpaper-next`, `noctalia msg wallpaper-previous`;
- поставить конкретный файл: `noctalia msg wallpaper-set ~/Pictures/foo.png`.

Свою папку можно указать явно:

```nix
programs.noctalia.settings.wallpaper.directory = "/home/<user>/Wallpapers";
```

## Экран входа (ly)

`services.displayManager.ly.settings` включает анимацию **Game of Life** на тёмно-зелёном фоне
(`bg`, `gameoflife_fg`, `border_fg`). Цвета задаются как `0xSSRRGGBB`, как в `res/config.ini` ly.
Если анимация не нужна — уберите блок `settings` из `configuration.nix`.

## Обновление системы через git

После установки `/etc/nixos` — это git-чекаут репозитория (симлинк `~/nixos-config` ведёт на него).
Машино-специфичные `hardware-configuration.nix` и `user-local.nix` добавлены в `.gitignore`,
поэтому `git pull` их не трогает, а пересборка идёт через `path:` (иначе flake не увидел бы
неотслеживаемые файлы).

```bash
cd ~/nixos-config
git pull --ff-only
sudo /etc/nixos/scripts/rebuild.sh
```

Алиасы (zsh):

```bash
rebuild   # sudo /etc/nixos/scripts/rebuild.sh
update    # git pull --ff-only && rebuild
upgrade   # nix flake update --flake /etc/nixos && rebuild
theme     # sudo /etc/nixos/scripts/theme.sh
clean     # sudo nh clean all
```

Свои правки:

```bash
cd ~/nixos-config
$EDITOR configuration.nix
rebuild
git add -A && git commit -m "..." && git push
```

### Перевести уже установленную систему на git

Если NixOS ставилась по старой инструкции (в `/etc/nixos` просто копия файлов, без `.git`), проще
всего просто запустить установщик — он сохранит `hardware-configuration.nix` и имя пользователя:

```bash
sudo nix --extra-experimental-features 'nix-command flakes' \
  run github:SPdrErgo/nixos-config#install
```

Либо сделать только git-миграцию, без полного переустановщика (скрипт сначала нужно получить,
в старой копии его ещё нет):

```bash
git clone https://github.com/SPdrErgo/nixos-config /tmp/nixos-config
sudo bash /tmp/nixos-config/scripts/adopt-git.sh
sudo nixos-rebuild switch --flake 'path:/etc/nixos#nixos'
```

Скрипт делает бэкап `/etc/nixos.bak-<дата>`, инициализирует git, забирает `main` с GitHub,
сохраняет `hardware-configuration.nix` и имя пользователя (в `user-local.nix`), выставляет владельца.

## Бинарные кеши

В `configuration.nix` прописаны (по приоритету):

- `https://mirror.yandex.ru/nixos` (основной в РФ)
- `https://cache.nixos.org`
- `https://niri.cachix.org`
- `https://noctalia.cachix.org`
- `https://mirror.sjtu.edu.cn/nix-channels/store` (запасной)

Nix сам переходит к следующему кешу, если предыдущий недоступен. Установщики дополнительно
**проверяют доступность** и передают только живые кеши:

```bash
./scripts/nix-caches.sh          # список доступных сейчас
./scripts/nix-caches.sh --all    # полный список
```

До первого `nixos-rebuild switch` (когда `/etc/nix/nix.conf` ещё не обновлён) можно собрать систему
заранее:

```bash
bash scripts/cached-build.sh
```

Если GitHub недоступен, установщик всё равно поставит систему из локального flake-снапшота и
предупредит; позже достаточно выполнить `git -C /etc/nixos fetch origin && git -C /etc/nixos reset --hard origin/main`.

## Темы

Все цвета лежат в `themes.nix`. Из них собираются:

- alacritty (фон/ANSI/курсор/выделение);
- рамки niri;
- палитра **noctalia** (бар, панели, лаунчер) — генерируется JSON
  `~/.config/noctalia/palettes/Config.json` через `customPalettes.Config`;
- экран входа `ly` (цвета + анимация).

Выбранная тема хранится в `theme-local.nix` (gitignore), по умолчанию — `catppuccin-mocha`.

```bash
theme                  # текущая тема + список доступных
theme everforest       # переключить и пересобрать
theme ascii            # чёрно-зелёный «фосфор» во всей системе
```

Доступно: `catppuccin-mocha`, `catppuccin-latte`, `everforest`, `gruvbox`, `ascii`.

Тема `ascii` — это чёрный фон и зелёный текст в духе старого терминала: в `ly` вместо
Game of Life включается ASCII-дождь (`animation = "matrix"`), `noctalia` перекрашивается в
чёрно-зелёную палитру, а `cmatrix` есть в системе (алиас `matrix`). Свою тему можно добавить,
скопировав блок в `themes.nix` — главное сохранить все ключи
(bg/fg/selection/…/accent/cursor/lyAnimation).

> `noctalia` при изменениях через GUI пишет их в `~/.config/noctalia/settings.toml`, а он
> загружается последним и перекрывает наш `config.toml`. Если после `theme <name>` цвета не
> поменялись — убери `theme`/`custom_palette` из `settings.toml` (или выбери палитру `Config`
> в настройках noctalia).

> Starship использует фиксированный пресет Catppuccin Powerline, он от темы не зависит.

## Если при входе в niri просит пароль

Это polkit. Самый частый виновник — `udiskie`: он пытается примонтировать внутренний или
зашифрованный раздел, а udisks2 на это требует аутентификацию. В конфиге теперь:

- `services.udiskie.automount = false` — при входе ничего не монтируется само;
- правило polkit для группы `wheel` — ручное монтирование через udisks2/Thunar и разблокировка
  LUKS-разделов идут без пароля.

Посмотреть, кто именно просил пароль:

```bash
journalctl -b --no-pager -g 'polkit|Authentication' | tail -40
```

## niri в виртуальной машине

niri требует GPU с EGL/GBM и **не умеет software-рендеринг**. В QEMU нужен virtio-gpu с 3D:

- видео: `<model type='virtio' heads='1' primary='yes'><acceleration accel3d='yes'/></model>`
- SPICE: только через **unix socket** с `<gl enable='yes'/>`. QEMU 11 + spice 0.16 падает при
  `gl=on` через TCP (`invalid video codec` — отсутствует gstreamer-энкодер).
- virt-manager 5.1 не умеет SPICE over unix socket; консоль открывается через
  `spicy --uri spice+unix:///var/lib/libvirt/qemu/spice-nixos.sock` (нужен доступ к сокету,
  например группа `libvirt-qemu`).

Проверка в госте: должен существовать `/dev/dri/renderD128`.
