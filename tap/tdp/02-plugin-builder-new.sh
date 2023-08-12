#!/bin/bash
# https://docs.google.com/document/d/11Th-4M9uT-7_byv4-wGqtjJ2mIcUG0hCdcRNm7sURWg/edit
# https://github.com/mstergianis/docs-tap/blob/5268f85d3e381597f4af22b4cce39c1c58f8c811/tap-gui/configurator/external-plugins.hbs.md

VIEW_DOMAIN=view.tap.nycpivot.com

acr_secret=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"acr-secret\")

export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export IMGPKG_REGISTRY_USERNAME_1=tanzuapplicationregistry
export IMGPKG_REGISTRY_PASSWORD_1=$acr_secret
export INSTALL_REPO=tanzu-application-platform/tap-packages

docker login $IMGPKG_REGISTRY_HOSTNAME_1 -u $IMGPKG_REGISTRY_USERNAME_1 -p $IMGPKG_REGISTRY_PASSWORD_1

backstage_app=backstage
tap_build=tap-build

kubectl config use-context $tap_build

# Find the location of the builder image by querying your TAP cluster
tpb_package=$(kubectl get package tpb.tanzu.vmware.com.0.1.2 -n tap-install -o "jsonpath={.spec.template.spec.fetch[0].imgpkgBundle.image}")

# This is a carvel bundle containing the builder image, 
# in order to get the address of the builder image you must download
# the carvel bundle and look at the image lock file within.
imgpkg pull -b ${tpb_package} -o tpb-package

# extract the configurator image tag
configurator_image=$(yq -r ".images[0].image" <tpb-package/.imgpkg/images.yml)

# download the configurator
imgpkg pull -i ${configurator_image} -o builder

# a workaround is needed to adjust the parameters 
# of the verdaccio offline_config.yaml in order 
# to fetch recently published packages
rm ~/builder/builder/registry/offline_config.yaml
cat <<EOF | tee ~/builder/builder/registry/offline_config.yaml
storage: ./storage
uplinks:
  npmjs:
    url: https://registry.npmjs.org/
    maxage: 2m
    cache: true
packages:
  '@tpb/*':
    access: $all
  '**':
    access: $all
    proxy: npmjs
log: { type: stdout, format: pretty, level: http }
EOF

cd ~/builder/builder/registry

# this particular curl doesn't recognize --retry-all-errors
rm start_offline.sh
cat <<EOF | tee start_offline.sh
#!/usr/bin/env bash
set -eou pipefail

echo "---> Starting Verdaccio..."

./node_modules/forever/bin/forever start node_modules/verdaccio/bin/verdaccio --config offline_config.yaml
if ! curl --connect-timeout 5 \
    --max-time 10 \
    --retry 5 \
    --retry-delay 0 \
    --retry-max-time 40 \
    http://localhost:4873/-/ping > /dev/null 2>&1; then
        echo "ERROR: Failed to start internal npm registry"
        exit 1
fi

echo "Verdaccio started"
EOF

./start_offline.sh
# ./node_modules/verdaccio/bin/verdaccio --config offline_config.yaml

# run the following to stop the forever server
# ./node_modules/forever/bin/forever stop node_modules/verdaccio/bin/verdaccio

# return to home and create backstage folder
cd ~
npx @backstage/create-app@latest --skip-install

cd ~/${backstage_app}
echo 'registry "http://localhost:4873"' > .yarnrc

# remove the packages directory, which contains a scaffolded backstage app and backend
rm -rf ~/${backstage_app}/packages/

