# Create Namespace
kubectl create namespace test

# Create Test Deployment
kubectl apply -f - <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
  namespace: test
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

test_pod_to_pod_comms() {
  
  # Get all pods belonging to the test-deployment
  deployment_pods=$(kubectl get pods -n test -l app=test -o jsonpath='{.items[*].metadata.name}')
  deployment_pod_array=($deployment_pods)

  # Pick two random pods from different worker nodes
  pod1=${deployment_pod_array[$((RANDOM % ${#deployment_pod_array[@]}))]}
  node1=$(kubectl get pod -n test $pod1 -o jsonpath='{.spec.nodeName}')

  pod2=""
  node2=""
  while [ -z "$pod2" ] || [ "$node1" == "$node2" ]; do
    pod2=${deployment_pod_array[$((RANDOM % ${#deployment_pod_array[@]}))]}
    node2=$(kubectl get pod -n test $pod2 -o jsonpath='{.spec.nodeName}')
  done

  # Get the pods running on the selected worker nodes
  pod1=$(kubectl get pods -n test -o jsonpath="{.items[?(@.spec.nodeName=='$node1')].metadata.name}" -l app=test)
  pod2=$(kubectl get pods -n test -o jsonpath="{.items[?(@.spec.nodeName=='$node2')].metadata.name}" -l app=test)

  if [ -z "$pod1" ] || [ -z "$pod2" ]; then
    echo "No pods found on the selected worker nodes. Skipping across-node test."
    return
  fi

  # Get the pod IP addresses and node IP addresses
  pod1_ip=$(kubectl get pod -n test $pod1 -o jsonpath='{.status.podIP}')
  pod2_ip=$(kubectl get pod -n test $pod2 -o jsonpath='{.status.podIP}')
  node1_ip=$(kubectl get node $node1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
  node2_ip=$(kubectl get node $node2 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')

  echo "Testing pod-to-pod communication across worker nodes $node1 ($node1_ip) and $node2 ($node2_ip)"
  kubectl exec -n test $pod1 -- curl -s http://$pod2_ip:80
  if [ $? -eq 0 ]; then
    echo "Pod-to-pod communication succeeded: $pod1 ($pod1_ip) -> $pod2 ($pod2_ip)"
  else
    echo "Pod-to-pod communication failed: $pod1 ($pod1_ip) -> $pod2 ($pod2_ip)"
  fi

  kubectl exec -n test $pod2 -- curl -s http://$pod1_ip:80
  if [ $? -eq 0 ]; then
    echo "Pod-to-pod communication succeeded: $pod2 ($pod2_ip) -> $pod1 ($pod1_ip)"
  else
    echo "Pod-to-pod communication failed: $pod2 ($pod2_ip) -> $pod1 ($pod1_ip)"
  fi
}

test_pod_to_pod_comms_across_worker_nodes() {
  worker_nodes=$(kubectl get nodes -l node-role.kubernetes.io/worker=true -o jsonpath='{.items[*].metadata.name}')
  worker_node_array=($worker_nodes)

  for ((i = 1; i <= 10; i++)); do
    test_pod_to_pod_comms worker_node_array
  done
  
}

test_pod_to_pod_comms_across_master_nodes() {
  master_nodes=$(kubectl get nodes -l node-role.kubernetes.io/master=true -o jsonpath='{.items[*].metadata.name}')
  master_node_array=($master_nodes)

  for ((i = 1; i <= 5; i++)); do
    test_pod_to_pod_comms master_node_array
  done
  
}

test_pod_to_pod_comms_across_worker_master_nodes() {
  worker_nodes=$(kubectl get nodes -l node-role.kubernetes.io/worker=true -o jsonpath='{.items[*].metadata.name}')
  master_nodes=$(kubectl get nodes -l node-role.kubernetes.io/master=true -o jsonpath='{.items[*].metadata.name}')
  worker_node_array=($worker_nodes)
  master_node_array=($master_nodes)
  for ((i = 1; i <= 10; i++)); do
    test_pod_to_pod_comms worker_node_array
  done
  
}

# Loop to test across-worker-node communication with different replica counts
for replicas in 10 20; do
  kubectl scale -n test deployment/test-deployment --replicas=$replicas
  kubectl rollout status -n test deployment/test-deployment --timeout=60s

  echo "Testing pod-pod communication across nodes"
  test_pod_to_pod_comms
#   test_pod_to_pod_comms_across_worker_nodes
#   echo "Testing pod-pod communication across master nodes"
#   test_pod_to_pod_comms_across_master_nodes

  echo "Waiting for 10 seconds..."
  sleep 10
done

# Clean up
kubectl delete namespace test

