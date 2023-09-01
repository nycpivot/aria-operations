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
TYPE_SPEED=15

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
#DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# hide the evidence
clear

DEMO_PROMPT="${GREEN}➜ TAP ${CYAN}\W "

pe "tanzu service class-claim create weather-db --class postgresql-unmanaged --parameter storageGB=2"
echo

echo "Press Ctrl+C when claim is ready..."
echo

kubectl get classclaims -w
echo

# claim_secret=$(kubectl get classclaim weather-db -ojson | jq -r .status.resourceRef.name)
claim_reference=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:weather-db
service_ref=db=${claim_reference}
