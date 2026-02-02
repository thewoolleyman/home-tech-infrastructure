# Raspberry Pi Image Setup Guide

How to flash a fresh microSD card with Raspberry Pi OS and boot a Pi for this project.

## Prerequisites

- Raspberry Pi (any model with ethernet -- Pi 3B+, Pi 4, Pi 5)
- microSD card (16GB+ recommended)
- microSD card reader/adapter for your computer
- Ethernet cable connected to your router
- Power supply for the Pi

## Pi Roles

| Pi | Hostname | IP (static, set later) | Role |
|----|----------|------------------------|------|
| 1 | bastion | 192.168.1.10 | SSH jump host + DDNS |
| 2 | dns | 192.168.1.11 | CoreDNS split-horizon |
| 3 | bastion-backup | 192.168.1.12 | Hot backup bastion |
| 4 | dns-backup | 192.168.1.13 | Hot backup DNS |

Set up Pi 1 (bastion) first -- it is the jump host all other Pis connect through.

## Step 1: Install Raspberry Pi Imager

On macOS:

```bash
brew install --cask raspberry-pi-imager
```

Or download from: https://www.raspberrypi.com/software/

## Step 2: Flash the microSD Card

1. Insert the **blank** microSD card into your Mac (via adapter if needed).
2. Open **Raspberry Pi Imager** (`/Applications/Raspberry Pi Imager.app`).
3. **Choose Device** -- select your Pi model (e.g. Raspberry Pi 4).
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
| Wireless LAN | Leave unchecked (Pis use ethernet) |
| Locale | Your timezone (e.g. `America/Los_Angeles`) |

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
3. Connect an ethernet cable between the Pi and your router.
4. Connect the power supply. The Pi will boot automatically.
5. Wait ~60-90 seconds for the first boot to complete (the Pi resizes the filesystem and reboots once).

## Step 4: Find the Pi on Your Network

The Pi will get an IP via DHCP. Find it using one of these methods:

### Option A: Scan for Raspberry Pi MAC addresses

```bash
# Raspberry Pi Foundation MAC prefixes
arp -a | grep -iE "b8:27:eb|dc:a6:32|e4:5f:01|d8:3a:dd|28:cd:c1|2c:cf:67"
```

### Option B: Try mDNS / Bonjour

```bash
ping bastion.local
```

(Replace `bastion` with whatever hostname you set in Step 2.)

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

# Check network
ip addr show eth0

# Check disk space
df -h /
```

## Step 6: Set a Static IP (Before Running Deploy Scripts)

Once you know the Pi boots and is reachable, assign it a static IP matching the inventory. Edit the Pi's DHCP client config:

```bash
sudo nmcli con mod "Wired connection 1" \
  ipv4.addresses 192.168.1.10/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "1.1.1.1 9.9.9.9" \
  ipv4.method manual

sudo nmcli con up "Wired connection 1"
```

> Replace `192.168.1.10` with the correct IP for this Pi's role (see table above).

After this, reconnect via the new static IP:

```bash
ssh deploy@192.168.1.10
```

## Step 7: Deploy

From your **Mac** (not the Pi), run the deploy scripts:

```bash
make deploy-pi ROLE=bastion TARGET=192.168.1.10
```

> This target is not yet implemented (Epic 5). For now, you can manually copy and run scripts. See the Makefile for available targets: `make help`.

## Repeating for Additional Pis

Follow the same steps for each Pi, changing:
- **Hostname** (Step 2) -- use the hostname from the table
- **Static IP** (Step 6) -- use the IP from the table
- **ROLE** (Step 7) -- use `bastion` or `dns` as appropriate

## Troubleshooting

**Can't find the Pi on the network:**
- Verify the ethernet cable is connected and the router port has link activity
- Wait 90+ seconds -- first boot takes time
- Try a different ethernet port on the router
- Re-flash the SD card if the Pi never appears

**SSH connection refused:**
- Verify SSH was enabled in the Imager settings (Step 2)
- Re-flash with SSH enabled if missed

**Wrong hostname:**
- Re-flash the SD card -- it's faster than debugging

**NOOBS card from CanaKit:**
- Store the original NOOBS card safely. You don't need it.
- NOOBS is discontinued. Always use Raspberry Pi Imager for new installs.
