# Old Router DHCP Configuration (Archer C2300)

**Extracted:** 2026-02-02
**Source:** http://tplinkwifi.net Advanced → Network → DHCP Server

## DHCP Server Settings

- **DHCP Server:** On
- **IP Address Pool:** 192.168.1.100 - 192.168.1.199
- **Address Lease Time:** 120 minutes
- **Default Gateway:** 192.168.1.1
- **Primary DNS:** (empty/optional)
- **Secondary DNS:** (empty/optional)

## DHCP Reservations (10 existing)

| # | Description | MAC Address | Reserved IP |
|---|-------------|-------------|-------------|
| 1 | Personal_Macbook_Wireless | 82-6D-FA-26-35-1F | 192.168.1.53 |
| 2 | Windows_Pc_Wired | 00-68-EB-AD-93-F9 | 192.168.1.4 |
| 3 | Work_Macbook_Wireless | C2-07-DC-35-C2-6C | 192.168.1.52 |
| 4 | Geekom_Wired | 38-F7-CD-C5-B9-7F | 192.168.1.3 |
| 5 | Work_Macbook_Wired | 00-1C-C2-46-20-A9 | 192.168.1.2 |
| 6 | Personal_Macbook_Wired | 48-65-EE-1F-87-7D | 192.168.1.7 |
| 7 | Personal_Macbook_Wireless (dup?) | B6-5E-1F-2A-C2-85 | 192.168.1.57 |
| 8 | Windows_Pc_Wireless | 74-12-B3-63-C9-09 | 192.168.1.54 |
| 9 | poweredge-host-server | 14-18-77-57-75-36 | 192.168.1.200 |
| 10 | lima-0-rancher | 52-55-55-65-B2-7A | 192.168.1.120 |

## Raspberry Pi Reservations (to be added)

**Note:** MAC addresses will be obtained when Pis are powered on during Story 8.1.

| # | Description | MAC Address | Reserved IP |
|---|-------------|-------------|-------------|
| 11 | pi1-bastion | TBD | 192.168.1.10 |
| 12 | pi2-dns | TBD | 192.168.1.11 |
| 13 | pi3-bastion-backup | TBD | 192.168.1.12 |
| 14 | pi4-dns-backup | TBD | 192.168.1.13 |

## New Router Configuration Checklist

For AXE7800 (new router):

1. **Change LAN Settings:**
   - LAN IP: 192.168.0.1 → **192.168.1.1**
   - DHCP Pool: 192.168.0.100-253 → **192.168.1.100-199**

2. **Copy all 10 existing DHCP reservations** (see table above)

3. **Add 4 Pi DHCP reservations** once MAC addresses are known

4. **Configure port forwarding:**
   - External 4222 → 192.168.1.10:22 (SSH bastion)

5. **Configure DHCP DNS (later, after Pi 2 deployed):**
   - Primary DNS: 192.168.1.11 (Pi 2 CoreDNS)

## Verification

Compare this document against screenshots:
- reference/old-router-dhcp-page-1.png
- reference/old-router-dhcp-page-2.png
