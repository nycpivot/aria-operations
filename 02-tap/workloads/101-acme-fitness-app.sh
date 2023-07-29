#!/bin/bash

kubectl config get-contexts
echo

read -p "Select build context (tap-build): " kube_context

if [[ -z $kube_context ]]
then
    kube_context=tap-build
fi

kubectl config use-context ${kube_context}

git_username=nycpivot
git_password=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"github-token\")

app_name=acme-payment-service
git_app_url=https://github.com/dillson/payment.git

rm git-secret.yaml
cat <<EOF | tee git-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: git-secret
  annotations:
    tekton.dev/git-0: https://github.com
type: kubernetes.io/basic-auth
stringData:
  username: ${git_username}
  password: ${git_password}
EOF

kubectl apply -f git-secret.yaml

kubectl patch serviceaccount default -p '{"secrets": [{"name": "git-secret"}]}'

tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch master --type web \
    --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} \
    --param gitops_ssh_secret=git-secret --yes
