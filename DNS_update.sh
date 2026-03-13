#!/bin/bash

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

auth_email="myEmail@home.com"
auth_key="ff403a4013adf1ba01a69c103511afafafaff"
zone_identifier="7afafafa3dab508f622afb753afafafaf"
ttl=1
proxy="true"

# Record names and their IDs
declare -A records
records=(
    ["agent.aaaaaa.com"]="9xxxxacc09b863dbd9a1785be52bf74"
    ["chat.aaaaaa.com"]="9xxxxacc09b863dbd9a1785be52bf74"
    ["comfy.aaaaaa.com"]="9xxxxacc09b863dbd9a1785be52bf74"
    ["esphome.aaaaaa.com"]="9xxxxacc09b863dbd9a1785be52bf74"

)

###########################################
## Get public IP
###########################################
ip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip' | cut -d'=' -f2)

if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ip=$(curl -s -4 https://api.ipify.org || curl -s -4 https://ipv4.icanhazip.com)
fi

if [[ ! $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    logger -s "DDNS Updater: Failed to find a valid IP."
    exit 2
fi

logger "DDNS Updater: Current IP is ${ip}"

###########################################
## Update all records
###########################################
success_count=0
fail_count=0

for record_name in "${!records[@]}"; do
    record_id="${records[$record_name]}"

    # Get current IP for this record
    current=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_identifier}/dns_records/${record_id}" \
        -H "X-Auth-Email: ${auth_email}" \
        -H "X-Auth-Key: ${auth_key}" \
        -H "Content-Type: application/json")

    old_ip=$(echo "${current}" | grep -oP '"content":"\K[^"]+' | head -1)

    if [[ "${ip}" == "${old_ip}" ]]; then
        logger "DDNS Updater: ${record_name} already up to date (${ip})"
        ((success_count++))
        continue
    fi

    # Update the record
    update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${zone_identifier}/dns_records/${record_id}" \
        -H "X-Auth-Email: ${auth_email}" \
        -H "X-Auth-Key: ${auth_key}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${record_name}\",\"content\":\"${ip}\",\"ttl\":${ttl},\"proxied\":${proxy}}")

    if [[ ${update} == *"\"success\":true"* ]]; then
        logger "DDNS Updater: ${record_name} updated to ${ip}"
        ((success_count++))
    else
        logger -s "DDNS Updater: Failed to update ${record_name}. Response: ${update}"
        ((fail_count++))
    fi
done

logger "DDNS Updater: Done. ${success_count} succeeded, ${fail_count} failed."
