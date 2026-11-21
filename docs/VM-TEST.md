# VM test run — MSI overlay (`msi-nix`)

You are an agent running on **`luka-nixos-test`**, a disposable NixOS VM. Your
job is to validate the MSI development overlay end-to-end and do a few desktop
spot checks, then report. Read this whole file before running anything.

## Rules

- Verify the machine first: `hostname` must print `luka-nixos-test`. If it does
  not, stop — this file is written for that VM only.
- `~/dotfiles` on the workstation is a *different system*; nothing here uses it.
- **Never** write secrets into files, commits, or reports. `.env.development`
  files and tokens stay where they are; redact output.
- Do not `git commit` or `git push` anywhere. Leave changes in the working tree
  for the user to review.
- Do not edit anything inside `~/projects/code/msi/<repo>` — those are work
  checkouts. Bundle tests use a copy under `/tmp`.
- Do not run `nix flake update`, do not delete `machine-setup/`, and do not
  start the old Docker compose stack (`machine-setup/dev up`).
- Some checks are visual (the pill, ghostty). Ask the user instead of guessing.

Report format at the end: one section per phase, each step marked PASS / FAIL /
SKIP with the command and a short output excerpt, then a "Blockers" list.

## Facts you need

| Thing | Value |
|---|---|
| NixOS config repo | `/home/luka/nixos-config` (flake output `luka-nixos-test`) |
| Overlay (this test) | `/home/luka/projects/code/msi-nix` (local git repo, not pushed) |
| Work repos root | `/home/luka/projects/code/msi` (`~/Code` symlinks here) |
| Phase-1 repos | `hms-core`, `homestay-management`, `lou`, `msi-utils` (private, `github.com/mystay/*`) |
| Expected Ruby | 3.0.7 (p220), OpenSSL 3.0.12, Bundler 2.5.23 |
| Expected Node | `lou` pins 20.9.0 → overlay maps EOL Node 20 to **22** (documented deviation) |
| Apps / ports | lobby 3001, executive 3002, reception 3003, willie 3004, lou 3005 |
| Hosts | `hms-<app>.test` and `aus.hms-<app>.test` → 127.0.0.1 |
| Services | Mongo `mongo:7.0.14` container, Redis 8 native, Caddy 2.11 native |
| Caddy CA | `~/.local/share/caddy/pki/authorities/local/root.crt` |
| Stack state | `$XDG_STATE_HOME/msi` (Mongo volume is a Docker named volume) |
| Runtime state | process-compose server log at `/tmp/process-compose-<user>.log` |

## Phase 0 — prerequisites and transfer

1. **Resources**
   ```sh
   hostname
   nproc; free -h; df -h /nix /home
   grep -qw avx /proc/cpuinfo && echo avx=yes || echo avx=no
   ```
   Mongo 7 requires AVX. If `avx=no`, note it and skip all Mongo/stack steps
   (the rest is still testable).

2. **Docker**
   ```sh
   docker info >/dev/null 2>&1 && echo docker=ok || echo docker=unavailable
   ```
   If permission denied, the host module (Phase 4) or a re-login is needed —
   note it and continue with steps that do not need Docker.

3. **GitHub auth** (do not attempt to log in for the user)
   ```sh
   gh auth status
   ```
   If it is not authenticated, **stop here** and ask the user to run
   `gh auth login` on the VM. Everything after this needs the private repos.

4. **Get the overlay onto the VM.** It exists only on the workstation. Use the
   transfer the user provides; preferred:
   ```sh
   rsync -a --exclude .git \
     <arch-user>@<arch-host>:/home/luka/projects/code/msi-nix/ \
     /home/luka/projects/code/msi-nix/
   ```
   Alternative: `git clone <remote> /home/luka/projects/code/msi-nix` if the
   user has pushed it. Verify:
   ```sh
   ls /home/luka/projects/code/msi-nix/flake.nix
   cd /home/luka/projects/code/msi-nix && git status --short   # expect clean or user-known changes
   ```

5. **Clone the phase-1 repos** (skip any that already exist):
   ```sh
   mkdir -p /home/luka/projects/code/msi
   for r in hms-core homestay-management lou msi-utils; do
     [ -d "/home/luka/projects/code/msi/$r" ] || \
       gh repo clone "mystay/$r" "/home/luka/projects/code/msi/$r"
   done
   ls /home/luka/projects/code/msi/{hms-core,homestay-management,lou,msi-utils}/.tool-versions
   ```
   The overlay's path inputs are hard-coded to those absolute paths, so they
   must exist before any flake command.

