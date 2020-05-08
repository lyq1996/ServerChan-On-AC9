#!/bin/sh
export PATH='/usr/sbin:/usr/bin:/sbin:/bin'

# Paraments
resub=1

# Push online devices
push_devices="0"

# Push ddns message
push_ddns="1"

# Enable ServerChan
serverchan_enable="1"

# ServerChan api key
serverchan_sckey=""

# Your CloudFlare API Key
api_key=""

# Your CloudFlare User account
cf_user_name=""

# Zone name, e.g. example.com
zone_name=""

# Your DNS record name, e.g. sub.example.com
record_name=""

# TTL in seconds (1=auto)
record_ttl="1"

touch /tmp/home/root/lastIPAddress
[ ! -s /tmp/home/root/lastIPAddress ] && echo "爷刚启动！" > /tmp/home/root/lastIPAddress

touch /tmp/home/root/pushDevice
[ ! -s /tmp/home/root/pushDevice ] && echo "$push_devices" > /tmp/home/root/pushDevice

# Get wan IP
# Check curl exist, if not, use wget
get_ip_addr() {
    curl_test=`which curl`
    if [ -z "$curl_test" ] || [ ! -s "`which curl`" ] ; then
        wget --no-check-certificate --quiet --output-document=- "http://members.3322.org/dyndns/getip"
    else
        curl -k -s "http://members.3322.org/dyndns/getip"
    fi
}
# load last IP
last_ip_addr() {
        local inter="/tmp/home/root/lastIPAddress"
        cat $inter
}

ddns_update() {
    ip_addr=${1}
    # Fetch Zone ID
    response=$(
        curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone_name" \
        -H "X-Auth-Email: $cf_user_name" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type:application/json"
    )
    zone_id=$(echo ${response} | sed -n "s/.*\"id\":\"\([^\"]*\)\".*\"name\":\"${zone_name}\".*/\1/p")

    # Fetch DNS record ID  
    response=$(
        curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=$record_name" \
        -H "X-Auth-Email: $cf_user_name" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type:application/json"
    )
    record_id=$(echo ${response} | sed -n "s/.*\"id\":\s\"\([^\"]*\)\".*\"name\":\s\"${record_name}\".*/\1/p")

    # Update DNS record
    response=$(
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/$record_id" \
        -H "X-Auth-Email: $cf_user_name" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type: application/json" \
        --data "{\"id\":\"$zone_id\",\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip_addr\", \"ttl\":$record_ttl},\"proxied\":false}"
    )

    # Check whether the update was successful
    echo $response | grep '"success":\ *true' >/dev/null

    if [ $? -eq 0 ]; then
        logger -t "ddns" "Cloudflare ddns updated"
		return 0
    else
        logger -t "ddns" "Cloudflare ddns updated failed"
		return 1
    fi
}

# Get online devices
push_online(){
	alias=`cat /var/lib/misc/dnsmasq.leases`
	arp | sed 's/(//;s/)//' | while read -r DESC IP AT MAC ETH ON IFACE
	do
	    if [ $IFACE ]; then
		NAME=`echo "$alias" | awk '/'$MAC'\ '$IP'/{print $4}'`
        echo $NAME $IP >> /tmp/home/root/newhostname.txt
		fi
	done
}

while [ "$serverchan_enable" = "1" ];
do
    curl_test=`which curl`
    if [ -z "$curl_test" ] ; then
        wget --continue --no-check-certificate  -q -T 10 http://www.baidu.com
	    [ "$?" == "0" ] && check=200 || check=404
    else
        check=`curl -k -s -w "%{http_code}" "http://www.baidu.com" -o /dev/null`
    fi

    if [ "$check" == "200" ] ; then
        local hostIP=$(get_ip_addr)
        local lastIP=$(last_ip_addr)

        if [ "$lastIP" != "$hostIP" ] && [ ! -z "$hostIP" ] ; then
	        sleep 60
            # Check again
	        local hostIP=$(get_ip_addr)
            local lastIP=$(last_ip_addr)
        fi

        if [ "$lastIP" != "$hostIP" ] && [ ! -z "$hostIP" ] ; then
            logger -t "公网IP变动" "目前 IP: ${hostIP}"
            logger -t "公网IP变动" "上次 IP: ${lastIP}"
            ddns_update ${hostIP}
            if [ "$?" == "0" ] ; then
                if [ "$push_ddns" = "1" ] ; then
                    curl -s "http://sc.ftqq.com/$serverchan_sckey.send?text=AC9的DDNS更新啦" -d "&desp=${hostIP}" &
                    logger -t "wechat push" "IP: ${hostIP} pushed"
                fi
                echo -n $hostIP > /tmp/home/root/lastIPAddress
            fi
        fi

        if [ `cat /tmp/home/root/pushDevice` = "1" ] ; then
            # 设备上、下线提醒
            # 获取接入设备名称
            touch /tmp/home/root/newhostname.txt
            echo "接入设备名称" > /tmp/home/root/newhostname.txt	
            # 当前所有接入设备
            push_online
            # cat /tmp/syslog.log | grep 'Found new hostname' | awk '{print $7" "$8}' >> /tmp/home/root/newhostname.txt	# MAC and IP
            # cat /tmp/static_ip.inf | grep -v "^$" | awk -F "," '{ if ( $6 == 0 ) print "【内网IP:"$1", MAC:"$2", 名称:"$3"】"}' >> /tmp/home/root/newhostname.txt
            # 读取已在线设备名称
            touch /tmp/home/root/hostname_online.txt
            [ ! -s /tmp/home/root/hostname_online.txt ] && echo "接入设备名称" > /tmp/home/root/hostname_online.txt
            # 上线
            # awk 'NR==FNR{a[$0]++} NR>FNR&&!a[$0]' /tmp/home/root/hostname_online.txt /tmp/home/root/newhostname.txt > /tmp/home/root/newhostname_uniqe_online.txt
            awk 'NR==FNR{a[$0]++} NR>FNR&&a[$0]' /tmp/home/root/hostname_online.txt /tmp/home/root/newhostname.txt > /tmp/home/root/newhostname_same_online.txt
            awk 'NR==FNR{a[$0]++} NR>FNR&&!a[$0]' /tmp/home/root/newhostname_same_online.txt /tmp/home/root/newhostname.txt > /tmp/home/root/newhostname_uniqe_online.txt
            if [ -s "/tmp/home/root/newhostname_uniqe_online.txt" ] ; then
                content=`cat /tmp/home/root/newhostname_uniqe_online.txt | grep -v "^$"`
                curl -s "http://sc.ftqq.com/$serverchan_sckey.send?text=AC9有设备上线啦" -d "&desp=${content}" &
                logger -t "wechat push" "设备上线: ${content} pushed"
                cat /tmp/home/root/newhostname_uniqe_online.txt | grep -v "^$" >> /tmp/home/root/hostname_online.txt
            fi
            # 下线
            awk 'NR==FNR{a[$0]++} NR>FNR&&!a[$0]' /tmp/home/root/newhostname.txt /tmp/home/root/hostname_online.txt > /tmp/home/root/newhostname_uniqe_offline.txt
            if [ -s "/tmp/home/root/newhostname_uniqe_offline.txt" ] ; then
            content=`cat /tmp/home/root/newhostname_uniqe_offline.txt | grep -v "^$"`
            curl -s "http://sc.ftqq.com/$serverchan_sckey.send?text=AC9有设备下线啦" -d "&desp=${content}" &
            logger -t "wechat push" "设备下线: ${content} pushed"
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

