#!/bin/bash
#
# Blue-Green Deployment Demo (Local Minikube - No Docker Hub)
# Usage: ./demo.sh [setup|green|buggy|rollback|status|health|clean]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

print_header() {
    echo ""
    echo "============================================================"
    echo "  $1"
    echo "============================================================"
}

print_step() {
    echo ""
    echo "[STEP $1] $2"
    echo "------------------------------------------------------------"
}

print_done() {
    echo "[DONE] $1"
}

print_error() {
    echo "[ERROR] $1" >&2
}

wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    echo "Waiting for $deployment in $namespace..."
    kubectl rollout status deployment/$deployment -n $namespace --timeout=120s
}

check_prerequisites() {
    print_step "0" "Checking prerequisites"
    
    local missing=0
    
    for cmd in docker kubectl minikube; do
        if command -v $cmd >/dev/null 2>&1; then
            echo "  [OK] $cmd"
        else
            echo "  [MISSING] $cmd"
            missing=1
        fi
    done
    
    if [ $missing -eq 1 ]; then
        print_error "Missing prerequisites. Please install them first."
        exit 1
    fi
    
    print_done "All prerequisites met"
}

# -----------------------------------------------------------------------------
# Setup Command
# -----------------------------------------------------------------------------

cmd_setup() {
    print_header "BLUE-GREEN DEPLOYMENT - INITIAL SETUP"
    
    check_prerequisites
    
    print_step "1" "Starting Minikube"
    if minikube status >/dev/null 2>&1; then
        echo "Minikube already running"
    else
        minikube start --driver=docker
    fi
    print_done "Minikube is running"
    
    print_step "2" "Configuring Docker to use Minikube's daemon"
    eval $(minikube docker-env)
    print_done "Docker configured for Minikube"
    
    print_step "3" "Creating Kubernetes namespaces"
    kubectl create namespace backend --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace frontend --dry-run=client -o yaml | kubectl apply -f -
    print_done "Namespaces created"
    
    print_step "4" "Building Blue backend image"
    cd "$SCRIPT_DIR/backend-blue"
    docker build -t backend:blue . --quiet
    print_done "Blue backend image built"
    
    print_step "5" "Building Green backend image"
    cd "$SCRIPT_DIR/backend-green"
    docker build -t backend:green . --quiet
    print_done "Green backend image built"
    
    print_step "6" "Building Buggy Green backend image"
    cd "$SCRIPT_DIR/backend-green-buggy"
    docker build -t backend:green-buggy . --quiet
    print_done "Buggy Green backend image built"
    
    print_step "7" "Deploying backend to Kubernetes"
    cd "$SCRIPT_DIR"
    kubectl apply -f k8s/backend.yaml
    wait_for_deployment "devops-el-blue" "backend"
    print_done "Backend deployed"
    
    print_step "8" "Getting backend URL"
    BACKEND_URL=$(minikube service devops-el-lb -n backend --url 2>/dev/null | head -1)
    echo "Backend URL: $BACKEND_URL"
    
    print_step "9" "Updating frontend configuration"
    sed -i "s|const BACKEND_URL = '.*'|const BACKEND_URL = '${BACKEND_URL}'|" "$SCRIPT_DIR/frontend/index.html"
    print_done "Frontend configured with backend URL"
    
    print_step "10" "Building frontend image"
    cd "$SCRIPT_DIR/frontend"
    docker build -t frontend:v1 . --quiet
    print_done "Frontend image built"
    
    print_step "11" "Deploying frontend to Kubernetes"
    cd "$SCRIPT_DIR"
    kubectl apply -f k8s/frontend.yaml
    wait_for_deployment "frontend-blue" "frontend"
    print_done "Frontend deployed"
    
    FRONTEND_URL=$(minikube service frontend-lb -n frontend --url 2>/dev/null | head -1)
    
    print_header "SETUP COMPLETE"
    echo ""
    echo "Backend URL:  $BACKEND_URL"
    echo "Frontend URL: $FRONTEND_URL"
    echo ""
    echo "Current deployment: BLUE"
    echo "Frontend shows: BLUE theme (login form with blue gradient)"
    echo ""
    echo "Next steps:"
    echo "  1. Open frontend URL in browser"
    echo "  2. Run './demo.sh green' to switch to Green"
    echo "  3. Run './demo.sh buggy' to deploy buggy version"
    echo "  4. Run './monitor.sh' to trigger auto-rollback"
    echo ""
}

