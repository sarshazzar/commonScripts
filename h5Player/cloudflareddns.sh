#!/bin/bash
set -e;

ipv4Regex="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])"

proxy="true"

# DSM Config
username="$1"
password="$2"
hostname="$3"
ipAddr="$4"
ip6fetch=$(ip -6 addr show eth0 | grep -oP '(?<=inet6\s)[\da-f:]+')
ip6Addr=${ip6fetch:0:$((${#ip6fetch})) - 25}
rec6type="AAAA"

if [[ $ipAddr =~ $ipv4Regex ]]; then
    recordType="A";
else
    recordType="AAAA";
fi

listDnsApi="https://api.cloudflare.com/client/v4/zones/${username}/dns_records?type=${recordType}&name=${hostname}"
list6DnsApi="https://api.cloudflare.com/client/v4/zones/${username}/dns_records?type=${rec6type}&name=${hostname}"
createDnsApi="https://api.cloudflare.com/client/v4/zones/${username}/dns_records"

res6=$(curl -s -X GET "$list6DnsApi" -H "Authorization: Bearer $password" -H "Content-Type:application/json")
res=$(curl -s -X GET "$listDnsApi" -H "Authorization: Bearer $password" -H "Content-Type:application/json")

resSuccess=$(echo "$res" | jq -r ".success")
res6Success=$(echo "$res" | jq -r ".success")

if [ $resSuccess != "true" ] || [ $res6Success != "true" ]; then
    echo "badauth";
    exit 1;
fi

recordId=$(echo "$res" | jq -r ".result[0].id")
recordIp=$(echo "$res" | jq -r ".result[0].content")
recordId6=$(echo "$res6" | jq -r ".result[0].id")
recordIp6=$(echo "$res6" | jq -r ".result[0].content")

if [ $recordIp = "$ipAddr" ] && [ $recordIp6 = "$ip6Addr" ]; then
    echo "nochg";
    exit 0;
fi

if [ $recordId = "null" ]; then
    # Record not exists
        res=$(curl -s -X POST "$createDnsApi" -H "Authorization: Bearer $password" -H "Content-Type:application/json" --data "{\"type\":\"$recordType\",\"name\":\"$hostname\",\"content\":\"$ipAddr\",\"proxied\":$proxy}");
elif [ $recordId6 = "null" ]; then
        res6=$(curl -s -X POST "$createDnsApi" -H "Authorization: Bearer $password" -H "Content-Type:application/json" --data "{\"type\":\"$rec6type\",\"name\":\"$hostname\",\"content\":\"$ip6Addr\",\"proxied\":$proxy}");
elif [ $recordIp != "$ipAddr" ]; then
    updateDnsApi="https://api.cloudflare.com/client/v4/zones/${username}/dns_records/${recordId}";
    res=$(curl -s -X PUT "$updateDnsApi" -H "Authorization: Bearer $password" -H "Content-Type:application/json" --data "{\"type\":\"$recordType\",\"name\":\"$hostname\",\"content\":\"$ipAddr\",\"proxied\":$proxy}");
elif [ $recordIp6 != "$ip6Addr" ]; then
        update6DnsApi="https://api.cloudflare.com/client/v4/zones/${username}/dns_records/${recordId6}";
        res6=$(curl -s -X PUT "$update6DnsApi" -H "Authorization: Bearer $password" -H "Content-Type:application/json" --data "{\"type\":\"$rec6type\",\"name\":\"$hostname\",\"content\":\"$ip6Addr\",\"proxied\":$proxy}");
fi

resSuccess=$(echo "$res" | jq -r ".success")
res6Success=$(echo "$res6" | jq -r ".success")

if [ $resSuccess = "true" ] || [ $res6Success = "true" ]; then
    echo "good";
else
    echo "badauth";
fi
