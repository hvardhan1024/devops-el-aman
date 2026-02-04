# Part 2: Blue-Green Deployment Demonstration

## Prerequisites (Local Machine)

- Docker installed
- Minikube installed & running
- kubectl configured
- Ansible installed
- Python 3 with venv

---

## Quick Start - All Commands in Order

### Step 0: Setup Python Environment & Ansible

```bash
cd ~/Desktop/DEVOPSEL_FINAL/devops-el

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Ansible and Kubernetes module
pip install ansible kubernetes

# Verify
ansible --version
```

### Step 1: Start Minikube & Create Namespaces

```bash
# Start minikube (if not running)
minikube start

# Create namespaces
kubectl create namespace backend
kubectl create namespace frontend

# Verify
kubectl get namespaces
```

---

## PHASE 1: Deploy Blue (Initial/Stable Version)

### Step 2: Build & Push Blue Backend

```bash
cd backend-blue

# Build image
docker build -t harshavardhan873/backend:blue .

# Push to Docker Hub
docker login -u harshavardhan873
docker push harshavardhan873/backend:blue
```

### Step 3: Deploy Blue Backend to Kubernetes

```bash
cd ../k8s

# Apply backend deployment
kubectl apply -f backend.yaml

# Wait for deployment
kubectl rollout status deployment/devops-el-blue -n backend

# Get backend service URL
minikube service devops-el-lb -n backend --url
```

**⚠️ COPY THIS URL** - You'll need it for the frontend!

### Step 4: Update Frontend with Backend URL

Edit `frontend/index.html` and update the `BACKEND_URL`:

```javascript
const BACKEND_URL = "<URL-FROM-STEP-3>" // e.g., http://192.168.49.2:31680
```

### Step 5: Build & Push Frontend

```bash
cd ../frontend

# Build image
docker build -t harshavardhan873/frontend:v1 .

# Push to Docker Hub
docker push harshavardhan873/frontend:v1
```

### Step 6: Deploy Frontend to Kubernetes

```bash
cd ../k8s

# Apply frontend deployment
kubectl apply -f frontend.yaml

# Wait for deployment
kubectl rollout status deployment/frontend-blue -n frontend

# Get frontend URL
minikube service frontend-lb -n frontend --url
```

### Step 7: Verify Blue Deployment

1. Open the frontend URL in browser
2. You should see:
   - **Version**: Blue Version
   - **Health**: OK from v1(Blue)!
   - **API**: OK from v1 ✓

---

## PHASE 2: Deploy Green (New Version) - Blue-Green Switch

### Step 8: Build & Push Green Backend

```bash
cd ../backend-green

# Build green image
docker build -t harshavardhan873/backend:green .

# Push to Docker Hub
docker push harshavardhan873/backend:green
```

### Step 9: Switch Traffic to Green using Ansible

```bash
cd ../ansible

# Activate venv if not active
source ../venv/bin/activate

# Run ansible playbook to switch to green
ansible-playbook -i inventory.ini deploy-green.yaml \
  --extra-vars "image_tag=harshavardhan873/backend:green"
```

### Step 10: Verify Green Deployment

1. Refresh the frontend URL in browser (hard refresh: Ctrl+Shift+R)
2. You should see:
   - **Version**: Green Version
   - **Health**: OK from v2(green)!
   - **API**: OK from v2 ✓

---

## PHASE 3: Rollback Demo (Simulating Failure)

### Step 11: Run Health Monitor (Detects Issues)

```bash
cd ..

# Make monitor script executable
chmod +x monitor.sh

# Run health check
./monitor.sh
```

If green is healthy, it will say "No rollback required".

### Step 12: Manual Rollback (if needed)

```bash
# Switch service back to blue
kubectl patch svc devops-el-lb \
  -p '{"spec":{"selector":{"color":"blue"}}}' \
  -n backend

# Scale down green
kubectl scale deployment/devops-el-green --replicas=0 -n backend
```

### Step 13: Verify Rollback

1. Refresh frontend
2. Should show Blue Version again

---
