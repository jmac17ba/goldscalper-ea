---
tags: [nomad, howto]
created: 2026-07-14
---

# Daily Routine — Start and Stop

## ⚠️ The one rule

**Keep the Ubuntu window open while using NOMAD.** Closing it shuts down the entire server — laptop and phone access both die. Minimize it, don't close it.

## Starting NOMAD (after a reboot or if it's down)

1. Start menu → open **Ubuntu**
2. Run:
   ```bash
   sudo bash /opt/project-nomad/start_nomad.sh
   ```
3. Wait for *"Finished initiating start of all Project N.O.M.A.D containers."*
4. Check `http://localhost:8080` in the browser
5. If the **phone** can't connect after a reboot, run the phone fix → [[04 Phone Access]]

## Stopping NOMAD (to free up the laptop)

```bash
sudo bash /opt/project-nomad/stop_nomad.sh
```

## Updating NOMAD (occasionally, when online)

```bash
sudo bash /opt/project-nomad/update_nomad.sh
```

⚠️ After the Friday rebrand ([[06 Rebrand Plan]]), updates may overwrite the custom branding — the plan accounts for this with an override file, but double-check after updating.

## Is it running? Quick check

```bash
sudo docker ps
```

Should list containers named `nomad_admin`, `nomad_mysql`, `nomad_redis`, `nomad_dozzle`, `nomad_updater`, `nomad_disk_collector`.
