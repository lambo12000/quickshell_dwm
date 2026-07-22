# quickshell_dwm

A macOS-flavored desktop for Arch Linux / X11, built from **dwm 6.8** (lightly
patched) and **[quickshell](https://quickshell.org)** (bar, Spotlight-style
launcher, notification system, calendar).

## Features

- **macOS-style keybindings** on Super (Cmd), with Alt↔Win swapped at the X
  level so the key next to the spacebar acts as Cmd
- **Spotlight launcher** — `Super+Space`, fuzzy app search, arrow keys + Enter,
  Escape to dismiss
- **quickshell bar** replacing the dwm bar: workspaces (tags), layout symbol,
  focused window title, **system tray** (SNI + XEmbed via snixembed) with
  working right-click menus, **network** and **bluetooth** popups, a
  **notification center**, and a clock with a **calendar popup**
- **Notification daemon built in** (replaces dunst): macOS-style toasts,
  history, and per-app rules — pin an app in the notification center and its
  toasts persist until dismissed; unpinned apps auto-expire. Rules and history
  live in `notification-data.json`
- **Click-to-focus** (no focus-follows-mouse), and `Super+Shift+J` bounces the
  focused window between monitors *with focus following it*

## Layout

| Path | What it is |
|---|---|
| `*.qml`, `qmldir` | The quickshell shell (bar, launcher, notifications, calendar) |
| `dwm/` | dwm 6.8 source with the local patch (see below) |
| `dotfiles/xinitrc` | X session: key swap, picom, quickshell, snixembed ordering, dwm |
| `dotfiles/picom.conf` | Stock picom config with tooltip opacity fixed to 1.0 |
| `install.sh` | Arch installer: packages, dwm build, dotfiles |

## Install (fresh Arch system)

```sh
git clone https://github.com/lambo12000/quickshell_dwm ~/projects/quickshell_dwm
cd ~/projects/quickshell_dwm
./install.sh
```

Then **edit `~/.xinitrc`**: the `xrandr` monitor layout and the NVIDIA/browser
environment variables are specific to my machine — adjust or delete them.
Finally `startx` from a TTY.

> The clone path matters: dwm's `Super+Space` binding and the xinitrc launch
> quickshell from `~/projects/quickshell_dwm`. Cloning elsewhere means editing
> `launchercmd` in `dwm/config.h` and the `qs -p` line in the xinitrc.

## Keybindings

| Key | Action |
|---|---|
| `Super+Space` | Spotlight launcher |
| `Super+Enter` | Terminal (ghostty) |
| `Super+Q` / `Super+W` | Close window |
| `Super+Shift+J` | Move window to the other monitor (focus follows) |
| `Super+1–9` | View tag / workspace |
| `Super+Shift+1–9` | Send window to tag |
| `Super+Tab` | Next occupied tag (wraps around) |
| `Super+Shift+Tab` | Previous occupied tag (wraps around) |
| `Super+J/K` | Cycle window focus on this monitor |
| `Super+,` / `Super+.` | Focus other monitor |
| `Super+T/F/M` | Tile / floating / monocle layout |
| `Super+Shift+Enter` | Promote window to master |
| `Super+P` | dmenu (fallback launcher) |
| `Super+Shift+Q` | Quit dwm (like Cmd+Shift+Q logout) |

The physical **Alt** key is Cmd/Super (via `setxkbmap -option altwin:swap_alt_win`
in the xinitrc); the physical Win key produces Alt, so apps keep their real
Alt shortcuts.

## How it fits together

dwm knows nothing about quickshell, and quickshell knows nothing about dwm —
they meet in three narrow places:

1. **Dock windows are unmanaged.** The dwm patch makes `manage()` map
   `_NET_WM_WINDOW_TYPE_DOCK` windows without managing them, so the bar and
   launcher position themselves and are never tiled. dwm's own (empty) bar
   stays enabled at a fixed `barheight = 30` purely to reserve the strip the
   quickshell bar draws over.
2. **State flows out through a file.** On every internal redraw dwm writes
   per-monitor state (selected/occupied/urgent tags, layout, focused title) as
   JSON to `$XDG_RUNTIME_DIR/dwm-state.json`; the bar watches it with a
   `FileView`.
3. **Commands flow back through synthetic keys.** Clicking a tag in the bar
   runs `xdotool key super+N` — the bar reuses dwm's own bindings instead of
   needing an IPC patch.

The launcher is toggled over quickshell's IPC
(`qs -p <dir> ipc call launcher toggle`). Because dwm ignores dock windows,
the launcher grabs X input focus itself when shown and restores the previously
focused window when hidden.

## Quirks worth knowing

- **quickshell windows have no `WM_CLASS` and an empty legacy `WM_NAME`** —
  only `_NET_WM_NAME` is set. `xdotool search --name` therefore can't find
  them; the launcher's focus script finds its window by pid + geometry.
- **snixembed must start *after* quickshell** owns
  `org.kde.StatusNotifierWatcher`, or it spawns its own stub watcher and no
  tray icons ever appear. The xinitrc has a `busctl` wait-loop for this.
- **picom's default config renders popups at 75% opacity** (they're typed as
  tooltips). `dotfiles/picom.conf` sets that rule to 1.0.
- Tray menus are rendered by the bar itself via `QsMenuOpener` — quickshell's
  native `display()` menu call doesn't work on X11.
- quickshell 0.3.0 does not hot-reload QML; restart `qs` after editing.

## Requirements

Everything `install.sh` installs: `quickshell` (extra), `picom`, `snixembed`,
`xdotool`, `dmenu`, `ghostty`, `ttf-jetbrains-mono-nerd`, `networkmanager`,
`bluez`/`bluez-utils`, plus the X11 build deps for dwm. NetworkManager and
bluez are required for the bar's network/bluetooth widgets.
