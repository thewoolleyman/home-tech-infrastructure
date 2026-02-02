# Raspberry Pi Image Setup Guide

How to flash a fresh microSD card with Raspberry Pi OS and boot a Pi for this project.

## Prerequisites

- Raspberry Pi Zero 2 W
- microSD card (16GB+ recommended)
- microSD card reader/adapter for your computer
- USB power supply (micro-USB)
- WiFi network credentials
- (Optional) mini-HDMI cable + USB OTG adapter + keyboard for debugging

## Pi Roles

| Pi | Hostname | IP (static, set later) | Role |
|----|----------|------------------------|------|
| 1 | bastion | 192.168.1.10 | SSH jump host + DDNS |
| 2 | dns | 192.168.1.11 | CoreDNS split-horizon |
| 3 | bastion-backup | 192.168.1.12 | Hot backup bastion |
| 4 | dns-backup | 192.168.1.13 | Hot backup DNS |

Set up Pi 1 (bastion) first -- it is the jump host all other Pis connect through.

## Network Setup

The target network uses SSID `FBI_SURVEILLANCE_VAN` on a TP-Link Archer AXE95 router.

The Xfinity XB8 modem is in **bridge mode** (enabled 2026-02-01), passing the real public IP directly to the router. No double NAT.

During the transition you may need the Pi on multiple networks:

| Network | SSID | Status | Purpose |
|---------|------|--------|---------|
| Current production | `TP-Link_8500` / `TP-Link_8500_5G` | Active | Archer C2300 (temporary router) |
| Target | `FBI_SURVEILLANCE_VAN` | Not yet deployed | Archer AXE95 (final router) |
| Old (disabled) | `Big Bopper Bang` / `The Big Bopper` | Disabled | XB8 WiFi (off in bridge mode) |

Configure the **current production** SSID (`TP-Link_8500_5G`) to get the Pi online, then switch to `FBI_SURVEILLANCE_VAN` when the Archer AXE95 is deployed.

## Step 1: Install Raspberry Pi Imager

On macOS:

```bash
brew install --cask raspberry-pi-imager
```

Or download from: https://www.raspberrypi.com/software/

## Step 2: Flash the microSD Card

1. Insert the **blank** microSD card into your Mac (via adapter if needed).
2. Open **Raspberry Pi Imager** (`/Applications/Raspberry Pi Imager.app`).
3. **Choose Device** -- select **Raspberry Pi Zero 2 W**.
4. **Choose OS** -> **Raspberry Pi OS (other)** -> **Raspberry Pi OS Lite (64-bit)**.
   - This is the headless server image (Debian Bookworm, no desktop).
5. **Choose Storage** -- select your microSD card.
6. Click **Next**. When prompted to customize, click **Edit Settings**.

### OS Customization Settings

In the **General** tab:

| Setting | Value |
|---------|-------|
| Hostname | The Pi's hostname from the table above (e.g. `bastion`) |
| Username | `deploy` |
| Password | A temporary password (will be replaced by key-only SSH) |
| Configure wireless LAN | **Yes** -- see below |
| SSID | `TP-Link_8500_5G` (current production) or `FBI_SURVEILLANCE_VAN` (target, not yet active) |
| Password | Your WiFi password |
| Wireless LAN country | `US` |
| Locale | Your timezone (e.g. `America/Los_Angeles`) |

> Use `TP-Link_8500_5G` (current production on C2300). The old XB8 SSIDs are disabled. Switch to `FBI_SURVEILLANCE_VAN` when AXE95 is deployed (see Step 6).

In the **Services** tab:

| Setting | Value |
|---------|-------|
| Enable SSH | Yes |
| Authentication | Use password authentication |

> Password auth is temporary. Our `harden.sh` script will disable it and switch to key-only SSH after deploy.

7. Click **Save**, then **Yes** to apply customization, then **Yes** to confirm writing.
8. Wait for the write + verification to complete.
9. Eject the card.

## Step 3: Boot the Pi

1. Remove any existing SD card from the Pi. Store old cards safely.
2. Insert the freshly flashed microSD card.
3. Connect the power supply (micro-USB port labeled **PWR**). The Pi will boot automatically.
4. Wait ~60-90 seconds for the first boot to complete (the Pi resizes the filesystem and reboots once).

> No ethernet cable needed -- the Zero 2 W connects via WiFi configured in Step 2.

## Step 4: Find the Pi on Your Network

The Pi will get an IP via DHCP over WiFi. Find it using one of these methods:

### Option A: Try mDNS / Bonjour

```bash
ping bastion.local
```

(Replace `bastion` with whatever hostname you set in Step 2.)

### Option B: Scan for Raspberry Pi MAC addresses

```bash
# Raspberry Pi Foundation MAC prefixes
arp -a | grep -iE "b8:27:eb|dc:a6:32|e4:5f:01|d8:3a:dd|28:cd:c1|2c:cf:67"
```

### Option C: Check your router

