#!/bin/bash
#Written by Aaron Martin (Aaron.M.Martin@rsa.com)
#This script allows for the quick removal and rediscovery of a host in NetWitness after being moved to a new head node
#This script is written to be version agnostic.
#Please note that at this time, this script is only certified for core devices

echo "Please ensure you DO NOT run this on the Admin Server. If you have by mistake, please hit Ctrl + C now to break out now."
echo "Please be aware that during yum steps, you may see errors saying 'md5 was not found.' These are expected."
echo "This script will resume in 20 seconds."
sleep 20

DESTINATION_FOLDER="/tmp/oldnodefiles-backup"
echo "All files will be moved to $DESTINATION_FOLDER"
mkdir -p $DESTINATION_FOLDER
mkdir -p $DESTINATION_FOLDER/salt
mkdir -p $DESTINATION_FOLDER/pki
mkdir -p $DESTINATION_FOLDER/ng
mkdir -p $DESTINATION_FOLDER/systemd

echo "Stopping the salt minion..."
systemctl stop salt-minion
mv /etc/salt/pki/minion/minion_master.pub $DESTINATION_FOLDER/salt
mv /etc/netwitness/platform $DESTINATION_FOLDER
mv /etc/netwitness/security-cli $DESTINATION_FOLDER
mv /etc/pki/nw $DESTINATION_FOLDER/pki

#Forcing a clean of yum to make sure we get the goods.
yum clean all -q

#Stop any relevant services
#echo "Stopping services before going further. If this seems like it can be stuck, you may Ctrl + C and rerun the script after you manually stop them."
#serviceNames=("nwappliance" "nwlogcollector" "nwlogdecoder" "nwconcentrator" "nwbroker" "nwarchiver" "nwdecoder" "mongod" "rabbitmq-server" "rsa-nw-contexthub-server" "rsa-nw-correlation-server" "rsa-nw-esa-analytics-server")
#for service in ${serviceNames[@]}; do 
#    if [ systemctl | grep $service ]; then
#        echo "Stopping $service... This may take some time."
#        systemctl stop $service
#    fi
#done

#The following section covers the truststores of the core services
coreServiceDirectoryList=("/etc/netwitness/ng/appliance" "/etc/netwitness/ng/logcollector" "/etc/netwitness/ng/logdecoder" "/etc/netwitness/ng/decoder" "/etc/netwitness/ng/broker" "/etc/netwitness/ng/archiver" "/etc/netwitness/ng/concentrator")
for directory in ${coreServiceDirectoryList[@]}; do
    if [ -d $directory ]; then
        echo "Moving $directory to $DESTINATION_FOLDER"
        mv $directory $DESTINATION_FOLDER/ng
    else
        echo "$directory not detected. Skipping..."
    fi
done

#This section covers the node infra service, if it exists. This was a change starting in the 11.4 release.
infraServerDirectory="/etc/netwitness/node-infra-server"
if [ -d $infraServerDirectory ]; then
    echo "Moving $infraServerDirectory to $DESTINATION_FOLDER and removing rpm for clean discovery"
    mv $infraServerDirectory $DESTINATION_FOLDER
    mv /etc/systemd/system/rsa-nw-node-infra-server.service.d/* $DESTINATION_FOLDER/systemd
    systemctl daemon-reload
    yum remove rsa-nw-node-infra-server -y -q
fi


#This section covers the launch services I have developed a method to deal with. Not all will be here, if any.
#ESA Primary
#mkdir -p /etc/netwitness/platform/mongo
#touch /etc/netwitness/platform/mongo/mongo.registered
#yum remove rsa-nw-contexthub-server rsa-nw-esa-analytics-server rsa-nw-correlation-server -y
#mv 
#mv /etc/systemd/system/rsa-nw-correlation-server.service.d/ /etc/systemd/system/rsa-nw-esa-analytics-server.service.d/ /etc/systemd/system/rsa-nw-contexthub-server.service.d/
#systemctl daemon-reload
#yum reinstall rsa-nw-esper-enterprise -y -q

echo "Reinstalling cookbooks and component-descriptor rpms to ensure that we can continue to reinstall. \
If this step fails and nwsetup-tui complains about missing cookbooks, you may need to find a way to do this manaully."
yum reinstall rsa-nw-config-management rsa-nw-component-descriptor -y -q
echo "Please also note that if you have ever had to make workarounds in the chef recipes, you will need to reapply them accordingly."
echo "The backing up and moving of files is now complete. Please rerun nwsetup-tui to discover the host on the new Admin Node."