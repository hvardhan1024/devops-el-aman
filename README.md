# Blue-Green Deployment Demo

A complete CI/CD pipeline demonstrating blue-green deployment strategy using Jenkins, Docker, Kubernetes, and Ansible.

## 📁 Project Structure

```
devops-el/
├── docs/
│   ├── 01-EC2-JENKINS-SETUP.md    # AWS EC2 & Jenkins setup guide
│   └── 02-BLUE-GREEN-DEMO.md      # Blue-green deployment demo guide
├── backend-blue/                   # Blue (stable) version
│   ├── app.js
│   └── Dockerfile
├── backend-green/                  # Green (new) version
│   ├── app.js
│   └── Dockerfile
├── frontend/
│   ├── index.html                  # Dashboard with cache-busting
│   ├── Dockerfile
│   └── nginx.conf                  # No-cache nginx config
├── k8s/
│   ├── backend.yaml                # Backend deployments & service
│   └── frontend.yaml               # Frontend deployment & service
├── ansible/
│   ├── inventory.ini
│   ├── deploy-green.yaml           # Switch traffic to green
│   └── rollback-blue.yaml          # Rollback to blue
├── Jenkinsfile                     # CI pipeline
├── monitor.sh                      # Health check & auto-rollback
└── demo.sh                         # Quick setup script
```

## 🚀 Quick Start

### Prerequisites

- Docker
- Minikube
- kubectl
- Python 3 with venv
- Ansible

### One-Command Setup

```bash
chmod +x demo.sh
./demo.sh
```

### Manual Setup

See [docs/02-BLUE-GREEN-DEMO.md](docs/02-BLUE-GREEN-DEMO.md)

## 🔧 EC2 & Jenkins Setup

See [docs/01-EC2-JENKINS-SETUP.md](docs/01-EC2-JENKINS-SETUP.md)

## 📋 Key Commands

```bash
# Switch to Green
cd ansible && ansible-playbook -i inventory.ini deploy-green.yaml

# Rollback to Blue
ansible-playbook -i inventory.ini rollback-blue.yaml

# Manual traffic switch
kubectl patch svc devops-el-lb -p '{"spec":{"selector":{"color":"green"}}}' -n backend

# Check health
./monitor.sh
```

## 🎯 Demo Flow

1. **Blue Running** → Initial stable version
2. **Deploy Green** → New version deployed (scaled to 0)
3. **Switch Traffic** → Ansible switches service to green
4. **Verify** → Frontend shows green version
5. **Rollback** → If issues, switch back to blue

## 🔑 Credentials

- **Docker Hub**: harshavardhan873
- **GitHub**: https://github.com/hvardhan1024/devops-el
# devops-el
# devops-el-aman