## Phase 1 — evaluate and build

Run everything from `/home/luka/projects/code/msi-nix`.

1. ```sh
   nix flake check --no-build
   ```
   Expect: `all checks passed!` (a warning about `homeModules` is fine).

2. Build the Ruby pin (first run is long — expect 10–25 min and ~2 GB):
   ```sh
   nix build .#ruby
   ```

3. Shell smoke tests:
   ```sh
   nix develop .#lou --command bash -c \
     'ruby -v; node --version; bundle -v; ruby -ropenssl -e "puts OpenSSL::OPENSSL_VERSION"'
   nix develop .#msi-utils --command bash -c 'ruby -v; bundle -v'
   ```
   Expect Ruby `3.0.7p220`, Bundler `2.5.23`, Node `v22.*`, OpenSSL `3.0.12`.

4. Confirm the CLI builds and the process project validates:
   ```sh
   MSI="$(nix build --no-link --print-out-paths .#msi)/bin/msi"
   "$MSI" help
   "$MSI" apps        # executive lobby lou reception willie
   "$MSI" hosts       # 5 host pairs
   nix shell nixpkgs#process-compose --command \
     process-compose -f "$(nix build --no-link --print-out-paths .#stack)" --dry-run
   ```
   Expect: `Validated 8 configured processes`.

## Phase 2 — bundle install in a copy

Do not dirty the checkout. Use `hms-core` (smallest Rails repo):

```sh
rm -rf /tmp/msi-test && mkdir -p /tmp/msi-test
cp -a /home/luka/projects/code/msi/hms-core /tmp/msi-test/hms-core
nix develop .#hms-core --command bash -c '
  export BUNDLE_PATH=/tmp/msi-test/bundle
  cd /tmp/msi-test/hms-core
  bundle install --jobs 4
  bundle check
  bundle exec rspec --version
'
```

Expect exit 0 and "dependencies are satisfied". If a native gem fails, record
the gem name and compiler error — that is the main thing this phase exists to
find. Do not retry with modified repos.

## Phase 3 — stack (requires AVX + Docker)

1. Make sure nothing old is running:
   ```sh
   pgrep -af process-compose || true
   docker ps --format '{{.Names}}' | grep -E 'msi-(mongo|redis)' || true
   ```
   If the old compose stack is running, stop it (`docker compose -p msi-dev down`)
   and note it.

2. Caddy needs :443:
   ```sh
   sysctl net.ipv4.ip_unprivileged_port_start
   ```
   If it is 1024, either wire the host module (Phase 4) or, with user approval,
   `sudo sysctl -w net.ipv4.ip_unprivileged_port_start=0` for this run.

3. Start the services. `msi` is installed in every dev shell:
   ```sh
   nix develop .#lou --command bash -c 'msi services up -d; sleep 8; msi status'
   docker ps --filter name=msi-mongo --format '{{.Status}}'
   ```
   Expect mongo/redis/caddy running. If mongo restarts, check
   `docker logs msi-mongo` (AVX message = report and skip apps).

4. CA + routes:
   ```sh
   CA=~/.local/share/caddy/pki/authorities/local/root.crt
   ls -l "$CA"
   curl -sS --cacert "$CA" --resolve hms-lobby.test:443:127.0.0.1 \
     -o /dev/null -w '%{http_code}\n' https://hms-lobby.test
   ```
   Before an app is running this should be a 502 from Caddy (not a TLS error).
   If TLS fails, report the exact curl error.

5. Install the app's gems (frozen, so a clean lock cannot be rewritten) and
   run the repo's bootstrap, then start it:
   ```sh
   nix develop .#lou --command bash -c 'msi bootstrap lobby'
   nix develop .#lou --command bash -c 'msi up -d lobby; sleep 20; msi status'
   nix develop .#lou --command bash -c 'msi logs lobby' | tail -30
   ```
   `msi bootstrap` runs `bundle install --frozen` and then `bin/bootstrap`; if
   the lock is out of sync it fails loudly instead of editing the checkout.
   Then request it with the CA and `--resolve`. Expect either a rendered login
   page or a Rails error page / 404 because the database is empty — record
   which. A 502 means the server did not bind; include the log excerpt.

6. Tear down:
   ```sh
   nix develop .#lou --command bash -c 'msi down'
   docker ps --filter name=msi-mongo --format '{{.Names}}'   # expect empty
   ```

## Phase 4 — wire into `nixos-config` (apply, do not commit)