Visit http://192.168.1.1 (or your router's admin page) and look for the Pi in the DHCP client list.

### Option D: Network scan

```bash
# Scan the local subnet for SSH
nmap -p 22 192.168.1.0/24 --open
```

## Step 5: SSH In

```bash
ssh deploy@<pi-ip>
```

Accept the host key fingerprint when prompted. Enter the temporary password you set in Step 2.

### Verify the Pi is working

```bash
# Check hostname
hostname

# Check OS
cat /etc/os-release

# Check WiFi connection
ip addr show wlan0

# Check which SSID you're connected to
nmcli -t -f active,ssid dev wifi | grep '^yes'

# Check disk space
df -h /
```

## Step 6: Configure WiFi Networks

The Pi should already be connected to the SSID you configured in Step 2. To add the other network (so the Pi can switch between old and new routers):

### Add the new network (if you started on the old one)

```bash
sudo nmcli device wifi connect "FBI_SURVEILLANCE_VAN" password "NEW_WIFI_PASSWORD"
```

### Add the old network (if you started on the new one)

```bash
sudo nmcli device wifi connect "TP-Link_8500_5G" password "OLD_WIFI_PASSWORD"
```

### Set network priority (prefer the new network when both are available)

```bash
# Higher priority = preferred
sudo nmcli connection modify "FBI_SURVEILLANCE_VAN" connection.autoconnect-priority 10
sudo nmcli connection modify "TP-Link_8500_5G" connection.autoconnect-priority 5
```

### Switch between networks manually

```bash
# Switch to the new network
sudo nmcli connection up "FBI_SURVEILLANCE_VAN"

# Switch to the old network
sudo nmcli connection up "TP-Link_8500_5G"

# Check current connection
nmcli -t -f active,ssid dev wifi | grep '^yes'
```

## Step 7: Set a Static IP

Once the Pi is on the correct network, assign a static IP matching the inventory.

### On the new network (FBI_SURVEILLANCE_VAN) -- target config

```bash
sudo nmcli con mod "FBI_SURVEILLANCE_VAN" \
  ipv4.addresses 192.168.1.10/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "1.1.1.1 9.9.9.9" \
  ipv4.method manual

sudo nmcli con up "FBI_SURVEILLANCE_VAN"
```

### On the old network (TP-Link_8500_5G) -- temporary during transition

```bash
sudo nmcli con mod "TP-Link_8500_5G" \
  ipv4.addresses 192.168.1.10/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "1.1.1.1 9.9.9.9" \
  ipv4.method manual

sudo nmcli con up "TP-Link_8500_5G"
```

> Replace `192.168.1.10` with the correct IP for this Pi's role (see table above).

After setting the static IP, reconnect via the new address:

```bash
ssh deploy@192.168.1.10
```

## Step 8: Deploy

From your **Mac** (not the Pi), run the deploy scripts:

```bash
make deploy-pi ROLE=bastion TARGET=192.168.1.10
```

> This target is not yet implemented (Epic 5). For now, you can manually copy and run scripts. See the Makefile for available targets: `make help`.

## Repeating for Additional Pis

Follow the same steps for each Pi, changing:
- **Hostname** (Step 2) -- use the hostname from the table
- **Static IP** (Step 7) -- use the IP from the table
- **ROLE** (Step 8) -- use `bastion` or `dns` as appropriate

## Cutover: Switching from Old Router to New Router

When the Archer AXE95 is ready to go live:

1. Verify all Pis have both SSIDs configured (Step 6 above)
2. Set priority so the new SSID is preferred (already done in Step 6)
3. Power on the Archer AXE95 and configure it with the same subnet (192.168.1.0/24)
4. Power off the old router
5. Pis will automatically reconnect to `FBI_SURVEILLANCE_VAN`
6. Verify each Pi: `ssh deploy@192.168.1.10` (and .11, .12, .13)

## Troubleshooting

**Can't find the Pi on the network:**
- Verify WiFi credentials were entered correctly in Step 2
- Wait 90+ seconds -- first boot takes time
- Connect a mini-HDMI monitor + USB keyboard to check boot messages
- Re-flash the SD card if the Pi never appears

**WiFi won't connect:**
- Check that the SSID and password are exact (case-sensitive)
- Verify your router is broadcasting on a channel the Zero 2 W supports (2.4GHz and 5GHz)
- Run `sudo nmcli device wifi list` on the Pi to see visible networks

**SSH connection refused:**
- Verify SSH was enabled in the Imager settings (Step 2)
- Re-flash with SSH enabled if missed

**Wrong hostname:**
- Re-flash the SD card -- it's faster than debugging

**WiFi drops or reconnects slowly:**
- NetworkManager handles reconnection automatically
- For persistent issues, consider adding a watchdog cron job that restarts wlan0

**NOOBS card from CanaKit:**
- Store the original NOOBS card safely. You don't need it.
- NOOBS is discontinued. Always use Raspberry Pi Imager for new installs.
