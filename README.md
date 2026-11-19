# NixOS 26.05 reference config

Flake для **NixOS 26.05**: KDE Plasma 6 + **niri** (Wayland) + **noctalia**, home-manager, Zen Browser, Zed, Catppuccin/starship, yazi/Thunar, udiskie.

## Что внутри

| Файл | Назначение |
|---|---|
| `flake.nix` | inputs: nixpkgs 26.05, home-manager, niri-flake, noctalia (cachix), zen-browser |
| `user.nix` | имя пользователя; установщик перезаписывает его выбранным значением |
| `configuration.nix` | система: boot, сеть, KDE + niri, pipewire, кеши, GC (SSH выключен) |
| `home.nix` | пользователь: zsh/starship/zoxide, niri, noctalia, терминалы, Zen, Zed, yazi/Thunar, udiskie, `nh` |
| `hardware-configuration.nix` | **не хранится в репозитории** — генерируется на каждой машине (`nixos-generate-config`) |
| `starship-catppuccin-powerline.toml` | пресет Starship |
| `scripts/cached-build.sh` | сборка до активации с включёнными кешами |

Пользователь создаётся при установке: имя вводится в установщике и пишется в `user.nix` (по умолчанию `nixos`), группы `wheel`/`networkmanager`, шелл zsh, пароль задаётся там же. SSH по умолчанию **выключен**.

## Установка одной командой (NixOS уже установлена)

Если NixOS (в том числе minimal) уже стоит и есть сеть:

```bash
sudo nix --extra-experimental-features 'nix-command flakes' \
  run github:SPdrErgo/nixos-config#install
```

Установщик:

- требует, чтобы на машине уже был `/etc/nixos/hardware-configuration.nix`, и **сохраняет его** (в репозитории его нет);
- бэкапит текущий `/etc/nixos` в `/etc/nixos.bak-<дата>`;
- копирует конфиг из репозитория в `/etc/nixos`;
- делает `nixos-rebuild switch` с включёнными бинарными кешами;
- создаёт `~/nixos-config` → `/etc/nixos`, чтобы работал alias `rebuild`;
- спрашивает имя пользователя (по умолчанию `nixos`) и его пароль.

> Нужен **публичный** репозиторий. Если он приватный — авторизуйтесь (`gh auth login` или PAT), либо клонируйте вручную и выполните `sudo nixos-rebuild switch --flake /etc/nixos#nixos`.

## Minimal ISO: установка одной командой

С флешки **NixOS minimal ISO 26.05**. Поднимите сеть (обычно DHCP сам; иначе `nmtui`).

```bash
sudo nix --extra-experimental-features 'nix-command flakes' \
  run github:SPdrErgo/nixos-config#install-iso -- /dev/vda
```

Что делает:

- затирает **весь диск** (укажите свой: `/dev/sda`, `/dev/nvme0n1`, ...);
- GPT: ESP 512 MiB + btrfs с subvolumes `@`, `@home`, `@nix`;
- `nixos-generate-config` + `nixos-install` с вашим flake;
- спрашивает `YES`, имя пользователя (по умолчанию `nixos`), root-пароль и пароль этого пользователя.

После установки: `reboot`, вынуть флешку. Требуется публичный репозиторий.

> Диск будет полностью стёрт. Скрипт откажется работать, если с этого диска что-то смонтировано (защита от затирания live-флешки).

## Установка с нуля (вручную, с ISO)

1. Загрузиться с NixOS ISO **26.05**, подключить сеть.
2. Разметить диск и смонтировать в `/mnt` (например btrfs subvolumes `@`, `home`, `nix` + EFI в `/boot`).
3. Сгенерировать hardware-конфиг:

   ```bash
   nixos-generate-config --root /mnt
   ```

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

6. Задать пароль пользователю (имя — из `/mnt/etc/nixos/user.nix`, по умолчанию `nixos`):

   ```bash
   nixos-enter --root /mnt -c 'passwd nixos'
   ```

7. Перезагрузка. В SDDM выбрать сессию **niri** или **Plasma**.

## SSH

В этом снимке SSH **выключен**. Чтобы включить, сначала добавьте свой ключ и только потом включайте сервис (одним rebuild, иначе потеряете доступ):

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

Или оставьте SSH выключенным и работайте локально.

## После установки

```bash
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#nixos
```

Первый switch делается через `nixos-rebuild`: `nh` появится в PATH только после активации. Дальше работают алиасы:

```bash
rebuild   # sudo nh os switch ~/nixos-config
update    # sudo nh os switch --update ~/nixos-config
clean     # sudo nh clean all
```

Обновление конфига:

```bash
cd ~/nixos-config && git pull && rebuild
```

## Бинарные кеши

В `configuration.nix` прописаны:

- `https://mirror.yandex.ru/nixos`
- `https://cache.nixos.org`
- `https://niri.cachix.org`
- `https://noctalia.cachix.org`

Они начинают действовать **после** первого `nixos-rebuild switch` (Nix читает `/etc/nix/nix.conf` текущей системы). Чтобы не собирать noctalia из исходников до активации:

```bash
bash scripts/cached-build.sh
```

Скрипт собирает систему с явно указанными substituters/ключами, после чего `nixos-rebuild switch` переиспользует готовые пути из store.

## niri в виртуальной машине

niri требует GPU с EGL/GBM и **не умеет software-рендеринг**. В QEMU нужен virtio-gpu с 3D:

- видео: `<model type='virtio' heads='1' primary='yes'><acceleration accel3d='yes'/></model>`
- SPICE: только через **unix socket** с `<gl enable='yes'/>`. QEMU 11 + spice 0.16 падает при `gl=on` через TCP (`invalid video codec` — отсутствует gstreamer-энкодер).
- virt-manager 5.1 не умеет SPICE over unix socket; консоль открывается через `spicy --uri spice+unix:///var/lib/libvirt/qemu/spice-nixos.sock` (нужен доступ к сокету, например группа `libvirt-qemu`).

Проверка в госте: должен существовать `/dev/dri/renderD128`.

## Замечания

- Пароль и приватные ключи в репозиторий не попадают.
- `hardware-configuration.nix` содержит UUID диска исходной VM.
- KDE и niri установлены одновременно; сессия выбирается в SDDM.
- Если udiskie конфликтует с автомонтированием Plasma — поставьте `services.udiskie.automount = false` и монтируйте через `udiskie-mount -a`.