# remove packages from workspaces section
rm ~/${backstage_app}/package.json
cat <<EOF | tee ~/${backstage_app}/package.json
{
  "name": "root",
  "version": "1.0.0",
  "private": true,
  "engines": {
    "node": "16 || 18"
  },
  "scripts": {
    "dev": "concurrently \"yarn start\" \"yarn start-backend\"",
    "start": "yarn workspace app start",
    "start-backend": "yarn workspace backend start",
    "build:backend": "yarn workspace backend build",
    "build:all": "backstage-cli repo build --all",
    "build-image": "yarn workspace backend build-image",
    "tsc": "tsc",
    "tsc:full": "tsc --skipLibCheck false --incremental false",
    "clean": "backstage-cli repo clean",
    "test": "backstage-cli repo test",
    "test:all": "backstage-cli repo test --coverage",
    "lint": "backstage-cli repo lint --since origin/master",
    "lint:all": "backstage-cli repo lint",
    "prettier:check": "prettier --check .",
    "new": "backstage-cli new --scope internal"
  },
  "workspaces": {
    "packages": [
      "plugins/*"
    ]
  },
  "devDependencies": {
    "@backstage/cli": "^0.22.9",
    "@spotify/prettier-config": "^12.0.0",
    "concurrently": "^6.0.0",
    "lerna": "^4.0.0",
    "node-gyp": "^9.0.0",
    "prettier": "^2.3.2",
    "typescript": "~5.0.0"
  },
  "resolutions": {
    "@types/react": "^17",
    "@types/react-dom": "^17"
  },
  "prettier": "@spotify/prettier-config",
  "lint-staged": {
    "*.{js,jsx,ts,tsx,mjs,cjs}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md}": [
      "prettier --write"
    ]
  }
}
EOF

yarn install

yarn backstage-cli new

# When asked "What do you want to create?" select "plugin - A new frontend plugin".
# When asked for "... the ID of the plugin [required]" enter "tech-insights-wrapper"

cd plugins/tech-insights-wrapper

rm package.json
cat <<EOF | tee package.json
{
  "name": "@nycpivot/tech-insights-wrapper",
  "version": "0.1.0",
  "main": "src/index.ts",
  "types": "src/index.ts",
  "license": "Apache-2.0",
  "publishConfig": {
    "access": "public",
    "main": "dist/index.esm.js",
    "types": "dist/index.d.ts"
  },
  "backstage": {
    "role": "frontend-plugin"
  },
  "scripts": {
    "start": "backstage-cli package start",
    "build": "backstage-cli package build",
    "lint": "backstage-cli package lint",
    "test": "backstage-cli package test",
    "clean": "backstage-cli package clean",
    "prepack": "backstage-cli package prepack",
    "postpack": "backstage-cli package postpack"
  },
  "dependencies": {
    "@backstage/plugin-catalog": "1.11.2",
    "@backstage/plugin-tech-insights": "0.3.11",
    "@tpb/core-common": "1.6.0-release-1.6.x.1",
    "@tpb/core-frontend": "1.6.0-release-1.6.x.1",
    "@tpb/plugin-catalog": "1.6.0-release-1.6.x.1"
  },
  "peerDependencies": {
    "react": "^17.0.2",
    "react-dom": "^17.0.2",
    "react-router": "6.0.0-beta.0",
    "react-router-dom": "6.0.0-beta.0"
  },
  "devDependencies": {
    "@backstage/cli": "^0.22.6",
    "@types/react": "^16.14.0",
    "@types/react-dom": "^16.9.16",
    "eslint": "^8.16.0",
    "typescript": "~4.6.4"
  },
  "files": [
    "dist"
  ]
}
EOF

rm -rf dev/ src/ && mkdir src
cd src/

cat <<EOF | tee index.ts
export { TechInsightsFrontendPlugin as plugin } from './TechInsightsFrontendPlugin';
EOF

cat <<EOF | tee TechInsightsFrontendPlugin.tsx
import { EntityLayout } from '@backstage/plugin-catalog';
import { EntityTechInsightsScorecardContent } from '@backstage/plugin-tech-insights';
import { AppPluginInterface, AppRouteSurface } from '@tpb/core-frontend';
import { SurfaceStoreInterface } from '@tpb/core-common';
import { EntityPageSurface } from '@tpb/plugin-catalog';
import React from 'react';

export const TechInsightsFrontendPlugin: AppPluginInterface =
  () => (context: SurfaceStoreInterface) => {
    context.applyWithDependency(
      AppRouteSurface,
      EntityPageSurface,
      (_appRouteSurface, entityPageSurface) => {
        entityPageSurface.servicePage.addTab(
          <EntityLayout.Route path="/techinsights" title="TechInsights">
            <EntityTechInsightsScorecardContent
              title="TechInsights Scorecard."
              description="TechInsight's default fact-checkers"
            />
          </EntityLayout.Route>,
        );
      },
    );
  };
EOF

yarn install && yarn tsc && yarn build



















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
