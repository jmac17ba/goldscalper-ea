---
tags: [nomad, reference, commands]
created: 2026-07-14
---

# Command Cheatsheet

Every command in one place. **U** = Ubuntu window, **PS-A** = Administrator PowerShell.

## Everyday

| What | Where | Command |
|------|-------|---------|
| Start NOMAD | U | `sudo bash /opt/project-nomad/start_nomad.sh` |
| Stop NOMAD | U | `sudo bash /opt/project-nomad/stop_nomad.sh` |
| Update NOMAD | U | `sudo bash /opt/project-nomad/update_nomad.sh` |
| Check containers running | U | `sudo docker ps` |
| Open Ubuntu from PowerShell | PS | `wsl -d Ubuntu` |

## Addresses

| What | Address |
|------|---------|
| Laptop browser | `http://localhost:8080` |
| Phone (same Wi-Fi) | `http://192.168.50.229:8080` |
| NOMAD files from Windows | `\\wsl.localhost\Ubuntu\opt\project-nomad` |

## Fixes

| What | Where | Command |
|------|-------|---------|
| Phone access repair | PS-A | see [[04 Phone Access]] (3-line block) |
| Find laptop's Wi-Fi IP | PS | `ipconfig \| findstr IPv4` → the `192.168.x.x` line |
| Find WSL's IP | U | `hostname -I` (first number) |
| Reset forgotten sudo password | PS | `wsl -d Ubuntu -u root` then `passwd noija` |
| Container mount error fix | U | `sudo mount --make-rshared /` |
| Show port forwards | PS-A | `netsh interface portproxy show all` |
| Test NOMAD responding | PS | `curl.exe -s -o NUL -w "%{http_code}" http://192.168.50.229:8080` (want `200`) |

## Golden rules

1. Ubuntu window stays **open** while NOMAD is in use
2. Linux commands → Ubuntu; `netsh`/`ipconfig` → PowerShell
3. Password prompts show nothing while typing — keep typing
4. `requires elevation` = need the **Administrator** PowerShell
