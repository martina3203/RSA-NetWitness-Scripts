#!/bin/bash
#This script collects some various information about the OS and RabbitMQ
#It will output it all ot a file in /tmp called rabbitstats
DESTINATION_FOLDER="/tmp/rabbitstats"

mkdir $DESTINATION_FOLDER

#Collecting information presented by the service
rabbitmqctl status > $DESTINATION_FOLDER/rabbitmq-status.out
rabbitmqctl report > $DESTINATION_FOLDER/rabbitmq-report.out
rabbitmqctl list_queues -p /rsa/system name messages consumers > $DESTINATION_FOLDER/list_queues-rsa-system.out
#Let's say we start targetting a log collector
rabbitmqctl list_queues -p logcollection name messages consumers > $DESTINATION_FOLDER/list_queues-logcollection.out

#Netstat and process information
netstat -anp > $DESTINATION_FOLDER/netstat.out
ss -n > $DESTINATION_FOLDER/ss-n.out
ps aux > $DESTINATION_FOLDER/ps-aux.out
systemctl status rabbitmq-server -l > $DESTINATION_FOLDER/systemctl-status-rabbit-l.out
systemctl status > $DESTINATION_FOLDER/systemctl-status.out 

#lsof output
lsof /var/netwitness/ > $DESTINATION_FOLDER/lsof-netwitnesshome.out
lsof -u rabbitmq > $DESTINATION_FOLDER/lsof-u-rabbitmq.out

#User File limits
ulimit -a > $DESTINATION_FOLDER/ulimit-a.out
cp /etc/security/limits.conf $DESTINATION_FOLDER/security-limits.conf

#We talked about SMS being part of the problem so I am going to include it. Also, I am lazy and decided not to bother trying to grep it out of the next step.
systemctl status rsa-sms -l > $DESTINATION_FOLDER/systemctl-status-rsa-sms-l.out

#This will create a list that will allow us to iterate and look in the /proc folder for each item
for pid in `ps aux | grep -i rabbitmq | grep -v "grep" | awk '{print $2}'| grep -i [0-9]`; 
    do 
    echo "checking /proc folder of $pid" 
    mkdir $DESTINATION_FOLDER/$pid
    cat /proc/$pid/limits > $DESTINATION_FOLDER/$pid/limits.out
    ls -alh /proc/$pid/fd* > $DESTINATION_FOLDER/$pid/fdinfo-ls-alh.out
done;

#I choose to omit this when I wish to add more to my final archive
tar -czf $DESTINATION_FOLDER-`date +%m%d%Y-%H%M`.tar.gz $DESTINATION_FOLDER -v