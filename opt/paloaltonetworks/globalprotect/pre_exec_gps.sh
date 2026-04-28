#!/bin/bash
sleep 0.1
pid_file=/var/run/PanGPS.pid
if [ -f $pid_file ]
then
	rm $pid_file
else
	echo "no pid file"
fi
