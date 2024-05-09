#!/bin/bash

while true; do
    # Generate a random pod name
    pod_name="test-$(date +%s)"

    # Create a pod
    kubectl run $pod_name --image=nginx --restart=Never --labels=app=test

    # Get a list of all pods
    pods=$(kubectl get pods -o jsonpath='{.items[*].metadata.name}')

    # Choose a random pod
    other_pod=$(echo $pods | tr ' ' '\n' | grep -v $pod_name | shuf -n 1)

    # Check communication between the two pods
    kubectl exec $pod_name -- wget -qO- $other_pod

    # Delete the pod
    kubectl delete pod $pod_name

    # Sleep for a short duration before creating the next pod
    sleep 0.1
done