# -----------------------------------------------------------------------------
# Switch to Green
# -----------------------------------------------------------------------------

cmd_green() {
    print_header "SWITCHING TRAFFIC TO GREEN (WORKING)"
    
    eval $(minikube docker-env)
    
    print_step "1" "Ensuring Green uses working image"
    kubectl set image deployment/devops-el-green devops-el=backend:green -n backend 2>/dev/null || true
    print_done "Green image set to working version"
    
    print_step "2" "Scaling up Green deployment"
    kubectl scale deployment/devops-el-green --replicas=1 -n backend
    wait_for_deployment "devops-el-green" "backend"
    print_done "Green deployment scaled up"
    
    print_step "3" "Switching service selector to Green"
    kubectl patch svc devops-el-lb \
        -p '{"spec":{"selector":{"color":"green"}}}' \
        -n backend
    print_done "Traffic switched to Green"
    
    FRONTEND_URL=$(minikube service frontend-lb -n frontend --url 2>/dev/null | head -1)
    
    print_header "SWITCH COMPLETE"
    echo ""
    echo "Current deployment: GREEN (working)"
    echo "Frontend shows: GREEN theme (login form with green gradient)"
    echo "Frontend URL: $FRONTEND_URL"
    echo ""
    echo "Next steps:"
    echo "  - Run './demo.sh buggy' to deploy buggy version"
    echo "  - Run './demo.sh rollback' to switch back to Blue"
    echo ""
}

# -----------------------------------------------------------------------------
# Deploy Buggy Green
# -----------------------------------------------------------------------------

cmd_buggy() {
    print_header "DEPLOYING BUGGY GREEN VERSION"
    
    eval $(minikube docker-env)
    
    print_step "1" "Updating Green deployment with buggy image"
    kubectl set image deployment/devops-el-green devops-el=backend:green-buggy -n backend
    kubectl scale deployment/devops-el-green --replicas=1 -n backend
    wait_for_deployment "devops-el-green" "backend"
    print_done "Buggy Green deployed"
    
    print_step "2" "Switching traffic to buggy Green"
    kubectl patch svc devops-el-lb \
        -p '{"spec":{"selector":{"color":"green"}}}' \
        -n backend
    print_done "Traffic switched to buggy Green"
    
    FRONTEND_URL=$(minikube service frontend-lb -n frontend --url 2>/dev/null | head -1)
    
    print_header "BUGGY GREEN DEPLOYED"
    echo ""
    echo "The /api/status endpoint now returns HTTP 500"
    echo ""
    echo "Watch the frontend - it should turn RED (error theme)"
    echo "Frontend URL: $FRONTEND_URL"
    echo ""
    echo "Now run the monitor to detect and auto-rollback:"
    echo "  ./monitor.sh"
    echo ""
}

# -----------------------------------------------------------------------------
# Rollback to Blue
# -----------------------------------------------------------------------------

cmd_rollback() {
    print_header "ROLLING BACK TO BLUE"
    
    print_step "1" "Switching service selector to Blue"
    kubectl patch svc devops-el-lb \
        -p '{"spec":{"selector":{"color":"blue"}}}' \
        -n backend
    print_done "Traffic switched to Blue"
    
    print_step "2" "Scaling down Green deployment"
    kubectl scale deployment/devops-el-green --replicas=0 -n backend
    print_done "Green deployment scaled down"
    
    FRONTEND_URL=$(minikube service frontend-lb -n frontend --url 2>/dev/null | head -1)
    
    print_header "ROLLBACK COMPLETE"
    echo ""
    echo "Current deployment: BLUE"
    echo "Frontend shows: BLUE theme (login form with blue gradient)"
    echo "Frontend URL: $FRONTEND_URL"
    echo ""
}

# -----------------------------------------------------------------------------
# Status Command
# -----------------------------------------------------------------------------

