# Lab 03: Private Compute Instance with Cloud NAT & IAP Access

## 📌 Overview
This lab demonstrates how to deploy a private Google Compute Engine (GCE) instance without a public IP address, securing remote access via **Identity-Aware Proxy (IAP)** and providing outbound internet connectivity through **Cloud NAT** and **Cloud Router**.

By removing public IP addresses from backend workloads, this pattern follows security best practices to reduce the attack surface against external threats.

---

## 🏗️ Architecture Diagram

```text
[ Internet ]
     ▲
     │ (Outbound Traffic Only)
[ Cloud NAT ]
     ▲
[ Cloud Router ]
     ▲
[ Private Subnet (10.0.1.0/24) ]
     └── VM: cl-vm-lab-dev-uc1a-01 (No Public IP)
             ▲
             │ (Inbound SSH Tunneling: 35.235.240.0/20)
[ Identity-Aware Proxy (IAP) ]

🚀 Key Features & Architectural Components
Custom VPC & Subnets: Created cl-vpc-lab-dev-01 with custom subnetwork ranges across multiple availability zones.

Private GCE Instance: Deployed an e2-micro Debian instance with no external IP assigned (access_config block omitted).

Identity-Aware Proxy (IAP) SSH Access: Restricted SSH ingress traffic (Port 22) exclusively to GCP's IAP proxy range (35.235.240.0/20) using network tags (allow-ssh).

Cloud Router & Cloud NAT: Implemented a managed Cloud NAT gateway (cl-nat-lab-dev-01) tied to a regional Cloud Router (cl-router-lab-dev-01) to allow private VMs to make outbound requests (e.g., package updates) without exposing them to inbound internet threats.

🛠️ Infrastructure Provisioning
Prerequisites
Google Cloud SDK (gcloud CLI) configured.

Terraform v1.0+ installed.

Active GCP project with Compute Engine APIs enabled.

Deployment Steps
Initialize Terraform:

terraform init
terraform plan
terraform apply

🧪 Verification & Testing
1. SSH into Private Instance via IAP
Connect to the instance using IAP tunneling since the VM lacks a public IP address:

gcloud compute ssh cl-vm-lab-dev-uc1a-01 \
    --zone=us-central1-a \
    --tunnel-through-iap

2. Verify Outbound Internet Access via Cloud NAT
Once connected inside the private VM, run a HTTP request to verify outbound access works through the NAT gateway:

curl -I [https://www.google.com](https://www.google.com)


Expected Result:

HTTP
HTTP/2 200
content-type: text/html; charset=ISO-8859-1
date: Sat, 26 Sep 2026 23:02:36 GMT
server: gws
...

🧹 Cleanup
To avoid incurring ongoing charges, destroy all created resources:

Bash
terraform destroy


