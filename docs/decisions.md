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

## 004 – VLAN segmentation
**Date:** 2026-11-23
**Decision:** Management stays untagged (172.20.10.0/24). VLANs 20 SERVERS, 30 CLIENTS and 40 DMZ are tagged on a trunk from pfSense through a GS308E to a VLAN-aware Proxmox bridge.
**Policy:** Each VLAN may reach pfSense DNS and the internet, and is blocked from all RFC1918 ranges (alias PRIVATE_NETS).
**Verified:** A test container on VLAN 20 got a DHCP lease, resolved DNS and reached the internet, and failed to reach management (172.20.10.10).
**Why untagged management:** Tagging the management network risks locking out pfSense, the switch and Proxmox at once.

## 005 – First domain controller: DC01
**Date:** 2026-11-26
**Decision:** Windows Server 2025 (Server Core, Evaluation) as the first DC of a new forest, **ad.rwglover.com** (NetBIOS RWGLOVER), with AD-integrated DNS.
**Build:** Proxmox VM 101: 2 vCPU, 2 GB RAM, 32 GB disk, UEFI with vTPM, VirtIO SCSI and network. Static IP 172.20.20.10 on VLAN 20 SERVERS. DNS forwarder 172.20.20.1 (pfSense). Promoted with `scripts/Install-DC.ps1` (dry run by default, `-Commit` to apply).
**Why:**
- Server Core keeps the footprint small and forces management through PowerShell and RSAT.
- A subdomain of a domain I own avoids `.local` and keeps the public rwglover.com free for the website and Microsoft 365 hybrid identity.
**Issues fixed:**
- The network adapter was missing because the VirtIO NetKVM driver wasn't loaded during setup. Installed it with `pnputil`.
- Windows Update failed (0x80240438) because DNS was set to IPv6 placeholder addresses. Set DNS to pfSense explicitly.
**Verified:** Get-ADDomain, DNS forwarder and external name resolution all pass, and DFSR event 4602 confirms SYSVOL initialized. dcdiag flags DFSREvent for events logged during promotion, which clears after 24 hours.

## 006 – Wi-Fi admin access to the lab (temporary)
**Date:** 2026-11-26
**Context:** The admin laptop needs to reach the lab over home Wi-Fi (10.0.0.0/8), not only by Ethernet on the lab switch.
**Decision:**
- Removed the "Block private networks" rule on pfSense WAN.
- Added a WAN pass rule: source 10.0.0.88 (admin laptop) → 172.20.0.0/16.
- Added a persistent route on the laptop: 172.20.0.0/16 via 10.0.0.29 (pfSense WAN).
- Reserved both addresses in the eero.
**Trade-off:** Only one host is allowed in, but access depends on a fixed IP and only works inside the house. The bogon block stays in place.
**Planned replacement:** WireGuard VPN on pfSense for remote admin access from anywhere.
**Verified:** Over Wi-Fi, pinged pfSense (172.20.10.1) and Proxmox (172.20.10.10), and loaded the Proxmox web interface.

## 007 – Admin account tiering
**Date:** 2026-11-26
**Context:** The built-in Administrator was being used for daily work.
**Decision:** Created t0-rglover in RWG/Admin/Tier0 as the day-to-day Domain Admin account (marked sensitive, cannot be delegated). The built-in Administrator got a 25+ character random password stored in a password manager and is reserved for break-glass recovery. It stays enabled.
**Why:** Separating named admin accounts by tier limits credential exposure and gives an audit trail tied to a person.
**Verified:** Signed in over SSH as t0-rglover, and whoami /groups shows Domain Admins.
