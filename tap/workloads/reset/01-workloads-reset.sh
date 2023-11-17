#!/bin/bash

kubectl config use-context tap-run-eks
kubectl delete deliverable tanzu-java-web-app

kubectl config use-context tap-run-aks
kubectl delete deliverable tanzu-java-web-app

kubectl config use-context tap-build
tanzu apps workload delete tanzu-java-web-app --yes

rm tanzu-java-web-app-deliverable.yaml
