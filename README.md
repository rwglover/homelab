# homelab
# Homelab

A self-built lab environment for hands-on practice with systems engineering: virtualization, networking, identity, automation and monitoring. Every change is recorded in the [decision log](docs/decisions.md).

## Hardware
| Role | Device | Notes |
|---|---|---|
| Firewall | Mini PC, 2 NICs | pfSense CE |
| Hypervisor | HISTTON mini PC, i5-10310U, 24 GB RAM, 250 GB SSD | Proxmox VE 9.2 |
| Switch | Netgear GS308E | 802.1Q VLANs |

## Network
| Network | Subnet | Gateway |
|---|---|---|
| Home (upstream) | 10.0.0.0/8 | eero |
| Lab LAN / management | 172.20.10.0/24 | pfSense 172.20.10.1 |

## Roadmap
- [x] pfSense firewall, lab LAN, DHCP and DNS
- [x] Proxmox installed, updated, on the lab network
- [x] VLAN segmentation (management, servers, clients, DMZ)
- [ ] Active Directory domain controller
- [ ] VM templates, Terraform and Ansible
- [ ] Monitoring and backup, with a tested restore
- [ ] Hybrid identity with Microsoft 365

## 004 – VLAN segmentation
**Date:** 2026-11-23
**Decision:** Management stays untagged (172.20.10.0/24). VLANs 20 SERVERS, 30 CLIENTS and 40 DMZ are tagged on a trunk from pfSense through a GS308E to a VLAN-aware Proxmox bridge.
**Policy:** Each VLAN may reach pfSense DNS and the internet, and is blocked from all RFC1918 ranges (alias PRIVATE_NETS).
**Verified:** A test container on VLAN 20 got a DHCP lease, resolved DNS and reached the internet, and failed to reach management (172.20.10.10).
**Why untagged management:** Tagging the management network risks locking out pfSense, the switch and Proxmox at once.
