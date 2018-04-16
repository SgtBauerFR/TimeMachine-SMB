#!/bin/bash
## Install Samba 4.8.0 for Time Machine
## Author: Lionel Frey
## Version: 1.0

## History
## 1.0 - Ok 16/04/18

### Tested on Ubuntu Server LTS 16.04.04 64Bits

if [ "$(whoami)" != "root" ]
then
    sudo su -s "$0"
    exit
fi

echo "Tested on Mon Apr 16 2018
Clean install of Ubuntu Server LTS 16.04.04 64Bits
Software selection:
[*]- standard system utilities
[*]- openSSH Server
Post installation:
apt upgrade

Enjoy your new Time Machine !
Lionel Frey"

read -s -n1 -p "Press Any Key to Continue..."; echo

read -p "Please enter your samba desired username: " USERNAME

export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_TYPE=en_US.UTF-8

apt install -y libreadline-dev git build-essential libattr1-dev libblkid-dev 
apt install -y autoconf python-dev python-dnspython libacl1-dev gdb pkg-config libpopt-dev libldap2-dev 
apt install -y dnsutils acl attr libbsd-dev docbook-xsl libcups2-dev libgnutls28-dev
apt install -y tracker libtracker-sparql-1.0-dev libpam0g-dev libavahi-client-dev libavahi-common-dev bison flex
apt install -y avahi-daemon

sudo cat << EOF > /etc/avahi/services/timemachine.service
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
 <name replace-wildcards="yes">%h</name>
 <service>
   <type>_smb._tcp</type>
   <port>445</port>
 </service>
 <service>
   <type>_device-info._tcp</type>
   <port>0</port>
   <txt-record>model=TimeCapsule8,119</txt-record>
 </service>
 <service>
   <type>_adisk._tcp</type>
   <txt-record>sys=waMa=0,adVF=0x100</txt-record>
   <txt-record>dk0=adVN=TimeMachine Home,adVF=0x82</txt-record>
 </service>
</service-group>
EOF

#read -s -n1 -p "Press Any Key to Continue..."; echo

cd /usr/src
wget https://download.samba.org/pub/samba/stable/samba-4.8.0.tar.gz
tar -xzvf samba-4.8.0.tar.gz
cd samba-4.8.0

#read -s -n1 -p "Press Any Key to Continue..."; echo

./configure --sysconfdir=/etc/samba --systemd-install-services --with-systemddir=/lib/systemd/system --with-shared-modules=idmap_ad --enable-debug --enable-selftest --with-systemd --enable-spotlight --jobs=`nproc --all`
make --jobs=`nproc --all`
make install --jobs=`nproc --all`

echo 'export PATH=/usr/local/samba/bin/:/usr/local/samba/sbin/:$PATH' >> /etc/profile
source /etc/profile

echo "[global]
# Basic Samba configuration
server role = standalone server
passdb backend = tdbsam
obey pam restrictions = yes
security = user
printcap name = /dev/null
load printers = no
socket options = TCP_NODELAY IPTOS_LOWDELAY SO_RCVBUF=524288 SO_SNDBUF=524288
server string = Samba Server %v
map to guest = bad user
dns proxy = no
wide links = yes
follow symlinks = yes
unix extensions = no
acl allow execute always = yes
log file = /var/log/samba/%m.log
max log size = 1000

# Special configuration for Apple's Time Machine
fruit:model = MacPro
fruit:advertise_fullsync = true
fruit:aapl = yes

## Definde your shares here
[TimeMachine Home]
path = /srv/backup/timemachine/%U
valid users = %U
writable = yes
durable handles = yes
kernel oplocks = no
kernel share modes = no
posix locking = no
vfs objects = catia fruit streams_xattr
ea support = yes
browseable = yes
read only = No
inherit acls = yes
fruit:time machine = yes
fruit:aapl = yes
spotlight = yes
create mask = 0600
directory mask = 0700
comment = Time Machine" > /etc/samba/smb.conf

mkdir -p /var/log/samba
mkdir -p /srv/backup/timemachine/
mkdir -m 700 /srv/backup/timemachine/$USERNAME
chown $USERNAME /srv/backup/timemachine/$USERNAME

sed -i 's/Type=notify/Type=simple/g' /lib/systemd/system/smb.service

echo "Check return Flags :
HAVE_AVAHI_CLIENT_CLIENT_H
HAVE_AVAHI_COMMON_WATCH_H
HAVE_AVAHI_CLIENT_NEW
HAVE_AVAHI_STRERROR
HAVE_LIBAVAHI_CLIENT
HAVE_LIBAVAHI_COMMON
WITH_AVAHI_SUPPORT
WITH_SPOTLIGHT
vfs_fruit_init"

smbd -b | grep -i avahi
#HAVE_AVAHI_CLIENT_CLIENT_H
#HAVE_AVAHI_COMMON_WATCH_H
#HAVE_AVAHI_CLIENT_NEW
#HAVE_AVAHI_STRERROR
#HAVE_LIBAVAHI_CLIENT
#HAVE_LIBAVAHI_COMMON
#WITH_AVAHI_SUPPORT
smbd -b | grep -i spotlight
#WITH_SPOTLIGHT
smbd -b | grep -i fruit
#vfs_fruit_init

echo "Please enter your samba desired password"
/usr/local/samba/bin/smbpasswd -a $USERNAME

systemctl enable smb.service; systemctl start smb.service
