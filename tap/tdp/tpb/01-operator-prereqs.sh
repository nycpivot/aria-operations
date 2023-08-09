#!/bin/bash

sudo apt update
yes | sudo apt upgrade

#DOCKER
yes | sudo apt install docker.io
sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER

#NVM
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

#DEMO-MAGIC
wget https://raw.githubusercontent.com/paxtonhare/demo-magic/master/demo-magic.sh
sudo mv demo-magic.sh /usr/local/bin/demo-magic.sh
chmod +x /usr/local/bin/demo-magic.sh

sudo apt install pv #required for demo-magic

sudo reboot
