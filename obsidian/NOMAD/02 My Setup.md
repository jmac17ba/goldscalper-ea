---
tags: [nomad, setup]
created: 2026-07-14
---

# My Setup

Installed **2026-07-13** with Claude walking me through it. Command Center **v1.33.0**.

## The machine

- **Laptop:** `LAPTOP-5D13SUCH` (Windows)
- **Linux layer:** WSL2 running Ubuntu 26.04, username `noija`
- **Disk:** 1TB available to WSL — plenty for offline content
- **Laptop Wi-Fi address:** `192.168.50.229` (can change if the router reassigns it)
- **WSL internal address:** `172.29.161.19` (changes on reboots — don't rely on it)

## Where NOMAD lives

Everything is under `/opt/project-nomad` inside Ubuntu:

- `management_compose.yaml` — the Docker Compose file that defines all containers
- `start_nomad.sh` / `stop_nomad.sh` / `update_nomad.sh` — helper scripts
- `storage/` — data, logs

From Windows File Explorer, the same files are reachable at:
`\\wsl.localhost\Ubuntu\opt\project-nomad`

## One permanent fix that was needed

WSL needed a mount setting for the containers to start (see [[05 Troubleshooting]]).
It's now permanent in `/etc/wsl.conf`:

```ini
[boot]
command = "mount --make-rshared /"
```

## Related

- [[03 Daily Routine — Start and Stop]]
- [[09 Command Cheatsheet]]
