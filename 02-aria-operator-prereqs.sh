#!/bin/bash

sudo apt update
yes | sudo apt upgrade

#DOCKER
yes | sudo apt install docker.io
sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER

#MISC TOOLS
sudo snap install jq
sudo snap install tree
sudo snap install helm --classic
sudo apt install unzip
#sudo apt install npm

sudo apt install python-is-python3
alias python=python3

yes | sudo apt install python3-pip
pip3 install yq

wget https://releases.hashicorp.com/terraform/0.13.0/terraform_0.13.0_linux_amd64.zip
unzip terraform_0.13.0_linux_amd64.zip
sudo mv terraform /usr/local/bin
rm terraform_0.13.0_linux_amd64.zip

#KREW
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

echo "export PATH='${KREW_ROOT:-$HOME/.krew}/bin:$PATH'" >> .bashrc

kubectl krew install tree
kubectl krew install lineage

#AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm awscliv2.zip

#AWS AUTHENTICATOR
curl -Lo aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.5.9/aws-iam-authenticator_0.5.9_linux_amd64
sudo mv aws-iam-authenticator /usr/local/bin
chmod +x /usr/local/bin/aws-iam-authenticator

#AWS EKSCTL
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
chmod +x /usr/local/bin/eksctl

#AZ CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az login
az account set --subscription nycpivot

#KUBECTL
sudo snap install kubectl --classic --channel=1.25/stable
kubectl version

#ISTIO
curl -sL https://istio.io/downloadIstioctl | sh -
export PATH=$PATH:$HOME/.istioctl/bin

# TSM CLI
# server_name=prod-2.nsxservicemesh.vmware.com
# tsm_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"tsm-token\")

# #wget https://prod-2.nsxservicemesh.vmware.com/allspark-static/binaries/tsm-cli-linux.tgz
# wget https://tsmcli.s3.us-west-2.amazonaws.com/tsm-cli-linux.tgz

# sudo tar xf tsm-cli-linux.tgz -C /usr/local/bin/

# tsm login -s $server_name -t $tsm_token

# EXTRAS, EXTRAS, EXTRAS

#DEMO-MAGIC
wget https://raw.githubusercontent.com/paxtonhare/demo-magic/master/demo-magic.sh
sudo mv demo-magic.sh /usr/local/bin/demo-magic.sh
chmod +x /usr/local/bin/demo-magic.sh

sudo apt install pv #required for demo-magic

# GITHUB CLI
# type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y)
# curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
# && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
# && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
# && sudo apt update \
# && sudo apt install gh -y

# git_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"github-token\")

# echo $git_token > git-token.txt

# https://external-secrets.io/v0.8.5/introduction/getting-started/
helm repo add external-secrets https://charts.external-secrets.io

echo
echo "***REBOOTING***"
echo

sudo reboot
