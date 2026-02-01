# Home Infrastructure Architecture

## Network Topology

```mermaid
graph TD
    subgraph Internet
        ISP["Internet (Xfinity Cable)"]
        NAMECHEAP["Namecheap DNS<br/>mindlikewater.net<br/>Only record: bastion A (DDNS)"]
    end

    subgraph Edge["Edge - Modem (Zero Config After Bridge Toggle)"]
        MODEM["Xfinity Modem/Gateway<br/>BRIDGE MODE<br/>Pass-through only<br/>No NAT, No DHCP, No WiFi"]
    end

    subgraph Network["Internal Network - 192.168.1.0/24"]
        ROUTER["router.mindlikewater.net<br/>Archer AXE95 / AXE7800 - 192.168.1.1<br/>PRIMARY ROUTER: NAT + Firewall + DHCP + WiFi<br/>Gets real public IP via bridge mode<br/>Port forward: ext :4222 → Pi 1 :22<br/>DHCP DNS: point clients to Pi 2 (.11)<br/>Managed via Python TP-Link API from Pi 2"]

        subgraph PiServices["Raspberry Pi Fleet (2 devices)"]
            PI_BASTION["Pi 1 - BASTION + DDNS<br/>bastion.mindlikewater.net<br/>192.168.1.10<br/>───────────────<br/>SSH jump box (key-only, no passwords)<br/>DDNS cron: curl Namecheap API every 5 min<br/>Hardened: minimal Debian, unattended-upgrades<br/>No other services"]
            PI_DNS["Pi 2 - DNS + INFRA MGMT<br/>dns.mindlikewater.net<br/>192.168.1.11<br/>───────────────<br/>CoreDNS: split-horizon for mindlikewater.net<br/>Upstream: Cloudflare 1.1.1.1 / Quad9 9.9.9.9<br/>Router mgmt scripts (Python TP-Link API)<br/>Scripts sourced from git repo"]
        end

        subgraph Server["Dell PowerEdge R630 - 192.168.1.200<br/>poweredge.mindlikewater.net<br/>192GB RAM / 36 cores / 3x 800GB SSD"]
            TALOS["Talos Linux<br/>Immutable OS<br/>API-managed via talosctl<br/>No SSH"]
            K8S["Single-Node Kubernetes<br/>k8s.mindlikewater.net<br/>allowSchedulingOnControlPlanes: true"]

            subgraph K8sWorkloads["K8s Workloads (all FluxCD-managed)"]
                FLUX["FluxCD<br/>GitOps Controller<br/>Source: Git repo<br/>SOPS decryption enabled"]
                SOPS_SECRET["SOPS + age<br/>In-cluster Secret<br/>(bootstrap: manual)"]
                CERTMGR["cert-manager<br/>Self-signed CA<br/>Auto-issues TLS certs"]
                GITLAB["GitLab Omnibus Container<br/>gitlab.mindlikewater.net<br/>(not Helm chart)<br/>Git + CI/CD + Registry"]
                AI["AI Agentic Workloads<br/>Programmatic K8s access"]
                INGRESS["Ingress Controller<br/>(Traefik or nginx)"]
                METALLB["MetalLB<br/>LB IPs: .220-.239"]
            end
        end

        subgraph Clients["Client Devices"]
            WORK_MAC["Work MacBook<br/>.2 wired / .52 wifi"]
            PERSONAL_MAC["Personal MacBook<br/>.7 wired / .57 wifi"]
            GEEKOM["GeekOM Mini PC<br/>.3 wired / .53 wifi"]
            HP["Windows HP<br/>.4 wired / .54 wifi"]
        end
    end

    ISP -->|WAN| MODEM
    MODEM -->|"Ethernet (public IP pass-through)"| ROUTER

    ROUTER -->|LAN| PI_BASTION
    ROUTER -->|LAN| PI_DNS
    ROUTER -->|LAN| TALOS
    ROUTER -->|LAN / WiFi| WORK_MAC
    ROUTER -->|LAN / WiFi| PERSONAL_MAC
    ROUTER -->|LAN / WiFi| GEEKOM
    ROUTER -->|LAN / WiFi| HP

    ROUTER -.->|"Port forward<br/>ext :4222 → .10 :22"| PI_BASTION

    PI_BASTION -.->|"DDNS cron<br/>curl → Namecheap API"| NAMECHEAP
    PI_DNS -.->|"Upstream DNS<br/>(non-mindlikewater.net)"| ROUTER

    TALOS --> K8S
    K8S --> FLUX
    K8S --> SOPS_SECRET
    K8S --> CERTMGR
    K8S --> GITLAB
    K8S --> AI
    K8S --> INGRESS
    K8S --> METALLB
    FLUX -->|"Reconcile from Git"| GITLAB

    ROUTER -.->|"DHCP: DNS server = .11"| PI_DNS

    style MODEM fill:#999,stroke:#333,stroke-width:1px,color:#fff
    style ROUTER fill:#0a8,stroke:#333,stroke-width:2px,color:#fff
    style PI_BASTION fill:#f96,stroke:#333,stroke-width:2px
    style PI_DNS fill:#69f,stroke:#333,stroke-width:2px
    style TALOS fill:#6c6,stroke:#333,stroke-width:2px
    style K8S fill:#6c6,stroke:#333,stroke-width:1px
    style GITLAB fill:#e44,stroke:#333,stroke-width:2px,color:#fff
    style FLUX fill:#96f,stroke:#333,stroke-width:2px,color:#fff
    style AI fill:#fc6,stroke:#333,stroke-width:2px
    style CERTMGR fill:#0aa,stroke:#333,stroke-width:1px,color:#fff
    style INGRESS fill:#888,stroke:#333,stroke-width:1px,color:#fff
    style METALLB fill:#888,stroke:#333,stroke-width:1px,color:#fff
    style SOPS_SECRET fill:#888,stroke:#333,stroke-width:1px,color:#fff
```

