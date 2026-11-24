# Decision Log
## 001 – Lab address space: 172.20.0.0/16
**Date:** 2026-11-19
**Context:** The home network (eero) uses 10.0.0.0/8, which covers every 10.x range.
**Decision:** All lab networks behind pfSense use 172.20.0.0/16, one /24 per VLAN.
**Why:** Overlapping subnets on pfSense WAN and LAN break routing. 172.31.0.0/16 is avoided because it's the AWS default VPC range, reserved for a future site-to-site VPN.

## 002 – Proxmox management moved into the lab network
**Date:** 2026-11-23
**Context:** The plan was to keep Proxmox management on the home network as a lockout fallback, but the home switch had no free port.
**Decision:** Proxmox management moved to 172.20.10.10/24 behind pfSense.
**Trade-off:** If pfSense fails, the web UI is unreachable. Fallback is local console access over HDMI.

## 003 – Proxmox repositories
**Date:** 2026-11-23
**Context:** On Proxmox VE 9.2, the enterprise repos were active and the Debian repos were disabled.
**Decision:** Disabled the enterprise and Ceph enterprise repos, enabled pve-no-subscription and the Debian main and security repos, then ran a full upgrade.
**Why:** No subscription, and the host needs Debian security patches.
