#!/bin/bash

sudo apt update
yes | sudo apt upgrade

#DOCKER
yes | sudo apt install docker.io
sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER

sudo apt install unzip

#NVM
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
source .bashrc

nvm install --lts
npm install --global make
npm install --global yarn
