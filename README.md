# 💼 BlueVault Finance – DevOps-Driven Microservices Deployment on Kubernetes (AWS)

BlueVault Finance is a microservices-based financial application designed and deployed using a fully automated DevOps pipeline. This project demonstrates how to build, containerize, and deploy multiple independent services to a Kubernetes cluster using best practices in Infrastructure as Code, CI/CD, and cloud-native architecture.

---

## 🚀 Project Modules (Microservices)

Each feature of the BlueVault Finance platform is built as an independent microservice (frontend + backend):

| Feature              | Frontend Repo                           | Backend Repo                           |
|---------------------|------------------------------------------|----------------------------------------|
| SIP Calculator       | [sip-fe](https://github.com/Surajmukhede/bluevault-sip-fe)      | [sip-be](https://github.com/Surajmukhede/bluevault-sip-be)   |
| EMI Calculator       | [emi-fe](https://github.com/Surajmukhede/bluevault-emi-fe)      | [emi-be](https://github.com/Surajmukhede/bluevault-emi-be)      |
| Home Page            | [homeloan-fe](https://github.com/Surajmukhede/bluevault-home)
| Loan Form            | [loan-form-fe](https://github.com/Surajmukhede/bluevault-loan-fe) | [loan-form-be](https://github.com/Surajmukhede/bluevault-loan-be)

Each microservice has:
- A separate GitHub repository
- Its own Dockerfile
- Its own Jenkins pipeline
- Kubernetes deployment and service YAMLs

---

## 🧠 How BlueVault Finance Works

- The **landing page** links to each calculator or form.
- When users click a module, they are routed via the **NGINX Ingress Controller** to the respective frontend.
- Frontends internally communicate with their backends using an NGINX **reverse proxy** inside containers.
- All services are deployed on a Kubernetes cluster running on **AWS EC2** instances.
- DNS is handled dynamically using **No-IP (bluevault.ddns.net)**.

---

## ⚙️ Infrastructure Overview

| Component         | Tool Used           | Description |
|------------------|---------------------|-------------|
| Infrastructure   | Terraform           | EC2 provisioning (1 Control Plane, 2 Workers, 1 Jenkins) |
| Configuration    | Ansible             | Automated installation of kubeadm, CRI-O, Jenkins, Docker |
| Cluster Setup    | Kubeadm             | Kubernetes setup with CRI-O runtime |
| CI/CD            | Jenkins             | Build & deployment pipelines |
| Containerization | Docker              | App packaging |
| DNS              | No-IP               | Dynamic domain (bluevault.ddns.net) |
| Routing          | NGINX + Ingress     | Path-based and reverse proxy routing |
| Monitoring       | kubectl             | Cluster control and rollout management |

---

## 🔄 CI/CD Pipeline Flow (Per Microservice)

Each microservice has its own Jenkins pipeline triggered via GitHub webhook:

1. **Webhook Trigger**: GitHub pushes trigger Jenkins (`http://jenkins.bluevault.in:8080/github-webhook/`)
2. **Clone Repo**: Jenkins clones the respective microservice repo
3. **Docker Build**: Builds and tags Docker image
4. **Push to Registry**: Docker image pushed to Docker Hub
5. **Deploy to K8s**: Jenkins runs `kubectl apply -f` to rollout updates
6. **Rolling Update**: Kubernetes performs rolling update with zero downtime

---
## ✅ Best Practices Followed

- ☑️ **Infrastructure as Code (IaC)** with Terraform
- ☑️ Automated configuration with **Ansible**
- ☑️ Clean separation of microservices (multi-repo pattern)
- ☑️ Secure SSH key-based access and subnet isolation
- ☑️ CI/CD pipelines are **declarative and version-controlled**
- ☑️ Used **.kube/config** automation for Jenkins-to-K8s access
- ☑️ Applied **rolling deployments** for zero downtime
- ☑️ Container runtime used: **CRI-O** (lightweight and Kubernetes-native)
- ☑️ **Ingress controller** routes traffic to frontend services
- ☑️ DNS managed dynamically using **No-IP + reverse proxy**

---
🔗 Useful Links

    No-IP Setup Guide

    Kubeadm Docs

    Terraform Docs

    Ansible Playbooks
---
🙋 About Me

## 🙋 About Me

I’m a DevOps Engineer passionate about automating infrastructure, building robust pipelines, and delivering scalable apps using cloud-native technologies.

🔗 [Let’s connect on LinkedIn](https://www.linkedin.com/in/suraj-mukhede-b72a74210/)
---
