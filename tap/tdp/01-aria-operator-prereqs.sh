#!/bin/bash

#NVM
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

nvm install --lts
npm install --global make
npm install --global yarn