## Remote Access Flow (SOCKS Proxy via Bastion)

```mermaid
sequenceDiagram
    participant User as Remote User<br/>(off-network)
    participant PubDNS as Namecheap DNS
    participant Modem as Xfinity Modem<br/>(Bridge)
    participant Router as Archer AXE95
    participant Bastion as Pi 1 - Bastion<br/>.10
    participant PiDNS as Pi 2 - DNS<br/>.11
    participant Server as PowerEdge<br/>.200

    Note over User: Step 1: Connect SOCKS proxy
    User->>PubDNS: dig bastion.mindlikewater.net
    PubDNS-->>User: Dynamic public IP

    User->>Modem: ssh -D 1080 user@bastion.mindlikewater.net -p 4222
    Modem->>Router: Pass-through (bridge mode)
    Router->>Bastion: Port forward :4222 → .10:22
    Bastion-->>User: SSH session + SOCKS5 proxy on localhost:1080

    Note over User: Step 2: Browse via SOCKS proxy (remote DNS enabled)
    User->>Bastion: Browser → SOCKS5 → DNS query: gitlab.mindlikewater.net
    Bastion->>PiDNS: DNS lookup (forwarded through LAN)
    PiDNS-->>Bastion: 192.168.1.200 (split-horizon, internal record)
    Bastion->>Server: HTTPS to 192.168.1.200:443
    Server-->>User: GitLab UI (cert matches gitlab.mindlikewater.net)
```

## LAN Access Flow (Direct)

```mermaid
sequenceDiagram
    participant Mac as Work MacBook<br/>(on LAN)
    participant PiDNS as Pi 2 - DNS<br/>.11
    participant Server as PowerEdge<br/>.200

    Mac->>PiDNS: DNS query: gitlab.mindlikewater.net
    PiDNS-->>Mac: 192.168.1.200 (local zone record)
    Mac->>Server: HTTPS direct to 192.168.1.200:443
    Server-->>Mac: GitLab UI (cert matches gitlab.mindlikewater.net)
```

## DDNS Update Flow

```mermaid
sequenceDiagram
    participant Cron as Pi 1 cron (every 5 min)
    participant Detect as ifconfig.io
    participant NC as Namecheap DDNS API

    Cron->>Detect: curl -s ifconfig.io
    Detect-->>Cron: Current public IP (seen after NAT)

    alt IP changed since last check
        Cron->>NC: GET /update?host=bastion&domain=mindlikewater.net&password=***&ip=NEW_IP
        NC-->>Cron: XML response (OK)
        Note over Cron: Log: IP updated to NEW_IP
    else IP unchanged
        Note over Cron: No-op, skip API call
    end
```

## Split-Horizon DNS Configuration

