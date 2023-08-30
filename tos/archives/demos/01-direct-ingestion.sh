#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

########################
# Configure the options
########################

#
# speed at which to simulate typing. bigger num = faster
#
TYPE_SPEED=20

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
#DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# hide the evidence
clear

DEMO_PROMPT="${GREEN}➜ TOS ${CYAN}\W "

project_name=01-spring-petclinic-direct-ingestion

wavefront_prod_token=$(az keyvault secret show --name wavefront-prod-token --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

export JAVA_HOME=/usr/lib/java/jdk-17
export PATH=$PATH:/usr/lib/java/jdk-17/bin
export PATH=$PATH:/usr/lib/maven/apache-maven-3.9.3/bin

#DOWNLOAD DEMO CODE
rm -rf tos/tanzu-observability
pe "git clone https://github.com/nycpivot/tanzu-observability tos/tanzu-observability"

pe "cat tos/tanzu-observability/${project_name}/pom.xml"
echo

pe "clear"

pe "echo wavefront.application.name=spring-petclinic-direct-ingestion >> tos/tanzu-observability/${project_name}/src/main/resources/application.properties"
pe "echo wavefront.application.service=spring-petclinic-direct-ingestion >> tos/tanzu-observability/${project_name}/src/main/resources/application.properties"
pe "echo management.metrics.export.wavefront.uri=https://vmwareprod.wavefront.com >> tos/tanzu-observability/${project_name}/src/main/resources/application.properties"
pe "echo management.metrics.export.wavefront.api-token=${wavefront_prod_token} >> tos/tanzu-observability/${project_name}/src/main/resources/application.properties"

pe "clear"
pe "cat tos/tanzu-observability/${project_name}/src/main/resources/application.properties"
echo
	
cd ${HOME}/tos/tanzu-observability/${project_name}
echo

chmod +x mvnw
pe "./mvnw spring-javaformat:apply"
echo

pe "./mvnw spring-boot:run"

cd $HOME