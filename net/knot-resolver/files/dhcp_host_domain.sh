#!/bin/sh

DEFAULT_RUNDIR=$(uci get resolver.kresd.rundir)
TMP_HINTS_CONFIG=$DEFAULT_RUNDIR/hosts.tmp
TTY_NUM=$(ls $DEFAULT_RUNDIR/tty/)


reload_hints () {
	local hosts=$1
	local dhcp_leases=$2
	local domain=$3
	local I=0

	echo "">$TMP_HINTS_CONFIG
	echo "hints.config('$TMP_HINTS_CONFIG')" | socat - UNIX-CONNECT:$DEFAULT_RUNDIR/tty/$TTY_NUM
	echo "#Do not edit">>$TMP_HINTS_CONFIG
	echo "#file generated from $hosts, $dhcp_leases and /etc/config/dhcp">>$TMP_HINTS_CONFIG

	#add hosts file
	cat $hosts>>$TMP_HINTS_CONFIG

	#add static domains from luci
	while [ true ]; do
		name=$(uci get dhcp.@domain[$I].name )
		ip=$(uci get dhcp.@domain[$I].ip )
		if [ ! "$?" -eq 0 ]; then
			break
		fi
		echo $ip $name.$domain>>$TMP_HINTS_CONFIG
		let I=I+1
	done

	#add dhcp dynamic domains
	while read line; do
		ip=$(echo "$line"|awk '{print $3}')
		name=$(echo "$line"|awk '{print $4}')
		if [ "$name" != '*' ]; then
			echo $ip $name.$domain>>$TMP_HINTS_CONFIG
		fi
	done <$dhcp_leases
	echo "hints.config('$TMP_HINTS_CONFIG')" | socat - UNIX-CONNECT:$DEFAULT_RUNDIR/tty/$TTY_NUM

}

dhcp_leases_file=$(uci get dhcp.@dnsmasq[0].leasefile)
hosts_file=$(uci get resolver.kresd.hostname_config)

expand_hosts=$(uci get dhcp.@dnsmasq[0].expandhosts)
local_domain=$(uci get dhcp.@dnsmasq[0].local| sed 's|/||g')
resolver=$(uci get resolver.common.prefered_resolver)

if [ "$expand_hosts" == "1" ] && [ "$resolver" == "kresd" ] && [ -f $dhcp_leases_file ]; then
	echo reload_hints  "$hosts_file" "$dhcp_leases_file" "$local_domain"
	reload_hints  "$hosts_file" "$dhcp_leases_file" "$local_domain"
fi

