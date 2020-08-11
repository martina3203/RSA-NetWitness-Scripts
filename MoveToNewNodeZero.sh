#!/bin/bash
#Written by Aaron Martin (Aaron.M.Martin@rsa.com)
#This script allows for the quick removal and rediscovery of a host in NetWitness after being moved to a new head node. 
#The order of operations is as follows. 
# 1. (Recommended) Remove the device from the previous environment, if possible.
# 2. Execute this script on the host you are trying to move. Do NOT run this on the Admin Server.
# 3. nwsetup-tui in install mode on the host and rediscovery it in the UI. If it says you have a backup to restore, don't use it. This is your 10.6 backup and in most cases should be removed.
# 4. Install the service in the GUI or command line of the Admin Server.
#This script is written to be version agnostic but is only meant with 11.3+ hosts in mind but I put logic just in case for 11.2 ESA's
#Please note that at this time, this script is only certified completely for core devices and your mileage may vary on other Launch devices like ESA and Endpoint.
#Just because the service installs does not mean you are done. You should check that every aspect of that service is functioning as expected a result.

echo "Please ensure you DO NOT run this on the Admin Server. If you have by mistake, please hit Ctrl + C now to break out now."
echo "Please also ensure that the Admin Server you are moving to is of the same Major Release before proceeding. For example, 11.3.X.X to 11.3.X.X"
read -p "Press enter to continue"

