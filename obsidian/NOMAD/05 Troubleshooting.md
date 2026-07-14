---
tags: [nomad, troubleshooting]
created: 2026-07-14
---

# Troubleshooting

Every problem hit during install (2026-07-13/14) and the exact fix. Newest lessons at the top of my mind:

## "Linux commands don't work in PowerShell" (and vice versa)

Two different worlds:
- **Ubuntu window** (`noija@LAPTOP...$` prompt) → Linux commands (`sudo`, `bash`, `apt-get`)
- **PowerShell** (`PS C:\...>` prompt) → Windows commands (`netsh`, `ipconfig`)

`netsh: command not found` in Ubuntu, or `The token '&&' is not valid` in PowerShell = wrong window.

## sudo password failed / forgotten

Reset it from Windows PowerShell:
```powershell
wsl -d Ubuntu -u root
```
then at the `#` prompt: `passwd noija` → type new password twice → `exit`.
(Screen shows NOTHING while typing passwords — that's normal, keep typing.)

## Containers fail: "path / is mounted on / but it is not a shared or slave mount"

WSL quirk. Fix:
```bash
sudo mount --make-rshared /
```
Made permanent in `/etc/wsl.conf` (see [[02 My Setup]]) so it shouldn't return.

## Phone can't reach NOMAD

Full guide in [[04 Phone Access]]. Root cause we found: capturing WSL's address into a PowerShell variable (`$wslip`) returned garbage ("A"), so the port forward pointed nowhere. Fix: forward to `127.0.0.1` instead — never chase the WSL IP.

## "The requested operation requires elevation"

The PowerShell window isn't Administrator. Title bar must say **Administrator: Windows PowerShell** — right-click → Run as administrator.

## Everything dead after closing the Ubuntu window

Expected — WSL shuts down when its window closes. Reopen Ubuntu, run the start script ([[03 Daily Routine — Start and Stop]]).

## Pasting multiple commands glues them together

Paste one command at a time, or paste blocks and press Enter at the end — glued commands like `...8080netsh interface...` silently do the wrong thing.
