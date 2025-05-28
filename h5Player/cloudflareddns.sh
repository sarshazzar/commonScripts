#!/bin/bash
# copyright:https://raw.githubusercontent.com/joshuaavalon/SynologyCloudflareDDNS/master/cloudflareddns.sh
set -e;
ipv6Regex="(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))"
ipv6="true"
# proxy="true" 
# ask for existing proxy, don't override it <.<

# DSM Config
username="$1"
password="$2"
hostname="$3"
ipAddr=$(ip addr show dev eth0 | grep -oE '[0-f]{0,4}\:[0-f]{0,4}\:[0-f]{0,4}\:[0-f]{0,4}\:[0-f]{0,4}\:[0-f]{0,4}\:[0-f]{0,4}\:[0-f]{0,4}')
recType6="AAAA"

#Fetch and filter IPv6, if Synology won't provide it
if [[ $ipv6 = "true" ]]; then
    # ip6fetch=$(ip -6 addr show eth0 | grep -oP "$ipv6Regex" || true)
    # Look out: `ip -6 addr show {your ipv6 network card} [filter your one ipv6 addr] `
    ip6fetch=$(ip -6 addr show ovs_eth0 | grep -oE "$ipv6Regex" | head -n 1 || true)
    # ip6Addr=$(if [ -z "$ip6fetch" ]; then echo ""; else echo "${ip6fetch:0:$((${#ip6fetch})) - 7}"; fi) # in case of NULL, echo NULL
    # Look out: ip6Addr final output your public ipv6 addr
    ip6Addr=$(if [ -z "$ip6fetch" ]; then echo ""; else echo "${ip6fetch}"; fi) # in case of NULL, echo NULL
    if [[ -z "$ip6Addr" ]]; then
        ipv6="false";     # if only ipv4 is available
        echo "not obtain ipv6 addr";
        exit 1;
    fi
else
    echo "not obtain ipv6 addr";
    exit 1;
fi

# above only, if IPv4 and/or IPv6 is provided
listDnsv6Api="https://api.cloudflare.com/client/v4/zones/${username}/dns_records?type=${recType6}&name=${hostname}" # if only IPv4 is provided

resv6=$(curl -s -X GET "$listDnsv6Api" -H "Authorization: Bearer $password" -H "Content-Type:application/json");
resSuccess=$(echo "$resv6" | jq -r ".success")

if [[ $resSuccess != "true" ]]; then
    echo "badauth";
    exit 1;
fi

recordIdv6=$(echo "$resv6" | jq -r ".result[0].id");
recordIpv6=$(echo "$resv6" | jq -r ".result[0].content");
recordProxv6=$(echo "$resv6" | jq -r ".result[0].proxied");


# API-Calls for creating DNS-Entries
createDnsApi="https://api.cloudflare.com/client/v4/zones/${username}/dns_records" # does also work for IPv6


# API-Calls for update DNS-Entries
updateDnsApi="https://api.cloudflare.com/client/v4/zones/${username}/dns_records/${recordId}" # for IPv4 or if provided IPv6
update6DnsApi="https://api.cloudflare.com/client/v4/zones/${username}/dns_records/${recordIdv6}" # if only IPv4 is provided

if [[ $recordIpv6 = "$ip6Addr" ]]; then
    echo "nochg";
    exit 0;
fi


if [[ $recordIdv6 = "null" ]]; then
    # IPv6 Record not exists
    proxy="false"; # new entry, enable proxy by default
    res6=$(curl -s -X POST "$createDnsApi" -H "Authorization: Bearer $password" -H "Content-Type:application/json" --data "{\"type\":\"$recType6\",\"name\":\"$hostname\",\"content\":\"$ip6Addr\",\"proxied\":$proxy}");
else
    # IPv6 Record exists
    res6=$(curl -s -X PUT "$update6DnsApi" -H "Authorization: Bearer $password" -H "Content-Type:application/json" --data "{\"type\":\"$recType6\",\"name\":\"$hostname\",\"content\":\"$ip6Addr\",\"proxied\":$recordProxv6}");
fi;
res6Success=$(echo "$res6" | jq -r ".success");


if [[ $res6Success = "true" ]]; then
    echo "good";
else
    echo "badauth";
fi
