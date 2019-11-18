#!/bin/sh
export PATH='/etc/storage/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin'
export LD_LIBRARY_PATH=/lib:

# Paraments
resub=1
push1="1"	# Push online devices
serverchan_enable="1"	# enable ServerChan
serverchan_sckey=""	# server chan api key
APITOKEN="" # Your API Token
ZONEID=""           # Your zone id, hex16 string
RECORDNAME=""                         # Your DNS record name, e.g. sub.example.com
RECORDTTL="1"                                       # TTL in seconds (1=auto)

touch /tmp/home/root/lastIPAddress
[ ! -s /tmp/home/root/lastIPAddress ] && echo "爷刚启动！" > /tmp/home/root/lastIPAddress

# Get wan IP
# Check curl exist, if not, use wget
getIpAddress() {
    curltest=`which curl`
    if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
        wget --no-check-certificate --quiet --output-document=- "http://members.3322.org/dyndns/getip"
    else
        curl -k -s "http://members.3322.org/dyndns/getip"
    fi
}
# load last IP
lastIPAddress() {
        local inter="/tmp/home/root/lastIPAddress"
        cat $inter
}

ddnsUpdate() {
    IP=${1}
    # Fetch DNS record ID
    RESPONSE="$(
        curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONEID}/dns_records?page=1&#per_page=1000&order=type&direction=asc" \
        -H "Authorization: Bearer ${APITOKEN}" \
        -H "Content-Type:application/json"
    )"
    RECORDID="$(echo ${RESPONSE} | sed -n "s/.*\"id\":\"\([^\"]*\)\".*\"name\":\"${RECORDNAME}\".*/\1/p")"

    # Update DNS record
    RESPONSE="$(
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONEID}/dns_records/${RECORDID}" \
        -H "Authorization: Bearer ${APITOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${RECORDNAME}\",\"content\":\"${IP}\",\"ttl\":${RECORDTTL},\"proxied\":false}"
    )"

    # Check whether the update was successful
    echo $RESPONSE | grep '"success":\ *true' >/dev/null

    if [ $? -eq 0 ]; then
        logger -t "ddns" "Cloudflare ddns updated"
		return 0
    else
        logger -t "ddns" "Cloudflare ddns updated failed"
		return 1
    fi
}

# Get online devices
test(){
	alias=`cat /var/lib/misc/dnsmasq.leases`
	arp | sed 's/(//;s/)//' | while read -r DESC IP AT MAC ETH ON IFACE
    do
	    NAME=`echo "$alias" | awk '/'$MAC'\ '$IP'/{print $4}'`
        echo $NAME $IP $MAC >> /tmp/home/root/newhostname.txt
    done
}

while [ "$serverchan_enable" = "1" ];
do
curltest=`which curl`
if [ -z "$curltest" ] ; then
    wget --continue --no-check-certificate  -q -T 10 http://www.baidu.com
	[ "$?" == "0" ] && check=200 || check=404
else
    check=`curl -k -s -w "%{http_code}" "http://www.baidu.com" -o /dev/null`
fi

if [ "$check" == "200" ] ; then
local hostIP=$(getIpAddress)
local lastIP=$(lastIPAddress)

if [ "$lastIP" != "$hostIP" ] && [ ! -z "$hostIP" ] ; then
	sleep 60
    Check again
	local hostIP=$(getIpAddress)
    local lastIP=$(lastIPAddress)
 fi

if [ "$lastIP" != "$hostIP" ] && [ ! -z "$hostIP" ] ; then
    logger -t "公网IP变动" "目前 IP: ${hostIP}"
    logger -t "公网IP变动" "上次 IP: ${lastIP}"
	ddnsUpdate ${hostIP}
	if [ "$?" == "0" ] ; then
		curl -s "http://sc.ftqq.com/$serverchan_sckey.send?text=AC9:公网IP变动" -d "&desp=${hostIP}" &
		logger -t "wechat push" "pushed"
		echo -n $hostIP > /tmp/home/root/lastIPAddress
	fi
fi

if [ "$push1" = "1" ] ; then
    # 设备上、下线提醒
    # 获取接入设备名称
    touch /tmp/home/root/newhostname.txt
    echo "接入设备名称" > /tmp/home/root/newhostname.txt	
    # 当前所有接入设备
	test
	# cat /tmp/syslog.log | grep 'Found new hostname' | awk '{print $7" "$8}' >> /tmp/home/root/newhostname.txt	# MAC and IP
    # cat /tmp/static_ip.inf | grep -v "^$" | awk -F "," '{ if ( $6 == 0 ) print "【内网IP:"$1", MAC:"$2", 名称:"$3"】"}' >> /tmp/home/root/newhostname.txt
    # 读取已在线设备名称
    touch /tmp/home/root/hostname_online.txt
    [ ! -s /tmp/home/root/hostname_online.txt ] && echo "接入设备名称" > /tmp/home/root/hostname_online.txt
    # 上线设备
	# awk 'NR==FNR{a[$0]++} NR>FNR&&!a[$0]' /tmp/home/root/hostname_online.txt /tmp/home/root/newhostname.txt > /tmp/home/root/newhostname_uniqe_online.txt
    awk 'NR==FNR{a[$0]++} NR>FNR&&a[$0]' /tmp/home/root/hostname_online.txt /tmp/home/root/newhostname.txt > /tmp/home/root/newhostname_same_online.txt
    awk 'NR==FNR{a[$0]++} NR>FNR&&!a[$0]' /tmp/home/root/newhostname_same_online.txt /tmp/home/root/newhostname.txt > /tmp/home/root/newhostname_uniqe_online.txt
    if [ -s "/tmp/home/root/newhostname_uniqe_online.txt" ] ; then
		content=`cat /tmp/home/root/newhostname_uniqe_online.txt | grep -v "^$"`
		curl -s "http://sc.ftqq.com/$serverchan_sckey.send?text=【家中AC9有设备上线】" -d "&desp=${content}" &
		logger -t "wechat push" "设备上线:${content}"
		cat /tmp/home/root/newhostname_uniqe_online.txt | grep -v "^$" >> /tmp/home/root/hostname_online.txt
    fi
    # 下线
    awk 'NR==FNR{a[$0]++} NR>FNR&&!a[$0]' /tmp/home/root/newhostname.txt /tmp/home/root/hostname_online.txt > /tmp/home/root/newhostname_uniqe_offline.txt
    if [ -s "/tmp/home/root/newhostname_uniqe_offline.txt" ] ; then
       content=`cat /tmp/home/root/newhostname_uniqe_offline.txt | grep -v "^$"`
       curl -s "http://sc.ftqq.com/$serverchan_sckey.send?text=【家中AC9有设备下线】" -d "&desp=${content}" &
       logger -t "wechat push" "设备下线:${content}"
       cat /tmp/home/root/newhostname.txt | grep -v "^$" > /tmp/home/root/hostname_online.txt
    fi
fi
resub=`expr $resub + 1`
[ "$resub" -gt 360 ] && resub=1
else
logger -t "server chan" "Check network failed."
resub=1
fi
sleep 60
continue
done

