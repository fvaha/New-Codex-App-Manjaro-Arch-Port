## English

### Codex macOS → Manjaro port script

This repo contains a single main script that lets you run the Codex macOS desktop app on Manjaro/Arch Linux (x86_64).

### What the script does

- downloads the original `Codex.dmg` for macOS into `~/Downloads/codex-macos`
- installs required system packages (`p7zip`, `nodejs`, `npm`, `python`, `base-devel`, `git`, `electron`) via `pacman`
- ensures `pnpm` is available and uses `pnpm dlx` to run `asar` and `electron-rebuild`
- extracts `app.asar` from `Codex.dmg` into `~/apps/codex-port/app_asar`
- reconstructs and rebuilds the `better-sqlite3` native module for Linux/Electron in an isolated project, then copies it back into the app
- creates the launcher script `~/apps/codex-port/run-codex.sh` for starting the Codex GUI
- installs the `@openai/codex` CLI globally for the current user via `pnpm`

### How to use

1. On a Manjaro/Arch system (x86_64), in a terminal:

   ```bash
   cd /path/to/CodexAppPort
   bash ./codex-port-manjaro.sh
   ```

2. After the script completes successfully:

   ```bash
   ~/apps/codex-port/run-codex.sh
   ```

`run-codex.sh` uses the Codex CLI from `~/.local/share/pnpm/codex` by default, but you can override it with the `CODEX_CLI_PATH` environment variable.

---

## Bosanski

### Codex macOS → Manjaro port skripta

Ovaj repo sadrži jednu glavnu skriptu za pokretanje Codex macOS aplikacije na Manjaro/Arch Linuxu (x86_64).

### Šta radi skripta

- preuzima originalni `Codex.dmg` za macOS u `~/Downloads/codex-macos`
- instalira potrebne sistemske pakete (`p7zip`, `nodejs`, `npm`, `python`, `base-devel`, `git`, `electron`) preko `pacman`
- obezbjeđuje `pnpm` i koristi `pnpm dlx` za `asar` i `electron-rebuild`
- ekstrahuje `app.asar` iz `Codex.dmg` u `~/apps/codex-port/app_asar`
- rekonstruiše i ponovo kompajlira `better-sqlite3` modul za Linux/Electron u izolovanom projektu, pa ga kopira nazad u aplikaciju
- pravi `~/apps/codex-port/run-codex.sh` skriptu za pokretanje Codex GUI‑a
- instalira `@openai/codex` CLI globalno za korisnika preko `pnpm`

### Kako se koristi

1. Na Manjaro/Arch sistemu (x86_64), u terminalu:

   ```bash
   cd /put/do/CodexAppPort
   bash ./codex-port-manjaro.sh
   ```

2. Poslije uspješnog prolaza:

   ```bash
   ~/apps/codex-port/run-codex.sh
   ```

`run-codex.sh` podrazumijevano koristi Codex CLI iz `~/.local/share/pnpm/codex`, ali to se može promijeniti promjenljivom okruženja `CODEX_CLI_PATH`.
