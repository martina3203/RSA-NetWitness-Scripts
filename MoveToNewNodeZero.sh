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

#This is where we will backup our files
DESTINATION_FOLDER="/tmp/PreviousNodeZeroFiles.`date +%Y-%b-%d-%H%M`"
COMMON_DIRECTORIES=("/etc/netwitness/platform" "/etc/netwitness/security-cli" "/etc/pki/nw" "/etc/netwitness/orchestration-client")
CORE_SERVICE_DIRECTORIES=("/etc/netwitness/ng/appliance" "/etc/netwitness/ng/logcollector" "/etc/netwitness/ng/logdecoder" "/etc/netwitness/ng/decoder" "/etc/netwitness/ng/broker" "/etc/netwitness/ng/archiver" "/etc/netwitness/ng/concentrator" )


#This function is reserved for cleaning the common launches services which generally have the same sort of steps that must be performed.
#I have created a case statement for these services for any special criteria that may be associated with them.
cleanLaunchService() {
    local launchDirectory=$1
    local serviceName=$2
    if [ -d $launchDirectory ]; then
        echo "Moving $launchDirectory to $DESTINATION_FOLDER"
        mv -f $launchDirectory $DESTINATION_FOLDER
        echo "Moving $serviceName service definition to $DESTINATION_FOLDER/systemd"
        mv -f /etc/systemd/system/$serviceName.service.d/* $DESTINATION_FOLDER/systemd
        #If we find special conditions for various launch services, we shall carry out those steps here.
        case $serviceName in
        "rsa-nw-endpoint-server")
            warning "Please note this process is not guaranteed to work on Endpoint Servers."
            warning "You may be expected to redeploy the agents as a result." 
            mkdir -p /etc/pki/nw/nwe-ca
            #We are putting the Endpoint Root CA certificates that we removed in bulk back so that we can resume agent connection, hopefully.
            cp $DESTINATION_FOLDER/nw/nwe-ca/nwerootca-cert.pem $DESTINATION_FOLDER/nw/nwe-ca/nwerootca-key.pem /etc/pki/nw/nwe-ca 
            chown -R netwitness:nwpki /etc/pki/nw ;;
        "rsa-nw-correlation-server" | "rsa-nw-esa-server")
            warning "Please note that you may need to update the Incident Counter on the Admin Server if this device will be the new ESA Primary and the previous INC counter is at a lower value."
            warning "Please see the KB article where you found this script for more details on this process.";;
        esac
    fi
}

#These functions are merely for my color coding messages
exitError() {
    echo -e "\e[91m$1\e[97m"
    exit 1
}

warning() {
    echo -e "\e[93m$1\e[97m"
}

#sanity checks to make sure this is not an Admin Server, otherwise we are quitting.
checkNotNodeZero() {
    warning "Please ensure you DO NOT run this on the Admin Server. If you have by mistake, please hit Ctrl + C now to break out now."
    warning "Please also ensure that the Admin Server you are moving to is of the same Major Release before proceeding. For example, 11.3.X.X to 11.3.X.X"
    read -p "Press enter to continue"
    if grep "node-zero" /etc/netwitness/platform/nw-node-type; then 
        exitError "Script detected this is not a valid host to run this script on after reviewing /etc/netwitness/platform/nw-node-type. Exiting..."
    fi
    if rpm -qa | grep "admin-server"; then
        exitError "Detected Admin Server rpms on host. Please confirm this is not an Admin Server before attempting again. Exiting..."
    fi 
}

echo "All files will be moved to $DESTINATION_FOLDER"
mkdir -p $DESTINATION_FOLDER/ng
mkdir -p $DESTINATION_FOLDER/systemd

#Forcing a clean of yum to make sure we get correct rpm information.

#We are checking for a mongo instance. We will be changing the password before proceeding to prevent error
checkMongo() {
    if systemctl list-units --all | grep -q mongod ; then
        echo "A Mongo Instance has been detected on this device. Please provide the deployment password of the old environment so that we may login to mongo to change it to match the deployment password of the new environment."
        echo "If you are unsure about the old password, please use KB 000037015 to reset the Mongo password in the backend then rerun this script."
        echo "If the password is the same because it just is or you have already changed the password, just type the same password twice."
        read -s -p 'Current Deployment password currently being used by the mongo: ' oldPassword
        echo ""
        read -s -p 'New Deployment password: ' newPassword
        mongo -u deploy_admin -p "${oldPassword}" --authenticationDatabase admin --eval "db=db.getSiblingDB(\"admin\");db.changeUserPassword(\"deploy_admin\",\"${newPassword}\")" || 
        exitError "Unable to change current mongodb password. Please confirm you have the correct password or follow KB article https://community.rsa.com/docs/DOC-100186 to change it in the backend for this host. Then, you may type the same password again twice for old and new."
        #Create the corresponding marker files
        mkdir -p /etc/netwitness/platform/mongo
        touch /etc/netwitness/platform/mongo/mongo.registered
    fi
}

#Stop any relevant services
stopServices() {
    serviceNames=("salt-minion" "nginx" "collectd" "nwappliance" "nwlogcollector" "nwlogdecoder" "nwconcentrator" "nwbroker" "nwarchiver" "nwworkbench" "nwdecoder" "mongod" "rabbitmq-server" "rsa-nw-contexthub-server" "rsa-nw-correlation-server" "rsa-nw-esa-analytics-server" "rsa-nw-node-infra-server")
    echo "Stopping services before going further. If this seems like it can be stuck for an excessive amount of time, you may Ctrl + C and rerun the script after you manually stop them."
    for service in ${serviceNames[@]}; do
        if systemctl is-active --quiet $service ; then
            echo "Stopping $service... This may take some time."
            systemctl stop $service
        fi
    done
}

backupDirectory() {
#This section covers the directories that are common to all host.
    if [ -d $1 ]; then
        echo "Moving $1 to $2"
        mv -f $1 $2
    else
        echo "$directory not detected. Skipping..."
    fi
}

########################################################################
#                     MAIN
########################################################################

checkNotNodeZero
checkMongo
stopServices
#This resets the salt master public key that is stored on the device.
mv -f /etc/salt/pki/minion/minion_master.pub $DESTINATION_FOLDER/salt
#Let's not have a bad yum cache
yum clean all -q 2> /dev/null
warning "All files will be moved to $DESTINATION_FOLDER"
mkdir -p $DESTINATION_FOLDER/ng
mkdir -p $DESTINATION_FOLDER/systemd
#These are our common directories that all hosts pretty much share.
for directory in ${COMMON_DIRECTORIES[@]}; do
    if [ -d $directory ]; then
        backupDirectory $directory $DESTINATION_FOLDER
    fi
done
#These are targeted towards the Core/C++ services
for directory in ${CORE_SERVICE_DIRECTORIES[@]}; do
    if [ -d $directory ]; then
        backupDirectory $directory $DESTINATION_FOLDER/ng
    fi
done

#The below seciton cleans up the launch/Java entries and responds accordingly based on criteria that may or may not apply to it.
cleanLaunchService /etc/netwitness/node-infra-server rsa-nw-node-infra-server
cleanLaunchService /etc/netwitness/contexthub-server rsa-nw-contexthub-server
cleanLaunchService /etc/netwitness/correlation-server rsa-nw-correlation-server
cleanLaunchService /etc/netwitness/esa-analytics-server rsa-nw-esa-analytics-server
cleanLaunchService /etc/netwitness/esa-server rsa-nw-esa-server
cleanLaunchService /etc/netwitness/endpoint-server rsa-nw-endpoint-server
systemctl daemon-reload

echo "The script execution is now complete. Please verify the following items before re-running nwsetup-tui in Install Mode."
warning "Please ensure that the version of this device has a matching repo on the Admin Server/Web Repo. If not, please add one by following the relevant upgrade guide to get the repo initialized."
warning "Please remove any repo files in /etc/yum.repos.d that are pointing to older versions of NetWitness that are no longer relevant, such as 11.1.0.1."
warning "Please note that if you have ever had to make workarounds in the chef recipes, you will need to reapply them accordingly."
echo "The backing up and moving of files is now complete. Please rerun nwsetup-tui to discover the host on the new Admin Node."