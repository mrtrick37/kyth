#!/bin/bash

# Determine Linux Distro and Version
. /etc/os-release

linux_ver=${VERSION_ID:0:1}
echo "Linux Version: $ID $linux_ver"

# Install EPEL Repository
if [ "$ID" = "centos" ]; then
    sudo yum -y install epel-release
elif [ "$ID" = "rhel" ]; then
    if [ "$linux_ver" = "7" ]; then
        sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    elif [ "$linux_ver" = "8" ]; then
        sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    else
	echo "Error: Unsupported Linux version: $linux_ver"
    fi
else
    echo "Error: Unrecognized OS: $ID"
    exit
fi

# Install Qt5 Webkit (EPEL Repository)
echo "yum: Installing Qt5 WebKit and wmctrl..."
sudo yum -y install qt5-qtwebkit wmctrl
