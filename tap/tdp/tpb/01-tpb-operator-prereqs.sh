#!/bin/bash

# INSTALL
nvm install node

npm install yarn
npm install --global verdaccio

# RUN LOCAL NPM REGISTRY
verdaccio

npm adduser --registry http://localhost:4873/
