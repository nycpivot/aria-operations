#!/bin/bash

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

read -p "App Name (tap-dotnet-core-api-weather): " app_name
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-core-api-weather
fi

tap_build=tap-build
tap_run_aks=tap-run-aks
tap_run_aks_domain=run-aks

if [ ! -d "${HOME}/${app_name}" ]
then
  mkdir -p ${HOME}/${app_name}
fi
