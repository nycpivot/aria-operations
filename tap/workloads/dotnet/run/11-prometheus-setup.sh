#!/bin/bash

tap_run_aks=tap-run-aks

kubectl config use-context ${tap_run_aks}

# https://artifacthub.io/packages/helm/prometheus-community/prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install aria-operations prometheus-community/prometheus

# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
# helm install aria-operations prometheus-community/prometheus
# helm install prometheus oci://registry-1.docker.io/bitnamicharts/kube-prometheus
# helm install prometheus prometheus-community/kube-prometheus-stack


# exec the prometheus server pod and run nslookup to get DNS of the service
# or it should just work with just the ClusterIP
kubectl exec -it aria-operations-prometheus-server-<id> -- nslookup <svc-cluster-ip>

kubectl get configmap aria-operations-prometheus-server
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      scrape_timeout: 10s
       evaluation_interval: 15s
    scrape_configs:
      - job_name:  'tap-dotnet-weather-api'
        scrape_interval: 5s
        static_configs:
          - targets: [ 'tap-dotnet-weather-api-00005-private.default.svc.cluster.local' ] # SVC DNS
          
kubectl edit configmap aria-operations-prometheus-server

kubectl get pods | grep aria-operations-prometheus-server
kubectl delete pod # aria-operations-prometheus-server-<id>

kubectl port-forward --namespace default svc/aria-operations-prometheus-server 9090:80

# SAMPLE QUERIES OF METRICS OF PROMETHEUS ITSELF
# prometheus_target_interval_length_seconds
# prometheus_target_interval_length_seconds{quantile="0.99"}
# count(prometheus_target_interval_length_seconds)




kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: darwin
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      scrape_timeout: 10s
      evaluation_interval: 15s
    scrape_configs:
      - job_name: 'darwin-service'
        scrape_interval: 5s
        static_configs:
          - targets: ['darwin-service:8080']











kubectl create configmap prometheus-config -- from-file=prometheus.yml

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      scrape_timeout: 10s
       evaluation_interval: 15s
    scrape_configs:
      - job_name:  'tap-dotnet-weather-api'
        scrape_interval: 5s
        static_configs:
          - targets: [ 'tap-dotnet-weather-api-00005-private.default.svc.cluster.local' ]
EOF


kubectl port-forward --namespace default svc/prometheus-kube-prometheus-prometheus 9090:9090

