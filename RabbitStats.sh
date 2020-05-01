#!/bin/bash
#This script collects some various information about the OS and RabbitMQ
#It will output it all ot a file in /tmp called rabbitstats
DESTINATION_FOLDER="/tmp/rabbitstats"

mkdir -p $DESTINATION_FOLDER

#You pass a pid and we will create a folder, if needed, as well as write many attributes about it to file.
getFDInfoForPid() {
    local pid=$1
    mkdir -p $DESTINATION_FOLDER/$pid
    cat /proc/$pid/limits > $DESTINATION_FOLDER/$pid/limits.out
    echo `date` >> $DESTINATION_FOLDER/$pid/fd-ls-alh.out
    ls -alh /proc/$pid/fd >> $DESTINATION_FOLDER/$pid/fd-ls-alh.out
    echo `date` >> $DESTINATION_FOLDER/$pid/fdinfo-ls-alh.out
    ls -alh /proc/$pid/fdinfo >> $DESTINATION_FOLDER/$pid/fdinfo-ls-alh.out
}

#Collecting information presented by the service
/usr/sbin/rabbitmqctl status > $DESTINATION_FOLDER/rabbitmq-status.out
/usr/sbin/rabbitmqctl report > $DESTINATION_FOLDER/rabbitmq-report.out
/usr/sbin/rabbitmqctl list_queues -p /rsa/system name messages consumers > $DESTINATION_FOLDER/list_queues-rsa-system.out
#Let's say we start targetting a log collector
/usr/sbin/rabbitmqctl list_queues -p logcollection name messages consumers > $DESTINATION_FOLDER/list_queues-logcollection.out

#Netstat and process information
netstat -anp > $DESTINATION_FOLDER/netstat.out
/usr/sbin/ss -n > $DESTINATION_FOLDER/ss-n.out
ps aux > $DESTINATION_FOLDER/ps-aux.out
/usr/bin/systemctl status rabbitmq-server -l > $DESTINATION_FOLDER/systemctl-status-rabbit-l.out
/usr/bin/systemctl status > $DESTINATION_FOLDER/systemctl-status.out 

#lsof output
/usr/sbin/lsof /var/netwitness/ > $DESTINATION_FOLDER/lsof-netwitnesshome.out
/usr/sbin/lsof -u rabbitmq > $DESTINATION_FOLDER/lsof-u-rabbitmq.out

#User File limits
ulimit -a > $DESTINATION_FOLDER/ulimit-a.out
cat /etc/security/limits.conf > $DESTINATION_FOLDER/security-limits.conf

#We talked about SMS being part of the problem so I am going to include it. Also, I am lazy and decided not to bother trying to grep it out of the next step.
/usr/bin/systemctl status rsa-sms -l > $DESTINATION_FOLDER/systemctl-status-rsa-sms-l.out

#This will create a list that will allow us to iterate and look in the /proc folder for each item
for pid in `ps aux | grep -i rabbitmq | grep -v "grep" | awk '{print $2}'| grep -i [0-9]`; 
    do 
    #echo "checking /proc folder of $pid" 
    getFDInfoForPid $pid
done;

#I choose to omit this when I wish to add more to my final archive
#tar -czf $DESTINATION_FOLDER-`date +%m%d%Y-%H%M`.tar.gz $DESTINATION_FOLDER -v