```mermaid
flowchart TD
    subgraph PiDNS["Pi 2 - CoreDNS"]
        ZONE["Local Zone: mindlikewater.net<br/>(authoritative for LAN clients)"]
        FWD["Forwarder: everything else<br/>→ 1.1.1.1 / 9.9.9.9"]
    end

    subgraph Namecheap["Namecheap Public DNS"]
        PUB["Public Zone: mindlikewater.net<br/>Only record: bastion A (DDNS)"]
    end

    LAN_CLIENT["LAN Client"] -->|"gitlab.mindlikewater.net?"| ZONE
    ZONE -->|"192.168.1.200"| LAN_CLIENT

    LAN_CLIENT -->|"google.com?"| FWD
    FWD -->|"Forward upstream"| UPSTREAM["1.1.1.1"]
    UPSTREAM -->|response| FWD
    FWD -->|response| LAN_CLIENT

    EXT_CLIENT["External Client"] -->|"gitlab.mindlikewater.net?"| PUB
    PUB -->|"NXDOMAIN (no record)"| EXT_CLIENT

    EXT_CLIENT -->|"bastion.mindlikewater.net?"| PUB
    PUB -->|"Dynamic public IP"| EXT_CLIENT

    style ZONE fill:#69f,stroke:#333,stroke-width:2px
    style FWD fill:#69f,stroke:#333,stroke-width:1px
    style PUB fill:#f90,stroke:#333,stroke-width:2px
```

## Router Management

```mermaid
flowchart LR
    SCRIPTS["Router Mgmt Scripts<br/>(Python, git repo)<br/>Runs on Pi 2"] -->|"TP-Link API<br/>(community package)"| ROUTER["Archer AXE95"]
    SCRIPTS -->|"Manage"| DHCP["DHCP Reservations<br/>+ DNS server = .11"]
    SCRIPTS -->|"Manage"| FWD["Port Forwarding<br/>ext :4222 → .10 :22"]
    SCRIPTS -->|"Manage"| WIFI["WiFi Networks<br/>(2.4G / 5G / 6G)"]
    SCRIPTS -->|"Monitor"| DEVICES["Connected Devices"]
```

## IP Address Scheme

| Range | Purpose | Hostnames |
|-------|---------|-----------|
| .1 | Router | router.mindlikewater.net |
| .2-.9 | Wired static clients | (no DNS names needed) |
| .10 | Pi 1 - Bastion + DDNS | bastion.mindlikewater.net |
| .11 | Pi 2 - DNS + Infra Mgmt | dns.mindlikewater.net |
| .12-.19 | Future Pis (hot backups) | *(reserved)* |
| .50-.59 | Wireless static clients | (no DNS names needed) |
| .100-.199 | DHCP dynamic range | *(auto-assigned)* |
| .200 | PowerEdge server | poweredge.mindlikewater.net |
| .201-.219 | Future servers | *(reserved)* |
| .220-.239 | MetalLB LoadBalancer pool | *(K8s assigns from pool)* |
| .240-.254 | Reserved | *(future use)* |

## DNS Records

### Pi DNS (CoreDNS) - Local Zone: mindlikewater.net

| Hostname | IP | Purpose |
|----------|----|---------|
| router.mindlikewater.net | 192.168.1.1 | Router admin |
| bastion.mindlikewater.net | 192.168.1.10 | Pi 1 (internal access) |
| dns.mindlikewater.net | 192.168.1.11 | Pi 2 (internal access) |
| poweredge.mindlikewater.net | 192.168.1.200 | Server direct access |
| k8s.mindlikewater.net | 192.168.1.200 | K8s API endpoint |
| gitlab.mindlikewater.net | 192.168.1.200 | GitLab (LAN + SOCKS tunnel) |

### Namecheap Public DNS - mindlikewater.net

| Record | Type | Value | Notes |
|--------|------|-------|-------|
| bastion | A (DDNS) | Dynamic public IP | Updated by Pi 1 cron |

*All other hostnames intentionally absent from public DNS.*

## TLS Certificates

```mermaid
flowchart TD
    CA["Self-Signed CA<br/>(key in SOPS-encrypted Secret)"]
    CM["cert-manager<br/>ClusterIssuer using CA"]
    CERT_GL["Certificate:<br/>gitlab.mindlikewater.net"]
    CERT_FUTURE["Future certs:<br/>*.mindlikewater.net"]

    CA --> CM
    CM -->|"Auto-issue"| CERT_GL
    CM -->|"Auto-issue"| CERT_FUTURE

    DEVICES["Client Devices:<br/>Install CA cert once<br/>(macOS Keychain, etc.)"]
    DEVICES -.->|"Trusts all certs<br/>issued by CA"| CERT_GL
```

