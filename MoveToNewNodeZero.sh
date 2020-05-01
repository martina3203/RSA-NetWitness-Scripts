#!/bin/bash
#Written by Aaron Martin (Aaron.M.Martin@rsa.com)
#This script allows for the quick removal and rediscovery of a host in NetWitness after being moved to a new head node
#This script is written to be version agnostic.
#Please note that at this time, this script is only certified for core devices

echo "Please ensure you DO NOT run this on the Admin Server. If you have by mistake, please hit Ctrl + C now to break out now."
echo "Please be aware that during yum steps, you may see errors saying 'md5 was not found.' These are expected."
read -p "Press enter to continue"

#sanity checks to make sure this is not an Admin Server, otherwise we are quitting.
if grep "node-zero" /etc/netwitness/platform/nw-node-type; then 
    echo "Script detected this is not a valid host to run this script on after reviewing /etc/netwitness/platform/nw-node-type. Exitting..."
    exit 0
fi
if rpm -qa | grep "admin-server"; then
    echo "Detected Admin Server rpms on host. Please confirm this is not an Admin Server before attempting again. Exitting..."
    exit 0
fi 

DESTINATION_FOLDER="/tmp/PreviousNodeZeroFiles"
echo "All files will be moved to $DESTINATION_FOLDER"
mkdir -p $DESTINATION_FOLDER
mkdir -p $DESTINATION_FOLDER/ng
mkdir -p $DESTINATION_FOLDER/systemd

#Forcing a clean of yum to make sure we get correct rpm information.
yum clean all -q 2> /dev/null

#We are checking for a mongo instance. We will be changing the password before proceeding.
if systemctl list-units --all | grep mongod ; then
    echo "A Mongo Instance has been detected on this device. Please provide the deployment password of the old environment so that we may login to mongo to change it to match the deployment password of the new environment."
    echo "If you are unsure about the old password, please use KB 000037015 to reset the Mongo password in the backend then rerun this script."
    echo "If the password is the same because it just is or you have already changed the password, just type the same password twice."
    read -p 'Current Deployment password currently being used by the mongo: ' oldPassword
    read -p 'New Deployment password: ' newPassword
    mongo -u deploy_admin -p "${oldPassword}" --authenticationDatabase admin --eval "db=db.getSiblingDB(\"admin\");db.changeUserPassword(\"deploy_admin\",\"${newPassword}\")" \
    || echo "Failed to change deploy_admin password in mongo server...please use KB 000037015 to reset the Mongo password in the backend before trying the script again."; exit
    mkdir -p /etc/netwitness/platform/mongo
    touch /etc/netwitness/platform/mongo/mongo.registered
fi

#Stop any relevant services
serviceNames=("nwappliance" "nwlogcollector" "nwlogdecoder" "nwconcentrator" "nwbroker" "nwarchiver" "nwdecoder" "mongod" "rabbitmq-server" "rsa-nw-contexthub-server" "rsa-nw-correlation-server" "rsa-nw-esa-analytics-server" "rsa-nw-node-infra-server")
echo "Stopping services before going further. If this seems like it can be stuck for an excessive amount of time, you may Ctrl + C and rerun the script after you manually stop them."
for service in ${serviceNames[@]}; do
    if systemctl is-active --quiet $service ; then
        echo "Stopping $service... This may take some time."
        systemctl stop $service
    fi
done

mv /etc/salt/pki/minion/minion_master.pub $DESTINATION_FOLDER/salt

#This section covers the directories that are common to all host.
commonDirectories=("/etc/netwitness/platform" "/etc/netwitness/security-cli" "/etc/pki/nw")
for directory in ${commonDirectories[@]}; do
    if [ -d $directory ]; then
        echo "Moving $directory to $DESTINATION_FOLDER"
        mv $directory $DESTINATION_FOLDER/ng
    else
        echo "$directory not detected. Skipping..."
    fi
done

#The following section covers the truststores of the Core services
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
    echo "Moving $infraServerDirectory to $DESTINATION_FOLDER"
    mv $infraServerDirectory $DESTINATION_FOLDER
    mv /etc/systemd/system/rsa-nw-node-infra-server.service.d/* $DESTINATION_FOLDER/systemd
    systemctl daemon-reload
fi

#This section covers the launch services I have developed a method to deal with. Not all will be here, if any. This is still a work in progress but I'll leave it in here.
contexthubServerDirectory="/etc/netwitness/contexthub-server"
if [ -d $contexthubServerDirectory ]; then
    echo "Moving $contexthubServerDirectory to $DESTINATION_FOLDER"
    mv $contexthubServerDirectory $DESTINATION_FOLDER
    mv /etc/systemd/system/rsa-nw-contexthub-server.service.d/* $DESTINATION_FOLDER/systemd
    systemctl daemon-reload
fi

correlationServerDirectory="/etc/netwitness/correlation-server"
if [ -d $correlationServerDirectory ]; then
    echo "Moving $correlationServerDirectory to $DESTINATION_FOLDER"
    mv $correlationServerDirectory $DESTINATION_FOLDER
    mv /etc/systemd/system/rsa-nw-correlation-server.service.d/* $DESTINATION_FOLDER/systemd
    systemctl daemon-reload
fi

esaAnalyticsServerDirectory="/etc/netwitness/esa-analytics-server"
if [ -d $esaAnalyticsServerDirectory ]; then
   echo "Moving $esaAnalyticsServerDirectory to $DESTINATION_FOLDER"
   mv $esaAnalyticsServerDirectory $DESTINATION_FOLDER
   mv /etc/systemd/system/rsa-nw-esa-analytics-server.service.d/* $DESTINATION_FOLDER/systemd
   systemctl daemon-reload
fi

endpointServerDirectory="/etc/netwitness/endpoint-server"
if [ -d $endpointServerDirectory ]; then
   echo "Moving $endpointServerDirectory to $DESTINATION_FOLDER"
   echo "Please note that for this specific service, a redeployment of the agents may be expected."
   mv $endpointServerDirectory $DESTINATION_FOLDER
   mv /etc/systemd/system/rsa-nw-endpoint-server.service.d/* $DESTINATION_FOLDER/systemd
   systemctl daemon-reload
fi

echo "Please also note that if you have ever had to make workarounds in the chef recipes, you will need to reapply them accordingly."
echo "The backing up and moving of files is now complete. Please rerun nwsetup-tui to discover the host on the new Admin Node."