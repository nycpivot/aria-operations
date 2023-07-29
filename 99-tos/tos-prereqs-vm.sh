#!/bin/bash

sudo apt update
yes | sudo apt upgrade

#PERSIST ENV VARIABLES
#envs=$(cat /etc/environment) | tr -d '"'
#envs=PATH="${envs}:/usr/lib/java/jdk-17/bin:/usr/lib/maven/apache-maven-3.8.4/bin:/snap/dotnet-sdk/current"
#echo $envs >> envs
#echo JAVA_HOME="/usr/lib/java/jdk-17" >> envs
#sudo rm /etc/environment
#sudo mv envs /etc/environment

#INSTALL JAVA
wget https://download.java.net/java/GA/jdk17/0d483333a00540d886896bac774ff48b/35/GPL/openjdk-17_linux-x64_bin.tar.gz
gzip -d openjdk-17_linux-x64_bin.tar.gz
tar -xvf openjdk-17_linux-x64_bin.tar

sudo mkdir /usr/lib/java
sudo mv jdk-17 /usr/lib/java/jdk-17
rm openjdk-17_linux-x64_bin.tar

export PATH=$PATH:/usr/lib/java/jdk-17/bin
export JAVA_HOME=/usr/lib/java/jdk-17

#INSTALL MAVEN
wget https://dlcdn.apache.org/maven/maven-3/3.9.3/binaries/apache-maven-3.9.3-bin.tar.gz
gzip -d apache-maven-3.9.3-bin.tar.gz
tar -xvf apache-maven-3.9.3-bin.tar

sudo mkdir /usr/lib/maven
sudo mv apache-maven-3.9.3 /usr/lib/maven
rm apache-maven-3.9.3-bin.tar

export PATH=$PATH:/usr/lib/maven/apache-maven-3.9.3/bin

#INSTALL DOTNET
#sudo snap install dotnet-sdk --classic
#sudo snap alias dotnet-sdk.dotnet dotnet
#sudo snap install dotnet-runtime-60 --classic
#sudo snap alias dotnet-runtime-60.dotnet dotnet

#export DOTNET_ROOT=/snap/dotnet-sdk/current

#INSTALL GO
#wget https://go.dev/dl/go1.17.8.linux-amd64.tar.gz
sudo snap install go --classic

#CLONE SOME REPOS
#cd tos
#rm -rf spring-petclinic

#git clone https://github.com/nycpivot/tanzu-spring-petclinic