cmd_status() {
    print_header "DEPLOYMENT STATUS"
    
    echo ""
    echo "Backend Namespace:"
    echo "------------------"
    kubectl get deployments -n backend -o wide 2>/dev/null || echo "  No deployments found"
    echo ""
    kubectl get pods -n backend -o wide 2>/dev/null || echo "  No pods found"
    echo ""
    
    echo "Frontend Namespace:"
    echo "-------------------"
    kubectl get deployments -n frontend -o wide 2>/dev/null || echo "  No deployments found"
    echo ""
    kubectl get pods -n frontend -o wide 2>/dev/null || echo "  No pods found"
    echo ""
    
    echo "Services:"
    echo "---------"
    kubectl get svc -n backend 2>/dev/null || echo "  No services found"
    kubectl get svc -n frontend 2>/dev/null || echo "  No services found"
    echo ""
    
    echo "Current Traffic:"
    echo "----------------"
    CURRENT_COLOR=$(kubectl get svc devops-el-lb -n backend -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "unknown")
    echo "  Backend service pointing to: $CURRENT_COLOR"
    echo ""
    
    echo "URLs:"
    echo "-----"
    BACKEND_URL=$(minikube service devops-el-lb -n backend --url 2>/dev/null | head -1 || echo "unavailable")
    FRONTEND_URL=$(minikube service frontend-lb -n frontend --url 2>/dev/null | head -1 || echo "unavailable")
    echo "  Backend:  $BACKEND_URL"
    echo "  Frontend: $FRONTEND_URL"
    echo ""
}

# -----------------------------------------------------------------------------
# Health Check
# -----------------------------------------------------------------------------

cmd_health() {
    print_header "HEALTH CHECK"
    
    BACKEND_URL=$(minikube service devops-el-lb -n backend --url 2>/dev/null | head -1)
    
    if [ -z "$BACKEND_URL" ]; then
        print_error "Cannot get backend URL. Is the deployment running?"
        exit 1
    fi
    
    echo ""
    echo "Backend URL: $BACKEND_URL"
    echo ""
    
    echo "Testing endpoints:"
    echo "------------------"
    
    echo -n "  / (version)    : "
    curl -s --max-time 5 "$BACKEND_URL/" || echo "FAILED"
    echo ""
    
    echo -n "  /health        : "
    curl -s --max-time 5 "$BACKEND_URL/health" || echo "FAILED"
    echo ""
    
    echo -n "  /api/status    : "
    curl -s --max-time 5 "$BACKEND_URL/api/status" || echo "FAILED"
    echo ""
    echo ""
}

# -----------------------------------------------------------------------------
# Clean Command
# -----------------------------------------------------------------------------

cmd_clean() {
    print_header "CLEANING UP RESOURCES"
    
    print_step "1" "Deleting namespaces"
    kubectl delete namespace backend --ignore-not-found=true
    kubectl delete namespace frontend --ignore-not-found=true
    print_done "Namespaces deleted"
    
    print_step "2" "Removing local images from Minikube"
    eval $(minikube docker-env)
    docker rmi backend:blue backend:green backend:green-buggy frontend:v1 2>/dev/null || true
    print_done "Local images removed"
    
    print_header "CLEANUP COMPLETE"
    echo ""
}

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------

usage() {
    echo ""
    echo "Blue-Green Deployment Demo (Local Minikube)"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  setup     Initial setup - build images and deploy Blue version"
    echo "  green     Switch traffic from Blue to Green (working)"
    echo "  buggy     Deploy buggy Green (returns 500 errors)"
    echo "  rollback  Switch traffic from Green back to Blue"
    echo "  status    Show current deployment status"
    echo "  health    Run health checks on backend"
    echo "  clean     Remove all deployed resources"
    echo ""
    echo "Demo Flow (Recommended):"
    echo "  1. ./demo.sh setup     - Deploy Blue (initial)"
    echo "  2. ./demo.sh green     - Switch to Green (working)"
    echo "  3. ./demo.sh buggy     - Deploy buggy Green"
    echo "  4. ./monitor.sh        - Watch health checks trigger rollback"
    echo ""
    echo "Frontend Theme Colors:"
    echo "  BLUE  = Blue v1 backend active (healthy)"
    echo "  GREEN = Green v2 backend active (healthy)"
    echo "  RED   = API error detected"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

cd "$SCRIPT_DIR"

case "${1:-}" in
    setup)
        cmd_setup
        ;;
    green)
        cmd_green
        ;;
    buggy)
        cmd_buggy
        ;;
    rollback)
        cmd_rollback
        ;;
    status)
        cmd_status
        ;;
    health)
        cmd_health
        ;;
    clean)
        cmd_clean
        ;;
    *)
        usage
        exit 1
        ;;
esac
