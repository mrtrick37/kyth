#!/bin/bash

echo "Start collecting..."


############################################
# Prepare directory

if [ "$USERNAME" == "root" ]; then
  gp_user_dir="$HOME"
else
  gp_user_dir=/home/"$USERNAME"
fi

gp_dir=/opt/paloaltonetworks/globalprotect

gpalog_dir=$(sed -n 's/.*<log-path-agent>\(.*\)<\/log-path-agent>.*/\1/p' ${gp_dir}/pangps.xml)
[ -z "${gpalog_dir}" ] && gpalog_dir="${gp_user_dir}"/.GlobalProtect

gpslog_dir=$(sed -n 's/.*<log-path-service>\(.*\)<\/log-path-service>.*/\1/p' ${gp_dir}/pangps.xml)
[ -z "${gpslog_dir}" ] && gpslog_dir=${gp_dir}

gplogs_tgz="${gpalog_dir}"/GlobalProtectLogs.tgz

tmp_dir="${gp_user_dir}"/.gp1234
[ ! -d "$tmp_dir" ] && mkdir -p "$tmp_dir"


############################################
# Collect TS files
echo "Collecting network info..."
/sbin/ip route > "$tmp_dir"/RoutePrint.txt
/sbin/ip -6 route >> "$tmp_dir"/RoutePrint.txt
/sbin/ip address > "$tmp_dir"/IfConfig.txt
/sbin/ip -6 address >> "$tmp_dir"/IfConfig.txt
/sbin/ip link show >> "$tmp_dir"/IpLink.txt

if [ -f "/bin/ss" ]; then
  /bin/ss -t -u -a > "$tmp_dir"/NetStat.txt
elif [ -f "/bin/netstat" ]; then
  /bin/netstat -t -u -a > "$tmp_dir"/NetStat.txt
fi

[ -n "$(which nmcli)" ] && nmcli dev show > "$tmp_dir"/networkinfo.txt

echo "Collecting machine info..."
/usr/bin/w > "$tmp_dir"/MachineState.txt
/bin/df -k >> "$tmp_dir"/MachineState.txt
/bin/ps axu >> "$tmp_dir"/MachineState.txt
if [ -f "/sbin/sysctl" ]; then
  /sbin/sysctl -a >> "$tmp_dir"/MachineState.txt
fi
ping -t 4 -c 3 www.google.com 2>> "$tmp_dir"/MachineState.txt >> "$tmp_dir"/MachineState.txt
ping -t 4 -c 3 www.paloaltonetworks.com 2>> "$tmp_dir"/MachineState.txt >> "$tmp_dir"/MachineState.txt
/usr/bin/top -S -n 1 -b > "$tmp_dir"/Top.txt

echo "Copying files..."
cp -f "${gpalog_dir}"/Pan*.log "$tmp_dir"/      > /dev/null 2>&1
cp -f "${gpalog_dir}"/Pan*.log.old "$tmp_dir"/  > /dev/null 2>&1
cp -f "${gpslog_dir}"/Pan*.log "$tmp_dir"/      > /dev/null 2>&1
cp -f "${gpslog_dir}"/Pan*.log.old "$tmp_dir"/  > /dev/null 2>&1
cp -f "${gpslog_dir}"/pan_gp_event.log "$tmp_dir"/  > /dev/null 2>&1
cp -f "${gpslog_dir}"/pan_gp_event.log.old "$tmp_dir"/  > /dev/null 2>&1
cp -f "${gpslog_dir}"/pan_gp_trb*.log "$tmp_dir"/  > /dev/null 2>&1
cp -f "${gpslog_dir}"/pan_gp_diag*.log "$tmp_dir"/  > /dev/null 2>&1
cp -f "${gpslog_dir}"/pan_gp_hrpt.xml "$tmp_dir"/  > /dev/null 2>&1
cp -f /var/log/syslog "$tmp_dir"                > /dev/null 2>&1
#cp -f /var/crash/*globalprotect* "$tmp_dir"/


echo "Generating final result file..."
cd "$tmp_dir"
tar -cvzf ${gplogs_tgz} * > /dev/null 2>&1
cd "${gp_user_dir}"
rm -rf "$tmp_dir"

echo "The support file is saved to ${gplogs_tgz}"
echo "Collection Complete"
