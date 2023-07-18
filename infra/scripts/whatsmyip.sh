#!/bin/sh

ipaddr=`curl -s https://whatsmyip.dev/api/ip | jq -r .addr`

AZD_IP_ADDRESS=$ipaddr export AZD_IP_ADDRESS
azd env set AZD_IP_ADDRESS $ipaddr
