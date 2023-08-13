#!/bin/bash
# https://docs.google.com/document/d/11Th-4M9uT-7_byv4-wGqtjJ2mIcUG0hCdcRNm7sURWg/edit
# https://github.com/mstergianis/docs-tap/blob/5268f85d3e381597f4af22b4cce39c1c58f8c811/tap-gui/configurator/external-plugins.hbs.md

VIEW_DOMAIN=view.tap.nycpivot.com

tap_view=tap-view
tap_build=tap-build

kubectl config use-context $tap_build

plugins_config=tpb-config

if test -f ${plugins_config}.yaml; then
  rm ${plugins_config}.yaml
fi

cat <<EOF | tee ${plugins_config}.yaml
app:
  plugins:
    - name: '@tpb/plugin-hello-world'
      version: '^1.6.0-release-1.6.x.1'
    #- name: '@backstage/plugin-tech-radar'
backend:
  plugins:
    - name: '@tpb/plugin-hello-world-backend'
      version: '^1.6.0-release-1.6.x.1'
EOF

encoded_config=$(base64 -i ${plugins_config}.yaml -w0)

export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export INSTALL_REPO=tanzu-application-platform/tap-packages

#GET TPB PACKAGE TO GET THE CONFIGURATOR IMAGE NEEDED IN THE WORKLOAD
acr_secret=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"acr-secret\")

export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export IMGPKG_REGISTRY_USERNAME_1=tanzuapplicationregistry
export IMGPKG_REGISTRY_PASSWORD_1=$acr_secret

docker login $IMGPKG_REGISTRY_HOSTNAME_1 -u $IMGPKG_REGISTRY_USERNAME_1 -p $IMGPKG_REGISTRY_PASSWORD_1

tpb_package=$(kubectl -n tap-install get package tpb.tanzu.vmware.com.0.1.2 -o "jsonpath={.spec.template.spec.fetch[0].imgpkgBundle.image}")

imgpkg pull -b ${tpb_package} -o tpb-package

configurator_image=$(yq -r ".images[0].image" <tpb-package/.imgpkg/images.yml)

workload_config=workload-config

if test -f ${workload_config}.yaml; then
  rm ${workload_config}.yaml
fi

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
    image: ${configurator_image}
    subPath: builder
EOF

tanzu apps workload create -f ${workload_config}.yaml --yes

tdp_image=$(kubectl get images.kpack.io tdp-configurator -o jsonpath={.status.latestImage})

kubectl get workloads -w

#OVERLAY TAP-GUI IN VIEW CLUSTER
kubectl config use-context ${tap_view}

tdp_overlay_secret=tdp-overlay-secret

if test -f ${tdp_overlay_secret}.yaml; then
  rm ${tdp_overlay_secret}.yaml
fi

cat <<EOF | tee ${tdp_overlay_secret}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: tpb-app-image-overlay-secret
  namespace: tap-install
stringData:
  tpb-app-image-overlay.yaml: |
    #@ load("@ytt:overlay", "overlay")

    #! makes an assumption that tap-gui is deployed in the namespace: "tap-gui"
    #@overlay/match by=overlay.subset({"kind": "Deployment", "metadata": {"name": "server", "namespace": "tap-gui"}}), expects="1+"
    ---
    spec:
      template:
        spec:
          containers:
            #@overlay/match by=overlay.subset({"name": "backstage"}),expects="1+"
            #@overlay/match-child-defaults missing_ok=True
            - image: ${tdp_image}
            #@overlay/replace
              args:
              - -c
              - |
                export KUBERNETES_SERVICE_ACCOUNT_TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
                exec /layers/tanzu-buildpacks_node-engine-lite/node/bin/node portal/dist/packages/backend  \
                --config=portal/app-config.yaml \
                --config=portal/runtime-config.yaml \
                --config=/etc/app-config/app-config.yaml
EOF

kubectl apply -f ${tdp_overlay_secret}.yaml


#UPDATE TAP-VALUES-VIEW
tap_gui_overlay=tap-gui-overlay

if test -f ${tap_gui_overlay}.yaml; then
  rm ${tap_gui_overlay}.yaml
fi

cat <<EOF | tee ${tap_gui_overlay}.yaml
package_overlays:
- name: tap-gui
  secrets:
  - name: tpb-app-image-overlay-secret
EOF

rm tap-values-view-overlay.yaml
cp tap-values-view.yaml tap-values-view-overlay.yaml
cat ${tap_gui_overlay}.yaml >> tap-values-view-overlay.yaml

tanzu package installed update tap --values-file tap-values-view-overlay.yaml -n tap-install

echo
echo "TAP-GUI: " https://tap-gui.${VIEW_DOMAIN}
echo
echo "HAPPY TAP'ING!"
echo
