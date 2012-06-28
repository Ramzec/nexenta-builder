#!/bin/sh
#
# Copyright 2005-2012 Nexenta Systems, Inc.  All rights reserved.
# Use is subject to license terms.
#
# Installation script generated by bootstrap.sh

PATH=/usr/gnu/bin:/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH

DEBCONF_FRONTEND=noninteractive
DEBCONF_NONINTERACTIVE_SEEN=true
export DEBCONF_FRONTEND DEBCONF_NONINTERACTIVE_SEEN

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
export BOOTSTRAP_REQUIRED=$(cat $1/var/tmp/required.lst)
export BOOTSTRAP_BASE=$(cat $1/var/tmp/base.lst)
export APTINST=$(cat $2/aptinst.lst)
export PKGSINST=$(cat $2/pkgs.lst)
LOG="/tmp/install-base-debootstrap.log"
PKGSLOG="/tmp/installed_pkgs.log"

source $2/defaults

echo "Starting ..." >> $LOG
date >> $LOG
cat /etc/issue >> $LOG

chrootenv="/usr/bin/env -i PATH=/usr/gnu/bin:/usr/bin:/sbin:/usr/sbin:/usr/loca/bin:/usr/local/sbin \
LOGNAME=root \
HOME=/root \
TERM=xterm"

TARGET="$1"

PKGSPATH="$2"

PKGS=" \
sunwcsd \
release-name \
sunwcs \
archiver-gnu-tar \
compress-gzip \
shell-bash \
nexenta-keyring \
library-security-libassuan \
package-dpkg-apt \
text-gnu-sed \
text-gnu-grep \
file-gnu-coreutils \
package-dpkg \
library-security-libgpg-error \
system-library-security-libgcrypt \
library-pth \
library-readline \
crypto-gnupg \
system-library-gcc-44-runtime \
library-gmp \
system-data-keyboard-keytables \
system-library \
system-library-storage-scsi-plugins \
compress-bzip2 \
system-library-math \
runtime-perl-510-extra \
library-zlib"

#runtime-perl-510 \
#runtime-perl-510-module-sun-solaris"

MAINPKGS="\
sunwcsd \
library-libtecla \
system-library \
system-library-gcc-44-runtime \
library-zlib \
system-boot-grub \
system-library-math \
sunwcs \
system-file-system-zfs \
library-security-trousers \
library-libxml2 \
compress-bzip2 \
package-dpkg \
library-security-openssl"

#runtime-perl-510 \
#text-gawk"

function getFile
{
    PKG=$1
    FILE=$PKG"_*.deb"
    PKGFILE=`find $PKGSPATH -name "$FILE"`
    echo "$PKGFILE"
}

function unpack
{
    PKG=$1
    TO=$2
    echo "Unpacking [$PKG] to [$TO] ..."
    dpkg-deb -x $PKG $TO
}

function dpkginst
{
    PKG=$2
    echo "Installing [$PKG] ..."
    chroot $1 $chrootenv dpkg --force-all -i $PKG
}

mkdir -p $TARGET/var/lib/dpkg/updates
mkdir -p $TARGET/var/lib/dpkg/info
mkdir -p $TARGET/var/lib/dpkg/alien
mkdir -p $TARGET/var/lib/dpkg/alternatives
mkdir -p $TARGET/var/lib/dpkg/parts
mkdir -p $TARGET/var/lib/dpkg/triggers

touch $TARGET/var/lib/dpkg/status
touch $TARGET/var/lib/dpkg/available
touch $TARGET/var/lib/dpkg/lock

LPKG=`getFile sunwcsd`
unpack $LPKG $TARGET 2>&1 | tee -a $LOG
LPKG=`getFile sunwcs`
unpack $LPKG $TARGET 2>&1 | tee -a $LOG

for package in $PKGS
do
    if [ "$package" = "sunwcsd" -o "$package" = "sunwcs" ]; then
	continue
    fi

    LPKG=`getFile $package`
    unpack $LPKG $TARGET 2>&1 | tee -a $LOG
    echo "$LPKG" >> $PKGSLOG
done


echo "== 1 - test -f $TARGET/etc/vfstab.sunwcs && mv $TARGET/etc/vfstab.sunwcs $TARGET/etc/vfstab" >> $LOG
test -f $TARGET/etc/vfstab.sunwcs && mv $TARGET/etc/vfstab.sunwcs $TARGET/etc/vfstab 2>&1 | tee -a $LOG
echo "== 1 - chroot $1 $chrootenv /sbin/mount -F proc /proc " >> $LOG
chroot $1 $chrootenv /sbin/mount -F proc /proc 2>&1 | tee -a $LOG

