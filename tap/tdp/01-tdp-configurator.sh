#!/bin/bash

plugins_config=tpb-config

cat <<EOF | tee ${plugins_config}.yaml
app:
  plugins:
    - name: '@tpb/plugin-hello-world'
    - name: '@tpb/plugin-gitlab-loblaw'
      version: '^0.0.18'
backend:
  plugins:
    - name: '@tpb/plugin-hello-world-backend'
EOF

encoded_config=YXBwOgogIHBsdWdpbnM6CiAgICAtIG5hbWU6ICdAdHBiL3BsdWdpbi1oZWxsby13b3JsZCcKICAgIC0gbmFtZTogJ0B0cGIvcGx1Z2luLWdpdGxhYi1sb2JsYXcnCiAgICAgIHZlcnNpb246ICdeMC4wLjE4JwpiYWNrZW5kOgogIHBsdWdpbnM6CiAgICAtIG5hbWU6ICdAdHBiL3BsdWdpbi1oZWxsby13b3JsZC1iYWNrZW5kJw==

#$(base64 -i ${plugins_config}.yaml)

export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export INSTALL_REPO=tanzu-application-platform/tap-packages

workload_config=workload-config

cat <<EOF | tee ${workload_config}.yaml
apiVersion: carto.run/v1alpha1
kind: Workload
metadata:
  name: tdp-configurator
  namespace: default
  labels:
    apps.tanzu.vmware.com/workload-type: web
    app.kubernetes.io/part-of: tdp-configurator
spec:
  build:
    env:
      - name: BP_NODE_RUN_SCRIPTS
        value: 'set-tpb-config,portal:pack'
      - name: TPB_CONFIG
        value: /tmp/tpb-config.yaml
      - name: TPB_CONFIG_STRING
        value: ${encoded_config}
  source:
    image: ${IMGPKG_REGISTRY_HOSTNAME_1}/${INSTALL_REPO}
    subPath: builder
EOF

tanzu apps workload create -f ${workload_config}.yaml --yes


az acr manifest list-metadata --registry tanzuapplicationregistry.azurecr.io --name tanzu-application-platform/tap-packages --query '[:].[digest, imageSize, tags[:]]' -o table
