---
tags: [nomad, howto, phone]
created: 2026-07-14
---

# Phone Access

**Working since 2026-07-14.** On the phone (same Wi-Fi as the laptop):

> **http://192.168.50.229:8080**

Type it with `http://` — Safari sometimes forces `https://` and fails.

## How it works

The phone can only see the **Windows** side of the laptop, but NOMAD lives inside **WSL**. A Windows "port proxy" relays traffic: phone → laptop's Wi-Fi address (`192.168.50.229:8080`) → Windows loopback (`127.0.0.1:8080`) → WSL → NOMAD. A firewall rule ("NOMAD 8080") lets the traffic in, and the `iphlpsvc` service does the relaying.

We route through loopback on purpose — it keeps working even when WSL's internal address changes after reboots.

## The fix if the phone stops connecting

Run in **Administrator PowerShell** (Start → type `powershell` → right-click → **Run as administrator**):

```powershell
netsh interface portproxy reset
netsh interface portproxy add v4tov4 listenaddress=192.168.50.229 listenport=8080 connectaddress=127.0.0.1 connectport=8080
curl.exe -s -o NUL -w "HTTP status: %{http_code}" http://192.168.50.229:8080
```

`HTTP status: 200` = fixed.

If the laptop's Wi-Fi address itself changed (rare): find the new one with `ipconfig | findstr IPv4` (the `192.168.x.x` line), swap it into the `listenaddress=` above AND use it on the phone.

## Still not working? Check in order

1. Is NOMAD running at all? `localhost:8080` on the laptop → if dead, see [[03 Daily Routine — Start and Stop]]
2. Phone on the same Wi-Fi? (turn off cellular data to be sure)
3. Windows network profile set to **Private**, not Public (Settings → Network & Internet → Wi-Fi → network name)
4. More history in [[05 Troubleshooting]]
