#!/bin/bash

nvm install --lts
npm install --global make
npm install --global yarn
npx @backstage/create-app@0.5.2

cd my-backstage
yarn dev
