# GCP Infrastructure Lab: Global Application Load Balancer with Regional MIG and Cloud Armor

![GCP](https://img.shields.io/badge/Google_Cloud-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)

Comprehensive Infrastructure as Code (IaC) deployment of a production-ready, highly available architecture in **Google Cloud Platform (GCP)** using **Terraform**. This project demonstrates Layer 7 Load Balancing, Multi-zone Regional Managed Instance Groups (MIG), Auto-healing, Autoscaling, and Web Application Firewall (WAF) integration with Cloud Armor.

---

## 📐 Architecture Overview

The deployed infrastructure enforces security, high availability, and zero-downtime scaling:

```
[ Internet Client / Anycast IP ]
               │
               ▼
   [ Global Forwarding Rule ] (TCP : 80)
               │
               ▼
     [ Target HTTP Proxy ]
               │
               ▼
         [ URL Map ]
               │
               ▼
     [ Backend Service ] ◄─────── [ Cloud Armor Security Policy ] (WAF)
               │
   ┌───────────┴───────────┐
   ▼                       ▼
[ Proxy-Only Subnet ] [ Proxy-Only Subnet ]
 (us-central1-a)        (us-central1-b)
   │                       │
   └───────────┬───────────┘
               ▼
┌──────────────────────────────────────────────────────────┐
│ Regional Managed Instance Group (MIG)                    │
│                                                          │
│  ┌───────────────────────┐   ┌───────────────────────┐   │
│  │ VM Instance (Zone A)  │   │ VM Instance (Zone B)  │   │
│  │ Subnet: 10.0.1.0/24   │   │ Subnet: 10.0.2.0/24   │   │
│  └───────────────────────┘   └───────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

---

## 🔑 Key Engineering & Architectural Decisions

### 1. Dedicated Proxy-Only Subnet (`REGIONAL_MANAGED_PROXY`)
* **Purpose:** External Application Load Balancers in GCP use Envoys running behind the scenes. They require a dedicated proxy-only subnet (`10.129.0.0/23`) with purpose set to `REGIONAL_MANAGED_PROXY`.
* **Firewall Isolation:** Explicit rules allow ingress HTTP traffic specifically from the proxy subnet to backend VMs on port 80.

### 2. Auto-Healing & Boot-up Delay Prevention
* **Mitigating Boot Loops:** To avoid "death loops" where fresh instances are prematurely killed during Nginx/startup script execution, the Auto-healing policy defines an `initial_delay_sec = 180`.
* **Health Check Source Ranges:** Dedicated ingress firewall rules explicitly permit probes from GCP Health Check ranges (`130.211.0.0/22` and `35.191.0.0/16`).

### 3. Immutable Instance Templates & Zero-Downtime Updates
* **Lifecycle Management:** Utilizes `name_prefix` and `create_before_destroy = true` within the instance template to ensure updates to VM configurations happen seamlessly without service interruption.

### 4. Edge Security with Cloud Armor (WAF)
* Attaches a Layer 7 Security Policy directly to the **Backend Service**, implementing custom IP blocking rules and a default fallback allow rule.

---

## 🛠️ Verification & Traffic Testing

The Application Load Balancer distributes incoming requests evenly between zones `us-central1-a` and `us-central1-b`.

Executing an automated loop against the Anycast Public IP verifies active load balancing across instances:

```bash
while true; do
  curl -s http://<LB_PUBLIC_IP>/ | grep 'class="value"' | sed 's/<[^>]*>//g' | tr '\n' ' '
  echo ""
  sleep 1
done
```

**Output:**
```text
web-srv-xvvx   us-central1-a   10.0.1.2   e2-micro
web-srv-fn9c   us-central1-b   10.0.1.3   e2-micro
web-srv-xvvx   us-central1-a   10.0.1.2   e2-micro
web-srv-fn9c   us-central1-b   10.0.1.3   e2-micro
```

---

## 💻 Deployment Commands

```bash
# Initialize provider & modules
terraform init

# Validate configuration syntax
terraform validate

# Review execution plan
terraform plan

# Apply infrastructure deployment
terraform apply -auto-approve
```

---

## 🧪 Real-World Troubleshooting Log

* **API Attribute Patch Restrictions:** Updating a subnet's `purpose` attribute after initial provisioning returns an API HTTP 400 error. Recreated the resource safely using targeted replacement:
  ```bash
  terraform apply -replace="google_compute_subnetwork.subnet_proxy"
  ```
* **Cloud Shell Connectivity Drops:** Addressed transient API connection timeouts (`dial tcp ... connect: connection refused`) by verifying network state and re-running `terraform apply`.

---

## 📜 Certification Alignment
Designed as part of hands-on preparation for the **Google Cloud Professional Cloud Network Engineer** certification, demonstrating real-world IaC implementation of VPCs, MIGs, Health Checking, Load Balancing, and Edge Security.