cleanLaunchService() {
    local launchDirectory=$1
    local serviceName=$2
    if [ -d $launchDirectory ]; then
        echo "Moving $launchDirectory to $DESTINATION_FOLDER"
        mv -f $launchDirectory $DESTINATION_FOLDER
        echo "Moving $serviceName service definition to $DESTINATION_FOLDER/systemd"
        mv -f /etc/systemd/system/$serviceName.service.d/* $DESTINATION_FOLDER/systemd
    fi
    #If we find special conditions for various launch services, we shall carry out those steps here.
    case $serviceName in
        "rsa-nw-endpoint-server")
            echo -e "/e[93mPlease note this process is not guaranteed to work on Endpoint Servers."
            echo "You should be expecting to redeploy the agents as a result." ;;
        "rsa-nw-correlation-server" | "rsa-nw-esa-server")
            echo "Please note that you may need to update the Incident Counter on the Admin Server if this device will be the new ESA Primary and the previous INC counter is at a lower value."
            echo "Please see the KB article where you found this script for more details on this process.";;
    esac
}

#sanity checks to make sure this is not an Admin Server, otherwise we are quitting.
if grep "node-zero" /etc/netwitness/platform/nw-node-type; then 
    echo -e "\e[91mScript detected this is not a valid host to run this script on after reviewing /etc/netwitness/platform/nw-node-type. Exiting..."
    exit 0
fi
if rpm -qa | grep "admin-server"; then
    echo -e "\e[91mDetected Admin Server rpms on host. Please confirm this is not an Admin Server before attempting again. Exiting..."
    exit 0
fi 

#This is the destination folder for all files that we are simply moving out.
DESTINATION_FOLDER="/tmp/PreviousNodeZeroFiles"
echo "All files will be moved to $DESTINATION_FOLDER"
mkdir -p $DESTINATION_FOLDER
mkdir -p $DESTINATION_FOLDER/ng
mkdir -p $DESTINATION_FOLDER/systemd

#Forcing a clean of yum to make sure we get correct rpm information.
yum clean all -q 2> /dev/null

#We are checking for a mongo instance. We will be changing the password before proceeding.
if systemctl list-units --all | grep -q mongod ; then
    echo "A Mongo Instance has been detected on this device. Please provide the deployment password of the old environment so that we may login to mongo to change it to match the deployment password of the new environment."
    echo "If you are unsure about the old password, please use KB 000037015 to reset the Mongo password in the backend then rerun this script."
    echo "If the password is the same because it just is or you have already changed the password, just type the same password twice."
    read -s -p 'Current Deployment password currently being used by the mongo: ' oldPassword
    echo ""
    read -s -p 'New Deployment password: ' newPassword
    if mongo -u deploy_admin -p "${oldPassword}" --authenticationDatabase admin --eval "db=db.getSiblingDB(\"admin\");db.changeUserPassword(\"deploy_admin\",\"${newPassword}\")" --quiet; then
        mkdir -p /etc/netwitness/platform/mongo
        touch /etc/netwitness/platform/mongo/mongo.registered
        echo -e "\e[93mPlease be sure that the empty file /etc/netwitness/platform/mongo/mongo.registered is created as a result of this command."
    else 
        echo -e "\e[91mUnable to change current mongodb password. Please confirm you have the correct password or follow KB article https://community.rsa.com/docs/DOC-100186 to change it in the backend for this host. Then, you may type the same password again twice for old and new."
        exit 1
    fi
fi

#Stop any relevant services
serviceNames=("salt-minion" "nwappliance" "nwlogcollector" "nwlogdecoder" "nwconcentrator" "nwbroker" "nwarchiver" "nwworkbench" "nwdecoder" "mongod" "rabbitmq-server" "rsa-nw-contexthub-server" "rsa-nw-correlation-server" "rsa-nw-esa-analytics-server" "rsa-nw-node-infra-server")
echo "Stopping services before going further. If this seems like it can be stuck for an excessive amount of time, you may Ctrl + C and rerun the script after you manually stop them."
for service in ${serviceNames[@]}; do
    if systemctl is-active --quiet $service ; then
        echo "Stopping $service... This may take some time."
        systemctl stop $service
    fi
done

#This resets the salt master public key that is stored on the device.
mv -f /etc/salt/pki/minion/minion_master.pub $DESTINATION_FOLDER/salt

#This section covers the directories that are common to all host.
commonDirectories=("/etc/netwitness/platform" "/etc/netwitness/security-cli" "/etc/pki/nw" "/etc/netwitness/orchestration-client")
for directory in ${commonDirectories[@]}; do
    if [ -d $directory ]; then
        echo "Moving $directory to $DESTINATION_FOLDER"
        mv -f $directory $DESTINATION_FOLDER
    else
        echo "$directory not detected. Skipping..."
    fi
done

#The following section covers the truststores of the Core services
coreServiceDirectoryList=("/etc/netwitness/ng/appliance" "/etc/netwitness/ng/logcollector" "/etc/netwitness/ng/logdecoder" "/etc/netwitness/ng/decoder" "/etc/netwitness/ng/broker" "/etc/netwitness/ng/archiver" "/etc/netwitness/ng/concentrator")
for directory in ${coreServiceDirectoryList[@]}; do
    if [ -d $directory ]; then
        echo "Moving $directory to $DESTINATION_FOLDER"
        mv -f $directory $DESTINATION_FOLDER/ng
    else
        echo "$directory not detected. Skipping..."
    fi
done

#The below seciton cleans up the launch entries and responds accordingly
cleanLaunchService /etc/netwitness/node-infra-server rsa-nw-node-infra-server
cleanLaunchService /etc/netwitness/contexthub-server rsa-nw-contexthub-server
cleanLaunchService /etc/netwitness/correlation-server rsa-nw-correlation-server
cleanLaunchService /etc/netwitness/esa-analytics-server rsa-nw-esa-analytics-server
cleanLaunchService /etc/netwitness/esa-server rsa-nw-esa-server
cleanLaunchService /etc/netwitness/endpoint-server rsa-nw-endpoint-server
systemctl daemon-reload

echo "The script execution is now complete. Please verify the following items before re-running nwsetup-tui in Install Mode:"
echo "Please ensure that the version of this device has a matching repo on the Admin Server/Web Repo. If not, please add one."
echo "Please remove any repo files in /etc/yum.repos.d that are pointing to older versions of NetWitness that are no longer relevant, such as 11.1.0.1."
echo "Please note that if you have ever had to make workarounds in the chef recipes, you will need to reapply them accordingly."
echo "The backing up and moving of files is now complete. Please rerun nwsetup-tui to discover the host on the new Admin Node."