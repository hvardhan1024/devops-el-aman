# Blue-Green Deployment Demo (Local Minikube)

A local blue-green deployment demo using Docker, Kubernetes (Minikube), and helper scripts for quick switching, rollback, and health monitoring.

## 📁 Project Structure

```
devops-el/
├── backend-blue/                   # Blue (stable) backend
├── backend-green/                  # Green (working) backend
├── backend-green-buggy/            # Green (buggy) backend
├── frontend/                       # Static dashboard (NodePort 30081)
├── k8s/                            # Kubernetes manifests (NodePort 30080/30081)
├── ansible/                        # Playbooks for traffic switch
├── demo.sh                         # Main orchestrator (setup/green/buggy/rollback/portfw)
├── monitor.sh                      # Health monitor with auto-rollback
└── docs/                           # Detailed guides
```

## 🚀 How to Run the Demo

> Assumes Docker, Minikube, and kubectl are installed. Run all commands from the repo root on Ubuntu/WSL.

1) Setup everything (build images, deploy blue)
```bash
./demo.sh setup
```

2) Start port-forward (and keep this terminal open). Press **r** anytime you switch versions to restart port-forward. Press **q/Ctrl+C** to quit.
```bash
./demo.sh portfw
```
Open http://localhost:30081 → you should see **Blue v1**.

3) Switch to Green (working)
```bash
./demo.sh green
```
After it finishes, go to the port-forward terminal and press **r**, then refresh the browser → you should see **Green v2** with green background.

4) Switch to Buggy Green (returns HTTP 500)
```bash
./demo.sh buggy
```
Press **r** in the port-forward terminal and refresh → frontend turns red (error theme).

5) Roll back to Blue
```bash
./demo.sh rollback
```
Press **r** in the port-forward terminal and refresh → back to **Blue v1**.

6) Demonstrate auto-rollback from buggy
```bash
./demo.sh buggy      # put buggy version live
./demo.sh portfw     # if not already running (press r after switches)
./monitor.sh         # in a new terminal
```
Monitor will detect 500s, scale Blue up, switch traffic to Blue (app+color selector), scale Green down, and you’ll see Blue again after pressing **r** in port-forward.

## 🧭 Working Notes

- Backend service selector uses both labels `app=devops-el` and `color` to target the correct pods.
- Images are built inside Minikube with `minikube image build` (containerd-safe), so no Docker Hub push is needed.
- Services use fixed NodePorts: backend `30080`, frontend `30081`.
- Frontend always calls backend via `http://localhost:30080` (works with port-forward).
- Monitor scales Blue up, waits for rollout, patches service back to Blue, then scales Green down.

## 🔧 Useful Commands (K8s & Docker)

```bash
# Build images directly into Minikube (containerd runtime)
minikube image build -t backend:blue backend-blue
minikube image build -t backend:green backend-green
minikube image build -t backend:green-buggy backend-green-buggy
minikube image build -t frontend:v1 frontend

# Apply manifests
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml

# Manual traffic switch
kubectl patch svc devops-el-lb \
	-p '{"spec":{"selector":{"app":"devops-el","color":"green"}}}' \
	-n backend

# Roll back traffic to blue
kubectl patch svc devops-el-lb \
	-p '{"spec":{"selector":{"app":"devops-el","color":"blue"}}}' \
	-n backend

# Port-forward (frontend and backend)
kubectl port-forward -n frontend svc/frontend-lb 30081:80 --address 0.0.0.0
kubectl port-forward -n backend svc/devops-el-lb 30080:80 --address 0.0.0.0

# Health monitor with auto-rollback
./monitor.sh
```

## 🧩 How It Works (Blue/Green)

- Blue and Green deployments run side-by-side; service selector picks which color gets traffic.
- Green starts scaled to 0; switching to Green scales it up and scales Blue down.
- Buggy Green returns HTTP 500; monitor detects failures and auto-rolls back.
- Port-forward exposes NodePorts to localhost for Windows/WSL browsers; restart it after switches.

## 🙌 Contributions (What was added/changed)

- Local-only workflow: build images with `minikube image build`, no Docker Hub push.
- NodePort services (30080/30081) with helper port-forward script and interactive restart (press **r**).
- Service patches now include both `app` and `color` selectors to avoid mismatches.
- Auto-rollback enhanced: scale Blue up, wait for rollout, patch selector, scale Green down.
- Frontend hardwired to localhost backend; backend responses cleaned to avoid false “Blue” detection.

## 📚 Docs

- Detailed demo walkthrough: docs/02-BLUE-GREEN-DEMO.md
- EC2/Jenkins setup: docs/01-EC2-JENKINS-SETUP.md
