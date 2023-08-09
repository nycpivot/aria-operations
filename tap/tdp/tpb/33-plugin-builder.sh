#!/bin/bash

rm -rf tdp-core
git clone https://gitlab.eng.vmware.com/esback/core.git


yarn tsc
yarn build
