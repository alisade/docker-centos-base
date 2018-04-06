#!/bin/bash

## execute in a Docker container to build the tarball
##   docker run --privileged -i -t -v $PWD:/srv centos:centos6 /srv/build.sh

# close stdin
exec 0<&-

set -e -u -x

ARCH=`uname -p`
case $ARCH in
  i686) ARCH="i386";;
esac


DEST_IMG="/srv/centos511-$ARCH.tar"

rm -f ${DEST_IMG}

instroot=$(mktemp -d)
tmpyum=$(mktemp)

cat << EOF >  ${tmpyum}
[main]
debuglevel=2
exactarch=1
obsoletes=1
gpgcheck=1
plugins=1
installonly_limit=5
distroverpkg=centos-release

[c5-base]
name=CentOS-5 - Base
baseurl=http://vault.centos.org/5.11/os/$ARCH/
gpgcheck=1
gpgkey=http://vault.centos.org/RPM-GPG-KEY-CentOS-5

[c5-updates]
name=CentOS-5 - Updates
baseurl=http://vault.centos.org/5.11/updates/$ARCH/
gpgcheck=1
gpgkey=http://vault.centos.org/RPM-GPG-KEY-CentOS-5
EOF

## touch, chmod; /dev/null; /etc/fstab; 
mkdir ${instroot}/{dev,etc,proc}
mknod ${instroot}/dev/null c 1 3 
touch ${instroot}/etc/fstab

yum \
    -c ${tmpyum} \
    --disablerepo='*' \
    --enablerepo='c5-*' \
    --setopt=cachedir=${instroot}/var/cache/yum \
    --setopt=logfile=${instroot}/var/log/yum.log \
    --setopt=keepcache=1 \
    --setopt=diskspacecheck=0 \
    -y \
    --installroot=${instroot} \
    install \
    centos-release yum iputils coreutils which curl || echo "ignoring failed yum; $?"

cp /etc/resolv.conf ${instroot}/etc/resolv.conf

## yum/rpm on centos6 creates databases that can't be read by centos5's yum
## http://lists.centos.org/pipermail/centos/2012-December/130752.html
rm ${instroot}/var/lib/rpm/*
chroot ${instroot} /bin/rpm --initdb
chroot ${instroot} /bin/rpm -ivh --justdb '/var/cache/yum/*/packages/*.rpm'
rm -r ${instroot}/var/cache/yum/

chroot ${instroot} sh -c 'echo "NETWORKING=yes" > /etc/sysconfig/network'

## set timezone of container to UTC
chroot ${instroot} ln -f /usr/share/zoneinfo/Etc/UTC /etc/localtime

sed -i \
    -e '/^mirrorlist/d' \
    -e 's@^#baseurl=http://mirror.centos.org/centos/$releasever/@baseurl=http://vault.centos.org/5.11/@g' \
    ${instroot}/etc/yum.repos.d/CentOS*.repo

## epel
curl -f -L -o ${instroot}/tmp/RPM-GPG-KEY-EPEL-5 http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-5
curl -f -L -o ${instroot}/tmp/epel-release-5-4.noarch.rpm https://archives.fedoraproject.org/pub/archive/epel/5/i386/epel-release-5-4.noarch.rpm
chroot ${instroot} rpm --import /tmp/RPM-GPG-KEY-EPEL-5
chroot ${instroot} yum localinstall -y /tmp/epel-release-5-4.noarch.rpm
rm -f ${instroot}/tmp/epel-release-5-4.noarch.rpm ${instroot}/tmp/RPM-GPG-KEY-EPEL-5

chroot ${instroot} yum clean all

## clean up mounts ($instroot/proc mounted by yum, apparently)
umount ${instroot}/proc
rm -f ${instroot}/etc/resolv.conf

## xz gives the smallest size by far, compared to bzip2 and gzip, by like 50%!
## … but somewhere along the line Docker stopped supporting it.
# gzip was causing erros when bulding the docker images, had to go with just tar
chroot ${instroot} tar -cf - . > ${DEST_IMG}
