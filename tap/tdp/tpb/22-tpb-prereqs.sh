#!/bin/bash

# INSTALL
echo "<<< INSTALLING NVM >>>"
echo
nvm install node
echo

echo
echo "<<< INSTALLING TYPESCRIPT"
npm install --global typescript
echo

echo "<<< INSTALLING YARN >>>"
echo
npm install --global yarn
yarn add tsc #typescript compiler
yarn add build
echo

echo "<<< INSTALLING VERDACCIO >>>"
echo
npm install --global verdaccio
echo

echo "<<< INSTALLING BACKSTAGE CLI >>>"
echo
npm install --global @backstage/cli
echo

# RUN LOCAL NPM REGISTRY
echo "<<< RUNNING VERDACCIO >>>"
echo
verdaccio
echo

echo "<<< ADD LOCAL NPM USER >>>"
echo
npm adduser --registry http://localhost:4873/
echo

sed -i 's+https://registry.npmjs.org/+https://artifactory.eng.vmware.com/artifactory/api/npm/tpb-npm-local/+g' verdaccio/config.yaml

# sudo reboot
