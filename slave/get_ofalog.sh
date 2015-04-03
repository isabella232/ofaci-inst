#!/bin/bash

BASE=${BASE:-/opt/stack}
OFALOGDIR=ofagent
OFALOGPATH=/tmp/${OFALOGDIR}
OFALOGFILE=${OFALOGPATH}/ofagent.log

function cp_if_exist {
    local logname=$1
    local dest=$2
    if [ -f "$logname" ]; then
        sudo cp $logname $dest/
    fi
}

mkdir -p $OFALOGPATH
cp_if_exist /var/log/openvswitch/ovs-ctl.log $OFALOGPATH
cp_if_exist /var/log/openvswitch/ovs-ctl.log.1 $OFALOGPATH
cp_if_exist /var/log/openvswitch/ovsdb-server.log $OFALOGPATH
cp_if_exist /var/log/openvswitch/ovsdb-server.log.1 $OFALOGPATH
cp_if_exist /var/log/openvswitch/ovs-vswitchd.log $OFALOGPATH
cp_if_exist /var/log/openvswitch/ovs-vswitchd.log.1 $OFALOGPATH

echo -e "\n>> ovs-appctl bridge/dump-flows br-int\n" >> $OFALOGFILE
sudo ovs-appctl bridge/dump-flows br-int >> $OFALOGFILE
echo -e "\n>> ovs-appctl dpif/show\n" >> $OFALOGFILE
sudo ovs-appctl dpif/show >> $OFALOGFILE
echo -e "\n>> ovs-ofctl -O openflow13 dump-ports-desc br-int\n" >> $OFALOGFILE
sudo ovs-ofctl -O openflow13 dump-ports-desc br-int >> $OFALOGFILE
echo -e "\n>> ovs-ofctl -O openflow13 dump-ports br-int\n" >> $OFALOGFILE
sudo ovs-ofctl -O openflow13 dump-ports br-int >> $OFALOGFILE
echo -e "\n>> ovs-ofctl -O openflow13 dump-flows br-int\n" >> $OFALOGFILE
sudo ovs-ofctl -O openflow13 dump-flows br-int >> $OFALOGFILE

sudo chown jenkins:jenkins -R $OFALOGPATH
pushd /tmp
tar czf ofagent_log.tar.gz $OFALOGDIR
sudo mv ofagent_log.tar.gz ${BASE}/logs/
rm -rf $OFALOGDIR
popd
