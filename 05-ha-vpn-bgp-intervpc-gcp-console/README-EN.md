🇺🇸 English Version

# Lab 05: GCP HA VPN & Dynamic BGP Routing (Console Deployment)

This lab demonstrates the interconnection of two distinct VPC networks within Google Cloud Platform (GCP) using a High Availability **HA VPN** setup with **dynamic BGP routing** and **ECMP (Equal-Cost Multi-Path)** load balancing.

Unlike automated Infrastructure-as-Code (IaC) deployments, this architecture was manually configured using the **GCP Console**. The goal was to validate cloud networking patterns, gain hands-on experience troubleshooting BGP sessions in real time, and demonstrate proficiency with the GCP web interface.

---

## 📐 System Architecture

The topology simulates the interconnection between a production cloud network (`vpc-gcp-production`) and a simulated On-Premises data center (`vpc-onprem-simulated`).

* **GCP VPC (Production):**
  * **Regions:** `us-central1` (Iowa) and `us-west1` (Oregon)
  * **Cloud Router:** `cr-gcp-us-central1` (ASN: `65001`)
  * **HA VPN Gateway:** `vpngw-gcp-us-central1` (Dual-homed: Interface 0 and Interface 1)
  * **Test VM:** `vm-gcp-us-central1-01` (`10.1.10.2`)

* **On-Prem VPC (Simulated):**
  * **Regions:** `us-central1` (Iowa) and `us-west1` (Oregon)
  * **Cloud Router:** `cr-onprem-us-central1` (ASN: `65002`)
  * **HA VPN Gateway:** `vpngw-onprem-us-central1` (Dual-homed: Interface 0 and Interface 1)
  * **Test VM:** `vm-onprem-us-central1-01` (`10.2.10.2`)

* **Routing and Redundancy:**
  * **BGP Scheme:** Active/Active (ECMP)
  * **BGP Priority (MED):** `100` configured across all 4 tunnels.

---

## 🖥️ Test Instances (Compute Engine)

To validate end-to-end private connectivity, `e2-micro` virtual machines were deployed inside the subnets of each VPC:

![VM Instances](images/gcp-vms-instances-list.png)

* **`vm-gcp-us-central1-01`**: Private IP `10.1.10.2` (GCP Prod VPC)
* **`vm-onprem-us-central1-01`**: Private IP `10.2.10.2` (On-Prem Simulated VPC)

---

## 🛠️ Key Troubleshooting: Manual `/30` BGP Subnet Alignment

During initial creation in the console, **automatic assignment** was selected for the BGP Link-Local IP addresses (`169.254.x.x`).

### The Problem:
GCP automatically generated independent `/30` subnets on each end, causing the Cloud Routers to attempt establishing BGP sessions against mismatched IP addresses:

* **Tunnel 0 (`if0`):** GCP sent packets to `.116.78`, while On-Prem listened on `.254.217`.
* **Tunnel 1 (`if1`):** GCP sent packets to `.170.2`, while On-Prem listened on `.139.9`.

This resulted in all BGP sessions staying in an **Inactive** state.

### The Solution:
Because the console does not allow inline editing of automatically assigned BGP IPs on an existing session, the BGP Link-Local pairs were manually recreated across matching `/30` subnets:

* **Tunnel 0 (`if0`):**
  * GCP Router: `169.254.116.77/30` | Peer: `169.254.116.78`
  * On-Prem Router: `169.254.116.78/30` | Peer: `169.254.116.77`
* **Tunnel 1 (`if1`):**
  * GCP Router: `169.254.139.10/30` | Peer: `169.254.139.9`
  * On-Prem Router: `169.254.139.9/30` | Peer: `169.254.139.10`

---

## ✅ Results and Evidence

### 1. BGP Session Status (Established/Active)
Once the Link-Local `/30` subnets were aligned, all 4 BGP sessions transitioned to an **Active (Green)** state immediately:

![BGP Session Status](images/bgp-sessions-established.png)

### 2. Connectivity Validation (Bidirectional ICMP Ping)
Private ICMP traffic exchange between instances in both VPCs was verified across the encrypted IPsec tunnels:

![Bidirectional Ping Test](images/icmp-ping-validation.png)

* **GCP Prod → On-Prem Test:**
  `ping 10.2.10.2` executed from `vm-gcp-us-central1-01` with **0% packet loss** and an average latency of ~1.9 ms.
* **On-Prem → GCP Prod Test:**
  `ping 10.1.10.2` executed from `vm-onprem-us-central1-01` with **0% packet loss** and an average latency of ~2.1 ms.

---

## 🔍 Verification Commands (Google Cloud CLI)

To verify the status of the tunnels and BGP sessions using Cloud Shell CLI:

```bash
# List and verify the operational status of the VPN tunnels
fertriana21@cloudshell:~ (cl-demo-learn-507500)$ gcloud compute vpn-tunnels list
NAME: vpn-tnl-gcp-to-onprem-if0
REGION: us-central1
GATEWAY: vpngw-gcp-us-central1
PEER_ADDRESS: 34.128.33.228

NAME: vpn-tnl-gcp-to-onprem-if1
REGION: us-central1
GATEWAY: vpngw-gcp-us-central1
PEER_ADDRESS: 34.184.42.180

NAME: vpn-tnl-onprem-to-gcp-if0
REGION: us-central1
GATEWAY: vpngw-on-prem-us-central1
PEER_ADDRESS: 35.242.112.249

NAME: vpn-tnl-onprem-to-gcp-if1
REGION: us-central1
GATEWAY: vpngw-on-prem-us-central1
PEER_ADDRESS: 34.157.235.253



# Inspect BGP learned routes and session details on the GCP Cloud Router
fertriana21@cloudshell:~ (cl-demo-learn-507500)$ gcloud compute routers describe cr-gcp-us-central1 \
    --region=us-central1 \
    --format="yaml(bgpPeers, status)"
bgpPeers:
- advertiseMode: DEFAULT
  advertisedRoutePriority: 100
  bfd:
    minReceiveInterval: 1000
    minTransmitInterval: 1000
    multiplier: 5
    sessionInitializationMode: DISABLED
  enable: 'TRUE'
  enableIpv4: true
  enableIpv6: false
  interfaceName: if-bgp-sess-gcp-to-onprem-if0
  ipAddress: 169.254.116.77
  name: bgp-sess-gcp-to-onprem-if0
  peerAsn: 65002
  peerIpAddress: 169.254.116.78
- advertiseMode: DEFAULT
  advertisedRoutePriority: 100
  bfd:
    minReceiveInterval: 1000
    minTransmitInterval: 1000
    multiplier: 5
    sessionInitializationMode: DISABLED
  enable: 'TRUE'
  enableIpv4: true
  enableIpv6: false
  interfaceName: if-bgp-sess-gcp-to-onprem-if1
  ipAddress: 169.254.139.10
  name: bgp-sess-gcp-to-onprem-if1
  peerAsn: 65002
  peerIpAddress: 169.254.139.9