Apply these edits, rebuild, and report the diff. Keep them uncommitted.

`/home/luka/nixos-config/flake.nix` — add to `inputs`:

```nix
    msi-nix.url = "path:/home/luka/projects/code/msi-nix";
```

`/home/luka/nixos-config/modules/hosts/luka-nixos-test/default.nix`:

- add `inputs.msi-nix.nixosModules.default` to the **top-level** `imports` list
  (next to `../features/desktop`), not inside `users.luka`;
- add at the host level:

```nix
  services.msi = {
    enable = true;
    dockerUsers = [ "luka" ];
  };
```

- inside `home-manager.users.luka`, next to `my.desktops.environment`, add:

```nix
      programs.msi.enable = true;
```

and in `/home/luka/nixos-config/modules/users/luka/home.nix` add
`inputs.msi-nix.homeManagerModules.default` to the HM `imports` list.

Rebuild:

```sh
sudo nixos-rebuild switch --flake /home/luka/nixos-config#luka-nixos-test
```

Verify:

```sh
command -v msi
readlink ~/Code                       # → /home/luka/projects/code/msi
getent hosts hms-lobby.test aus.hms-lou.test
id -nG | tr ' ' '\n' | grep -x docker
sysctl net.ipv4.ip_unprivileged_port_start
```

`msi` on PATH comes from the new generation; `~/Code` and the hosts entries are
the module's work. If Docker group membership only appears after re-login, note
it rather than rebooting.

## Phase 5 — desktop spot checks (quick)

1. **Quickshell / LiquoRice is the active DE**
   ```sh
   pgrep -af quickshell | head -3
   readlink ~/.config/quickshell
   ls ~/.config/hypr/scripts
   ```
   Expect the quickshell process, a symlink to `configs/quickshell`, and the
   three helper scripts. Ask the user to confirm the pill is visible and the
   launcher works.

2. **Compositor look matches the Arch dotfiles**
   ```sh
   L=~/.config/hypr/hyprland.lua
   grep -c '^hl.curve' "$L"        # 5
   grep -c '^hl.animation' "$L"    # 17
   grep -A4 '^hl.gesture' "$L"     # 3-finger horizontal workspace
   hyprctl -j getoption decoration:rounding
   hyprctl -j getoption decoration:blur:vibrancy
   hyprctl -j getoption general:gaps_out
   ```
   Expect rounding 8, vibrancy 0.1696, gaps_out 3/8/8/8.

3. **Herdr replaces tmux in ghostty**
   ```sh
   command -v herdr && herdr --version          # 0.9.5
   command -v tmux || echo "tmux absent (expected)"
   grep -n '^command' ~/.config/ghostty/config  # path ending …/bin/herdr
   ```
   Ask the user to open a new ghostty window and confirm herdr starts.

## Failure handling

| Symptom | Meaning / action |
|---|---|
| `permission denied` on docker | Host module not applied yet; finish Phase 4 or note it |
| `mongod` container restarts | Likely missing AVX; report `docker logs msi-mongo` and skip apps |
| Caddy `bind: permission denied` | `ip_unprivileged_port_start` still 1024; apply Phase 4 or sysctl |
| `msi: no Ruby/bundler on PATH` | You ran `msi up` outside `nix develop`; use the env-passing form above |
| TLS error from curl | Use `--cacert "$CA"`; if the file is missing, Caddy never started |
| Ruby build OOMs | Report `free -h` and stop; do not retry with lower parallelism unless asked |
| Gem native extension fails | Record gem + error; Phase 2 is specifically looking for this |

## Final report template

```
## Environment
hostname / nproc / RAM / disk / avx / docker / gh auth

## Phase 1 — build & shells
PASS/FAIL: nix flake check
PASS/FAIL: nix build .#ruby (time)
PASS/FAIL: shell smoke (versions observed)

## Phase 2 — bundle install
PASS/FAIL: hms-core bundle install / bundle check / rspec

## Phase 3 — stack
PASS/FAIL: services up (mongo/redis/caddy)
PASS/FAIL: CA + routes
PASS/FAIL: lobby boot (HTTP code + log excerpt)
PASS/FAIL: down (containers gone)

## Phase 4 — host wiring
PASS/FAIL: rebuild, msi on PATH, ~/Code, hosts, docker group, sysctl
diff of nixos-config changes (uncommitted)

## Phase 5 — desktop
quickshell processes / config links
animation values
herdr version + ghostty command

## Blockers
- …

## Suggestions
- …
```