# hack chroot for utils
touch $1/dev/zero


chroot $1 $chrootenv crle -u -l /lib:/usr/lib 2>&1 | tee -a $LOG
chroot $1 $chrootenv crle -64 -u -l /lib/64:/usr/lib/64 2>&1 | tee -a $LOG

echo "deb file:///usr/nexenta/ ${_KS_inst_dist} main contrib non-free" > $1/etc/apt/sources.list

for package in $MAINPKGS
do
    LPKG=`getFile $package`
    dpkginst $1 $LPKG 2>&1 | tee -a $LOG
    echo "$LPKG" >> $PKGSLOG
done

echo "== 2 - chroot $1 $chrootenv mount -F proc /proc " >> $LOG
chroot $1 $chrootenv mount -F proc /proc 2>&1 | tee -a $LOG

echo "== chroot $1 $chrootenv apt-get update" >> $LOG
chroot $1 $chrootenv apt-get update 2>&1 | tee -a $LOG

echo "== chroot $1 $chrootenv apt-get -f -y --force-yes install " >> $LOG
chroot $1 $chrootenv apt-get -f -y --force-yes install 2>&1 | tee -a $LOG

APTCMD="apt-get -o APT::Get::AllowUnauthenticated=1 -o Debug::pkgDPkgProgressReporting=true -o Debug::pkgProblemResolver=true -y --force-yes install"

for package in nexenta-keyring text-locale; do
	echo "== chroot $1 $chrootenv $APTCMD $package" >> $LOG
	chroot $1 $chrootenv $APTCMD $package 2>&1 | tee -a $LOG
	echo "$package" >> $PKGSLOG
done

echo "== chroot $1 $chrootenv $APTCMD $PKGS" >> $LOG
chroot $1 $chrootenv $APTCMD $PKGS 2>&1 | tee -a $LOG
echo "$PKGS" >> $PKGSLOG

for package in archiver-gnu-tar compress-gzip; do
	echo "== chroot $1 $chrootenv $APTCMD $package" >> $LOG
	chroot $1 $chrootenv $APTCMD $package 2>&1 | tee -a $LOG
	echo "$package" >> $PKGSLOG
done

chroot $1 $chrootenv apt-get update 2>&1 | tee -a $LOG
chroot $1 $chrootenv apt-get install -f 2>&1 | tee -a $LOG

APTCMD="apt-get -o APT::Get::AllowUnauthenticated=1 -o Debug::pkgDPkgProgressReporting=true -o Debug::pkgProblemResolver=true -o APT::Immediate-Configure=false -y --force-yes install"
echo "== chroot $1 $chrootenv $APTCMD $APTINST" >> $LOG
chroot $1 $chrootenv $APTCMD $APTINST 2>&1 | tee -a $LOG
echo "$APTINST" >> $PKGSLOG

chroot $1 $chrootenv crle -u 2>&1 | tee -a $LOG
chroot $1 $chrootenv crle -64 -u 2>&1 | tee -a $LOG

chroot $1 $chrootenv apt-key update 2>&1 | tee -a $LOG
chroot $1 $chrootenv apt-get update 2>&1 | tee -a $LOG
chroot $1 $chrootenv dpkg --configure -a 2>&1 | tee -a $LOG
echo "== chroot $1 $chrootenv apt-get install -f -y --force-yes 2>&1" >> $LOG
chroot $1 $chrootenv apt-get install -f -y --force-yes 2>&1 | tee -a $LOG

chroot $1 $chrootenv umount /proc 2>&1 | tee -a $LOG

for pid in `ps -ef|awk '/devfsadmd/ {print $2}'`; do
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

cp -f $1/debootstrap/debootstrap.log $1/root
cp $LOG $1/root
cp $PKGSLOG $1/root

# ntp client config
NTPCONFCONF="$1/etc/inet/ntp.conf"
echo "driftfile /var/ntp/ntp.drift" > $NTPCONFCONF
echo "server pool.ntp.org # default" >> $NTPCONFCONF
echo "server 0.pool.ntp.org" >> $NTPCONFCONF
echo "server 1.pool.ntp.org" >> $NTPCONFCONF
echo "server 2.pool.ntp.org" >> $NTPCONFCONF

exit 0
