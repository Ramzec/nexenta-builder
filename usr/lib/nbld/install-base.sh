#!/bin/bash
#
# Copyright 2005-2012 Nexenta Systems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# Installation script generated by bootstrap.sh

PATH=/usr/gnu/bin:/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH

test "x$1" = x && exit 1
test "x$2" = x && exit 1
test "x$3" = x && exit 1

if test "x$3" = "x1"; then
	mkdir -p /tmp/apt-archive.$$
	mkdir -p $1/var/cache/apt/archives/partial
	mount -F lofs /tmp/apt-archive.$$ $1/var/cache/apt/archives
fi
mkdir -p $1$2
mount -F lofs $2 $1$2


# required.lst and base.lst are symbolic links to the
# selected user profile
export APTINST=$(cat $2/aptinst.lst)
LOG="/tmp/install-base-debootstrap.log"
PKGSLOG="/tmp/installed_pkgs.log"

. $2/defaults

aborted()
{
    # $errlog is a global variable exported by nexenta-install.sh
    echo "$1" > $errlog
    exit 1
}

APT_FAILURE_MSG="Installation failed"

echo "Starting ..." >> $LOG
date >> $LOG
cat /etc/issue >> $LOG

TARGET="$1"

PKGSPATH="$2"

APT_GET="apt-get -R $TARGET"

echo "$APT_GET update" >> $LOG
$APT_GET update >> $LOG 2>&1 || aborted "Can't update packages list from the Install CD repo"

echo "$APT_GET install -y --force-yes sunwcsd" >> $LOG
$APT_GET install -y --force-yes sunwcsd >> $LOG 2>&1 || aborted "$APT_FAILURE_MSG"
echo "$APT_GET install -y --force-yes sunwcs bash dpkg apt-get" >> $LOG
$APT_GET install -y --force-yes sunwcs shell-bash package-dpkg package-dpkg-apt >> $LOG 2>&1 || aborted "$APT_FAILURE_MSG"
echo "$APT_GET install -y --force-yes $APTINST" | >> $LOG
$APT_GET install -y --force-yes $APTINST >> $LOG 2>&1 || aborted "$APT_FAILURE_MSG"

for pid in `ps -ef|nawk '/devfsadmd/ {print $2}'`; do
	if pfiles $pid 2>/dev/null | grep $1 >/dev/null; then
		kill -9 $pid 2>/dev/null
		break
	fi
done

sleep 2
umount $1/devices 2>/dev/null
umount -f $1$2 2>/dev/null
if test "x$3" = "x1"; then
	umount -f $1/var/cache/apt/archives
	rm -rf /tmp/apt-archive.$$
fi

cp $LOG $1/root
cp $PKGSLOG $1/root

# ntp client config
echo "Configuring NTP service ..." | tee -a $LOG
NTPCONFCONF="$1/etc/inet/ntp.conf"
echo "driftfile /etc/inet/ntp.drift" > $NTPCONFCONF
echo "server pool.ntp.org # default" >> $NTPCONFCONF
echo "server 0.pool.ntp.org" >> $NTPCONFCONF
echo "server 1.pool.ntp.org" >> $NTPCONFCONF
echo "server 2.pool.ntp.org" >> $NTPCONFCONF

exit 0
