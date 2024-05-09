# Create Namespace
kubectl create namespace pod-comm-test

# Create Test Deployment
kubectl apply -f - <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
  namespace: pod-comm-test
spec:
  replicas: 10
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: test-container
        image: nginx:latest
        ports:
        - containerPort: 80
EOF

# Create Test Service
kubectl apply -f - <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: test-service
  namespace: pod-comm-test
spec:
  selector:
    app: test
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
EOF

test_pod_to_pod_comms() {
  
  deployment_pods=$(kubectl get pods -n pod-comm-test -l app=test -o jsonpath='{.items[*].metadata.name}')
  deployment_pod_array=($deployment_pods)

  # Pick two random pods from different nodes
  pod1=${deployment_pod_array[$((RANDOM % ${#deployment_pod_array[@]}))]}
  node1=$(kubectl get pod -n pod-comm-test $pod1 -o jsonpath='{.spec.nodeName}')

  pod2=""
  node2=""
  while [ -z "$pod2" ] || [ "$node1" == "$node2" ]; do
    pod2=${deployment_pod_array[$((RANDOM % ${#deployment_pod_array[@]}))]}
    node2=$(kubectl get pod -n pod-comm-test $pod2 -o jsonpath='{.spec.nodeName}')
  done

  pod1_ip=$(kubectl get pod -n pod-comm-test $pod1 -o jsonpath='{.status.podIP}')
  pod2_ip=$(kubectl get pod -n pod-comm-test $pod2 -o jsonpath='{.status.podIP}')

  # Test pod-to-pod communication
  kubectl exec -n pod-comm-test $pod1 -- curl -s http://$pod2_ip:80 >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "Pod-to-pod communication succeeded: NODE:$node1  POD:$pod1_ip  ->  NODE:$node2  POD:$pod2_ip"
  else
    echo "Pod-to-pod communication failed: NODE:$node1  POD:$pod1_ip  ->  NODE:$node2  POD:$pod2_ip"
  fi

  kubectl exec -n pod-comm-test $pod2 -- curl -s http://$pod1_ip:80 >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "Pod-to-pod communication succeeded: NODE:$node2  POD:$pod2_ip  ->  NODE:$node1  POD:$pod1_ip"
  else
    echo "Pod-to-pod communication failed: NODE:$node2  POD:$pod2_ip  ->  NODE:$node1  POD:$pod1_ip"
  fi
}

test_pod_to_service_comms() {
  service_ip=$(kubectl get svc -n pod-comm-test test-service -o jsonpath='{.spec.clusterIP}')

  # Pick a random pod
  pod=${deployment_pod_array[$((RANDOM % ${#deployment_pod_array[@]}))]}
  node=$(kubectl get pod -n pod-comm-test $pod -o jsonpath='{.spec.nodeName}')

  # Get the pod IP address
  pod_ip=$(kubectl get pod -n pod-comm-test $pod -o jsonpath='{.status.podIP}')

  # Test pod-to-service communication
  kubectl exec -n pod-comm-test $pod -- curl -s http://$service_ip:80 >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "Pod-to-service communication succeeded: NODE:$node  POD:$pod_ip  ->  SERVICE:$service_ip"
  else
    echo "Pod-to-service communication failed: NODE:$node  POD:$pod_ip  ->  SERVICE:$service_ip"
  fi
}

# Initial replica count
min_replicas=10
max_replicas=300
replicas=50

while [ $min_replicas -lt $max_replicas ]; do
  # Scale the deployment to the current replica count
  kubectl scale -n pod-comm-test deployment/test-deployment --replicas=$replicas
  kubectl rollout status -n pod-comm-test deployment/test-deployment --timeout=60s

  # Test pod-to-pod and pod-to-service communication
  for ((i = 1; i <= 10; i++)); do
    test_pod_to_pod_comms
    test_pod_to_service_comms
  done

  echo "Current replica count: $replicas"

  # Ask the user to decide whether to scale up or down
  read -p "Enter 'u' to scale up, 'd' to scale down, or 'q' to quit: " action
  case $action in
    u)
      # Scale up
      min_replicas=$replicas
      replicas=$((min_replicas + (max_replicas - min_replicas) / 2))
      ;;
    d)
      # Scale down
      max_replicas=$replicas
      replicas=$((min_replicas + (max_replicas - min_replicas) / 2))
      ;;
    q)
      # Quit
      read -p "delete the deployment and service? y/n: " action
      if [ "$action" == "y" ]; then
        kubectl delete namespace pod-comm-test
      fi
      break
      ;;
    *)
      echo "Invalid input. Please try again."
      ;;
  esac
done