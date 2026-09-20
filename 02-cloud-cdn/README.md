# Lab 02: Global HTTP External Load Balancer + Cloud CDN with Storage Bucket

## 📌 Overview
This lab provisions a globally distributed static website architecture on Google Cloud Platform using Terraform. It leverages **Cloud Storage** as an origin backend, fronted by an **External HTTP Load Balancer** with **Cloud CDN** enabled to accelerate content delivery using Google's edge points of presence (PoPs).

## 📐 Architecture

[ Client Request ]
│
▼
[ Global External Forwarding Rule (Port 80) ]
│
▼
[ Target HTTP Proxy ]
│
▼
[ URL Map ]
│
▼
[ Backend Bucket + Cloud CDN Enabled ] ──(Cache Miss)──► [ Cloud Storage Bucket ]

## 🚀 Key Resources Provisioned
* **Cloud Storage Bucket**: Configured with public read access (`allUsers`) and web hosting attributes (`index.html`).
* **Backend Bucket**: Attach point connecting Cloud Storage to the Load Balancer with `CACHE_ALL_STATIC` policy.
* **Global IPv4 Address**: Static external IP address reserved for the Load Balancer entry point.
* **Global Forwarding Rule & Target HTTP Proxy**: Routing traffic from port 80 down to the backend map.

## 🛠️ Usage

### Prerequisites
* Terraform >= 1.0
* GCP Service Account with `roles/compute.networkAdmin` and `roles/storage.admin`.

### Steps
1. Initialize Terraform plugins:
   ```bash
   terraform init

   terraform plan

   terraform apply -auto-approve

🧪 Verification & Testing

   
Direct Origin Test: Visit bucket_direct_url output to verify file upload.

CDN Test: Query the load_balancer_ip output using curl -I http://<LOAD_BALANCER_IP> and inspect headers:

Look for Via: 1.1 google and Age: <seconds> to verify cache hits.

🧹 Cleanup
To avoid ongoing costs from the static global IP and Forwarding Rule:

Bash
terraform destroy -auto-approve
