# Project N.O.M.A.D. — Install Record & Plans

Owner: Jahnoi (noija). Node installed **2026-07-13** on Windows laptop `LAPTOP-5D13SUCH`
via WSL2 (Ubuntu 26.04). Command Center v1.33.0 running at `http://localhost:8080`.

Upstream project: https://github.com/Crosstalk-Solutions/project-nomad (Apache 2.0)

---

## 1. Current setup (what was done)

- WSL2 + Ubuntu 26.04, user `noija`
- Official installer run: `install/install_nomad.sh` from the upstream repo main branch
- Install location on the node: `/opt/project-nomad` (compose file `management_compose.yaml`,
  helper scripts `start_nomad.sh` / `stop_nomad.sh` / `update_nomad.sh`)
- **WSL fix applied**: first start failed with
  `path / is mounted on / but it is not a shared or slave mount`.
  Fixed with `sudo mount --make-rshared /`. Made permanent in `/etc/wsl.conf`:

  ```ini
  [boot]
  command = "mount --make-rshared /"
  ```

### After every Windows reboot

```bash
# in the Ubuntu window
sudo bash /opt/project-nomad/start_nomad.sh
```

### Phone / LAN access (run in ADMIN PowerShell; re-run after reboots — WSL IP changes)

```powershell
$wslip = (wsl -d Ubuntu hostname -I).Trim().Split(" ")[0]
netsh interface portproxy delete v4tov4 listenport=8080 listenaddress=0.0.0.0
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=8080 connectaddress=$wslip
netsh advfirewall firewall add rule name="NOMAD 8080" dir=in action=allow protocol=TCP localport=8080
ipconfig | findstr IPv4
```

Then on the phone (same Wi-Fi): `http://<laptop IPv4>:8080`.
If it fails: check Windows network profile isn't "Public", and router AP-isolation is off.

---

## 2. Rebrand plan (scheduled: Friday 2026-07-17, ~8pm)

Goal: NOMAD Command Center with Jahnoi's own logo, name, and colors; publish on his
brand page/site.

Steps for the Claude session that picks this up:

1. Fetch upstream source (public repo above); locate the Command Center frontend
   (logo assets, app title, theme colors — the olive/dark theme seen in v1.33.0).
2. Create a branded fork/overlay:
   - Replace logo + favicon with Jahnoi's brand assets (ASK HIM for the files first).
   - Change displayed product name; keep "Powered by Project N.O.M.A.D." attribution.
   - Adjust theme colors to brand palette.
3. Build a custom Docker image; update `/opt/project-nomad/management_compose.yaml`
   (or an override file) to use the custom image instead of
   `ghcr.io/crosstalk-solutions/project-nomad:latest`.
   NOTE: upstream `update_nomad.sh` will overwrite the stock image reference — prefer a
   `compose.override.yaml` so updates don't clobber the rebrand.
4. Legal: Apache 2.0 permits modification. Keep LICENSE/NOTICE; do not claim the
   underlying system as original work; attribution line stays visible.
5. Clarify with Jahnoi what "push it to the brand page" means (his website? somewhere
   in NOMAD?) before publishing anything.

## 3. Obsidian integration plan

Goal: everything from NOMAD's Notes lives in Jahnoi's Obsidian brain, organized.

- NOMAD Notes = **FlatNotes**, plain `.md` files under `/opt/project-nomad` storage
  (find exact dir with `sudo find /opt/project-nomad -name '*.md' -path '*flatnotes*'`
  or inspect the compose volume mounts).
- FlatNotes is FLAT (no folders); Obsidian vaults are nested. Best-fit approach:
  1. In the Obsidian vault, create a `NOMAD/` folder.
  2. Sync FlatNotes storage → `NOMAD/` (two-way). Files are reachable from Windows at
     `\\wsl.localhost\Ubuntu\opt\project-nomad\...`. If Obsidian is flaky over the UNC
     path, use a small scheduled robocopy/rsync sync script instead of a live mount.
  3. Notes authored in nested vault folders won't render in FlatNotes — treat `NOMAD/`
     as the shared flat space; the rest of the vault stays Obsidian-only.
- If he wants richer sync later: install Syncthing (or similar) from NOMAD's Supply
  Depot and sync the vault properly across devices.
