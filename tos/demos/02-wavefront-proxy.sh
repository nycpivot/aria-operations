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

wavefront_prod_token=$(az keyvault secret show --name wavefront-prod-token --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

pe "docker run -d -e WAVEFRONT_URL=https://vmwareprod.wavefront.com -e WAVEFRONT_TOKEN=${wavefront_prod_token} -e JAVA_HEAP_USAGE=512m -p 2878:2878 wavefronthq/proxy:latest"
echo

read -p "Metric name (test.metric): " metric_name

if [ -z $metric_name ]
then
	metric_name=test.metric
fi

pe "echo -e \"${metric_name} 1 source=test.host\n\" | nc localhost 2878"
