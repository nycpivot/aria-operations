#!/bin/bash

helm install prometheus oci://registry-1.docker.io/bitnamicharts/kube-prometheus

kubectl port-forward --namespace default svc/prometheus-kube-prometheus-prometheus 9090:9090