## Architecture Decisions (All Resolved)

| # | Decision | Choice | Rationale |
|---|----------|--------|-----------|
| 1 | Xfinity modem mode | **Bridge** | Zero config after initial toggle. Router gets real public IP. No double NAT. |
| 2 | Primary router | **Archer AXE95** | Handles NAT, DHCP, firewall, WiFi. Programmable via Python TP-Link API. |
| 3 | Pi 1 role | **Bastion + DDNS** | DDNS is a cron job (zero attack surface). Both are edge concerns. |
| 4 | Pi 2 role | **DNS + Router Mgmt** | CoreDNS for split-horizon. Router scripts for infra-as-code. |
| 5 | DDNS placement | **Internal (on Pi 1)** | Namecheap API auto-detects IP via NAT. No WAN-side placement needed. |
| 6 | Bastion placement | **Inside router (on LAN)** | Router port-forwards SSH only. SSH key auth = bastion compromise requires breaking key auth regardless of placement. |
| 7 | DNS zone | **Single: mindlikewater.net** | Split-horizon: Pi DNS authoritative internally, Namecheap externally. No separate internal zone needed. |
| 8 | External access | **SOCKS proxy via bastion** | `ssh -D 1080` + browser with remote DNS. Single hostname works LAN and remote. |
| 9 | DNS software | **CoreDNS** | Lightweight, config-as-code, K8s-native style. No unnecessary extras. |
| 10 | Router management | **Python TP-Link API on Pi 2** | AXE95 v1.0 confirmed supported. Scripts in git, runs on always-on Pi. |
| 11 | MetalLB range | **.220-.239** | 20 IPs, plenty for single-node homelab. |
| 12 | TLS certificates | **Self-signed CA + cert-manager** | Automated cert issuance. CA cert installed on client devices once. |
| 13 | SSH external port | **Non-standard (4222)** | Reduces scanner noise. Not security-through-obscurity (key auth is the real gate). |
| 14 | Secrets management | **SOPS + age** | Git-committable encryption. 1Password backup for DR. FluxCD native integration. |

## Bootstrap Order

```mermaid
flowchart TD
    B1["1. Xfinity Modem → Bridge Mode<br/>(one-time manual toggle)"]
    B2["2. Archer AXE95 Setup<br/>Static IPs, DHCP range, port forward<br/>(Python scripts or initial manual)"]
    B3["3. Pi 1 - Bastion<br/>Harden OS, SSH key-only<br/>DDNS cron job"]
    B4["4. Pi 2 - DNS<br/>CoreDNS with mindlikewater.net zone<br/>Router mgmt scripts"]
    B5["5. PowerEdge - Talos Linux<br/>Boot ISO, apply machine config<br/>Verify kubectl access"]
    B6["6. FluxCD Bootstrap<br/>(from GitHub, migrate later)<br/>+ SOPS age secret (manual)"]
    B7["7. cert-manager + CA<br/>Self-signed CA, ClusterIssuer<br/>Install CA on client devices"]
    B8["8. GitLab Deployment<br/>Omnibus container via FluxCD<br/>gitlab.mindlikewater.net"]
    B9["9. AI Agentic Workloads<br/>Deploy via FluxCD"]
    B10["10. Migrate FluxCD source<br/>GitHub → self-hosted GitLab"]

    B1 --> B2 --> B3 --> B4 --> B5 --> B6 --> B7 --> B8 --> B9 --> B10

    style B1 fill:#999,stroke:#333,color:#fff
    style B2 fill:#0a8,stroke:#333,color:#fff
    style B3 fill:#f96,stroke:#333
    style B4 fill:#69f,stroke:#333
    style B5 fill:#6c6,stroke:#333
    style B6 fill:#96f,stroke:#333,color:#fff
    style B7 fill:#0aa,stroke:#333,color:#fff
    style B8 fill:#e44,stroke:#333,color:#fff
    style B9 fill:#fc6,stroke:#333
    style B10 fill:#96f,stroke:#333,color:#fff
```
