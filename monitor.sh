#!/bin/bash
#
# Health Monitor - Detects failures and auto-rollbacks to Blue
# This script monitors the /api/status endpoint and triggers rollback on failures
#

echo ""
echo "============================================================"
echo "  HEALTH MONITOR - Auto Rollback System"
echo "============================================================"
echo ""

BACKEND_URL="http://$(minikube ip):30080"
FRONTEND_URL="http://$(minikube ip):30081"

if [ -z "$BACKEND_URL" ]; then
  echo "[ERROR] Failed to fetch backend service URL"
  exit 1
fi

echo "[INFO] Backend URL:  $BACKEND_URL"
echo "[INFO] Frontend URL: $FRONTEND_URL"
echo ""
echo "[INFO] Watch the frontend - background color indicates status:"
echo "       BLUE  = Blue v1 backend (healthy)"
echo "       GREEN = Green v2 backend (healthy)"
echo "       RED   = API Error detected"
echo ""
echo "[INFO] Running health checks on /api/status endpoint..."
echo ""

error_count=0
total_checks=5

for i in $(seq 1 $total_checks); do
  echo -n "[CHECK $i/$total_checks] "
  
  response=$(curl -s -o /dev/null -w '%{http_code}' "$BACKEND_URL/api/status" --max-time 5)
  
  if [ "$response" -ne 200 ]; then
    echo "FAILED (HTTP $response)"
    ((error_count++))
  else
    echo "OK (HTTP 200)"
  fi
  
  sleep 2
done

echo ""
echo "------------------------------------------------------------"
echo "[RESULT] $error_count failures out of $total_checks checks"
echo "------------------------------------------------------------"
echo ""

if [ "$error_count" -ge 3 ]; then
  echo "[ALERT] Backend is UNHEALTHY! Initiating automatic rollback..."
  echo ""
  
  echo "[ROLLBACK] Step 1: Switching traffic to BLUE deployment"
  kubectl patch svc devops-el-lb \
    -p '{"spec":{"selector":{"color":"blue"}}}' \
    -n backend
  
  echo "[ROLLBACK] Step 2: Scaling down GREEN deployment"
  kubectl scale deployment/devops-el-green --replicas=0 -n backend
  
  echo ""
  echo "============================================================"
  echo "  ROLLBACK COMPLETE - Traffic now on BLUE"
  echo "============================================================"
  echo ""
  echo "[INFO] Frontend will now show BLUE theme (auto-refresh in 3s)"
  echo "[INFO] Frontend URL: $FRONTEND_URL"
else
  echo "[OK] Backend is healthy. No rollback required."
fi

echo ""
echo "[DONE] Health monitor finished"
