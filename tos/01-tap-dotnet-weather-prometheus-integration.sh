#!/bin/bash

tap_run_aks=tap-run-aks

wavefront_url=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-url\")
wavefront_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-token\")

kubectl config use-context ${tap_run_aks}

# Need to change YOUR_CLUSTER and YOUR_API_TOKEN accordingly
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
# Kubernetes versions after 1.9.0 should use apps/v1
# Kubernetes version 1.8.x should use apps/v1beta2
# Kubernetes versions before 1.8.0 should use apps/v1beta1
kind: Deployment
metadata:
  labels:
    app: wavefront-proxy
    name: wavefront-proxy
  name: wavefront-proxy
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wavefront-proxy
  template:
    metadata:
      labels:
        app: wavefront-proxy
    spec:
      containers:
        - name: wavefront-proxy
          image: projects.registry.vmware.com/tanzu_observability/proxy:12.0
          imagePullPolicy: IfNotPresent
          env:
            - name: WAVEFRONT_URL
              value: ${wavefront_url}/api/
            - name: WAVEFRONT_TOKEN
              value: ${wavefront_token}
          # Uncomment the below lines to consume Zipkin/Istio traces
          #- name: WAVEFRONT_PROXY_ARGS
          #  value: --traceZipkinListenerPorts 9411
          ports:
            - containerPort: 2878
              protocol: TCP
          # Uncomment the below lines to consume Zipkin/Istio traces
          #- containerPort: 9411
          #  protocol: TCP
          securityContext:
            privileged: false
---
apiVersion: v1
kind: Service
metadata:
  name: wavefront-proxy
  labels:
    app: wavefront-proxy
  namespace: default
spec:
  ports:
    - name: wavefront
      port: 2878
      protocol: TCP
  # Uncomment the below lines to consume Zipkin/Istio traces
  #- name: http
  #  port: 9411
  #  targetPort: 9411
  #  protocol: TCP
  selector:
    app: wavefront-proxy
EOF

cat <<EOF | kubectl apply -f -
kind: Deployment
apiVersion: apps/v1
metadata:
  name: prometheus-storage-adapter
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus-storage-adapter
  template:
    metadata:
      labels:
        app: prometheus-storage-adapter
    spec:
      containers:
      - name: prometheus-storage-adapter
        image: wavefronthq/prometheus-storage-adapter:latest
        command:
        - /bin/adapter
        - -listen=1234
        - -proxy=wavefront-proxy.default.svc.cluster.local
        - -proxy-port=2878
        - -prefix=tap-dotnet-weather-api
---
apiVersion: v1
kind: Service
metadata:
  name: storage-adapter-service
spec:
  selector:
    app: prometheus-storage-adapter
  ports:
    - name: adapter-port
      protocol: TCP
      port: 80
      targetPort: 1234
EOF

remote_write:
  - url: "http://storage-adapter-service.default.svc.cluster.local/receive"

kubectl edit configmap aria-operations-prometheus-server

echo
echo ">>> Infra Metrics:"
echo https://vmwareprod.wavefront.com/proxies
echo

echo
echo ">>> App Metrics:"
echo https://vmwareprod.wavefront.com/metrics#_v01(s:tap-dotnet-weather-api)
echo


