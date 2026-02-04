#!/bin/bash
#
# DEMO SCRIPT - Blue-Green Deployment with Auto-Rollback
# 
# Demo Flow:
#   1. Blue running smoothly
#   2. Deploy working Green, switch traffic
#   3. Deploy buggy Green, monitor detects and rollbacks to Blue
#

DOCKER_USER="harshavardhan873"

echo "============================================================"
echo "  BLUE-GREEN DEPLOYMENT DEMO"
echo "============================================================"
echo ""
echo "Frontend Theme Colors:"
echo "  BLUE gradient  = Blue v1 backend (healthy)"
echo "  GREEN gradient = Green v2 backend (healthy)"
echo "  RED gradient   = API error detected"
echo ""
echo "Commands available:"
echo ""
echo "  PHASE 1 - Initial Setup (Blue):"
echo "    ./run-demo.sh setup"
echo ""
echo "  PHASE 2 - Deploy Working Green:"
echo "    ./run-demo.sh green"
echo ""
echo "  PHASE 3 - Deploy Buggy Green (triggers rollback):"
echo "    ./run-demo.sh buggy"
echo ""
echo "  Monitor Health (run in separate terminal):"
echo "    ./monitor.sh"
echo ""
echo "  Other commands:"
echo "    ./run-demo.sh status   - Check current status"
echo "    ./run-demo.sh reset    - Reset to Blue"
echo ""
echo "============================================================"

case "${1:-}" in
  setup)
    echo ""
    echo "[PHASE 1] Setting up BLUE deployment..."
    echo "------------------------------------------------------------"
    
    # Build blue
    echo "[1/4] Building Blue backend..."
    cd backend-blue
    docker build -t ${DOCKER_USER}/backend:blue . --quiet
    docker push ${DOCKER_USER}/backend:blue --quiet
    cd ..
    
    # Build working green
    echo "[2/4] Building Green backend (working version)..."
    cd backend-green
    docker build -t ${DOCKER_USER}/backend:green . --quiet
    docker push ${DOCKER_USER}/backend:green --quiet
    cd ..
    
    # Build buggy green
    echo "[3/4] Building Green backend (buggy version)..."
    cd backend-green-buggy
    docker build -t ${DOCKER_USER}/backend:green-buggy . --quiet
    docker push ${DOCKER_USER}/backend:green-buggy --quiet
    cd ..
    
    # Deploy
    echo "[4/4] Deploying to Kubernetes..."
    kubectl create namespace backend --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace frontend --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f k8s/backend.yaml
    kubectl apply -f k8s/frontend.yaml
    kubectl rollout status deployment/devops-el-blue -n backend --timeout=60s
    kubectl rollout status deployment/frontend-blue -n frontend --timeout=60s
    
    BACKEND_URL=$(minikube service devops-el-lb -n backend --url 2>/dev/null | head -1)
    FRONTEND_URL=$(minikube service frontend-lb -n frontend --url 2>/dev/null | head -1)
    
    echo ""
    echo "[DONE] Blue is running!"
    echo "Backend URL:  $BACKEND_URL"
    echo "Frontend URL: $FRONTEND_URL"
    echo ""
    echo "Open frontend in browser - shows BLUE theme (login form)"
    echo "Test backend: curl $BACKEND_URL/api/status"
    echo ""
    ;;
    
  green)
    echo ""
    echo "[PHASE 2] Deploying WORKING Green and switching traffic..."
    echo "------------------------------------------------------------"
    
    # Update green deployment to use working image
    echo "[1/3] Updating Green deployment with working image..."
    kubectl set image deployment/devops-el-green devops-el=${DOCKER_USER}/backend:green -n backend
    
    echo "[2/3] Scaling up Green deployment..."
    kubectl scale deployment/devops-el-green --replicas=1 -n backend
    kubectl rollout status deployment/devops-el-green -n backend --timeout=60s
    
    echo "[3/3] Switching traffic to Green..."
    kubectl patch svc devops-el-lb -p '{"spec":{"selector":{"color":"green"}}}' -n backend
    
    BACKEND_URL=$(minikube service devops-el-lb -n backend --url 2>/dev/null | head -1)
    FRONTEND_URL=$(minikube service frontend-lb -n frontend --url 2>/dev/null | head -1)
    
    echo ""
    echo "[DONE] Traffic switched to GREEN (working version)!"
    echo "Backend URL:  $BACKEND_URL"
    echo "Frontend URL: $FRONTEND_URL"
    echo ""
    echo "Frontend now shows GREEN theme"
    echo "Test backend: curl $BACKEND_URL/api/status (expect OK from v2)"
    echo ""
    ;;
    
  buggy)
    echo ""
    echo "[PHASE 3] Deploying BUGGY Green..."
    echo "------------------------------------------------------------"
    
    echo "[1/2] Updating Green deployment with BUGGY image..."
    kubectl set image deployment/devops-el-green devops-el=${DOCKER_USER}/backend:green-buggy -n backend
    kubectl rollout status deployment/devops-el-green -n backend --timeout=60s
    
    BACKEND_URL=$(minikube service devops-el-lb -n backend --url 2>/dev/null | head -1)
    FRONTEND_URL=$(minikube service frontend-lb -n frontend --url 2>/dev/null | head -1)
    
    echo ""
    echo "[DONE] Buggy Green deployed!"
    echo "Backend URL:  $BACKEND_URL"
    echo "Frontend URL: $FRONTEND_URL"
    echo ""
    echo "Frontend now shows RED theme (API error)"
    echo "Test backend: curl $BACKEND_URL/api/status (expect HTTP 500)"
    echo ""
    echo "Run the monitor to detect and auto-rollback:"
    echo "  ./monitor.sh"
    echo ""
    ;;
    
  status)
    echo ""
    echo "[STATUS] Current deployment status:"
    echo "------------------------------------------------------------"
    
    CURRENT_COLOR=$(kubectl get svc devops-el-lb -n backend -o jsonpath='{.spec.selector.color}' 2>/dev/null)
    echo "Traffic pointing to: $CURRENT_COLOR"
    echo ""
    
    echo "Deployments:"
    kubectl get deployments -n backend
    echo ""
    
    echo "Pods:"
    kubectl get pods -n backend
    echo ""
    
    BACKEND_URL=$(minikube service devops-el-lb -n backend --url 2>/dev/null | head -1)
    FRONTEND_URL=$(minikube service frontend-lb -n frontend --url 2>/dev/null | head -1)
    echo "Backend URL:  $BACKEND_URL"
    echo "Frontend URL: $FRONTEND_URL"
    echo ""
    
    echo "Quick test:"
    curl -s "$BACKEND_URL/api/status" && echo "" || echo "(request failed)"
    echo ""
    ;;
    
  reset)
    echo ""
    echo "[RESET] Switching back to Blue..."
    echo "------------------------------------------------------------"
    
    kubectl patch svc devops-el-lb -p '{"spec":{"selector":{"color":"blue"}}}' -n backend
    kubectl scale deployment/devops-el-green --replicas=0 -n backend
    
    FRONTEND_URL=$(minikube service frontend-lb -n frontend --url 2>/dev/null | head -1)
    
    echo ""
    echo "[DONE] Traffic reset to BLUE"
    echo "Frontend URL: $FRONTEND_URL"
    echo "Frontend now shows BLUE theme"
    echo ""
    ;;
    
  *)
    # Just show the help (already printed above)
    ;;
esac
