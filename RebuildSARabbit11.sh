#!/bin/bash
#This is meant to rebuld the RabbitMQ to the best of my abilities

#Origin of steps is case 01423578
#This should only need to be ran on a Admin server

rabbitmqctl add_vhost /rsa/system

#Create deploy_admin user if he doens't exist.
#Substitute your deployment password for the below
rabbitmqctl add_user deploy_admin netwitness
rabbitmqctl set_permissions -p /rsa/system deploy_admin ".*" ".*" ".*"
rabbitmqctl set_permissions -p / deploy_admin ".*" ".*" ".*"
rabbitmqctl set_user_tags deploy_admin administrator

#Add permissions for guest
rabbitmqctl set_permissions -p /rsa/system guest ".*" ".*" ".*"

#Admin Server
rabbitmqctl add_user rsa-nw-admin-server netwitness
rabbitmqctl clear_password rsa-nw-admin-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-admin-server ".*" ".*" ".*"

#Config Server
rabbitmqctl add_user rsa-nw-config-server netwitness
rabbitmqctl clear_password rsa-nw-config-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-config-server ".*" ".*" ".*"

#Content Server
rabbitmqctl add_user rsa-nw-content-server netwitness
rabbitmqctl clear_password rsa-nw-content-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-content-server ".*" ".*" ".*"

#Contexthub Server
rabbitmqctl add_user rsa-nw-contexthub-server netwitness
rabbitmqctl clear_password rsa-nw-contexthub-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-contexthub-server ".*" ".*" ".*"

#Correlation Server
rabbitmqctl add_user rsa-nw-correlation-server netwitness
rabbitmqctl clear_password rsa-nw-correlation-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-correlation-server ".*" ".*" ".*"

#Endpoint Server
rabbitmqctl add_user rsa-nw-endpoint-server netwitness
rabbitmqctl clear_password rsa-nw-endpoint-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-endpoint-server ".*" ".*" ".*"

#ESA Analytics Server
rabbitmqctl add_user rsa-nw-esa-analytics-server netwitness
rabbitmqctl clear_password rsa-nw-esa-analytics-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-esa-analytics-server ".*" ".*" ".*"

#Integration Server
rabbitmqctl add_user rsa-nw-integration-server netwitness
rabbitmqctl clear_password rsa-nw-integration-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-integration-server ".*" ".*" ".*"

#Investigate Server
rabbitmqctl add_user rsa-nw-investigate-server netwitness
rabbitmqctl clear_password rsa-nw-investigate-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-investigate-server ".*" ".*" ".*"

#License Server
rabbitmqctl add_user rsa-nw-license-server netwitness
rabbitmqctl clear_password rsa-nw-license-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-license-server ".*" ".*" ".*"

#Orchestration Server
rabbitmqctl add_user rsa-nw-orchestration-server netwitness
rabbitmqctl clear_password rsa-nw-orchestration-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-orchestration-server ".*" ".*" ".*"

#Respond Server
rabbitmqctl add_user rsa-nw-respond-server netwitness
rabbitmqctl clear_password rsa-nw-respond-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-respond-server ".*" ".*" ".*"

#Security Server
rabbitmqctl add_user rsa-nw-security-server netwitness
rabbitmqctl clear_password rsa-nw-security-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-security-server ".*" ".*" ".*"

#Source Server
rabbitmqctl add_user rsa-nw-source-server netwitness
rabbitmqctl clear_password rsa-nw-source-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-source-server ".*" ".*" ".*"

#Node Infra Server.This is for 11.4
rabbitmqctl add_user rsa-nw-node-infra-server netwitness
rabbitmqctl clear_password rsa-nw-node-infra-server
rabbitmqctl set_permissions -p /rsa/system rsa-nw-node-infra-server ".*" ".*" ".*"

#Policy
#set_policy [-p <vhost>] [--priority <priority>] [--apply-to <apply-to>] <name> <pattern>  <definition>
rabbitmqctl set_policy -p /rsa/system --priority 0 --apply-to exchanges carlos-federate '^carlos\.*' '{"federation-upstream-set":"all"}'

#Now, we are gonna attempt to readd all of the users per salt device.
#Collect those individuals

for i in `salt-key | sed -n '/Accepted Keys:/,/Denied Keys:/{ /Accepted Keys:/d; /Denied Keys:/d; p;}'`; do
  echo $i
  rabbitmqctl add_user $i netwitness
  rabbitmqctl clear_password $i
  rabbitmqctl set_permissions -p /rsa/system $i ".*" ".*" ".*"
done

#Remove marker file for logstash user to be recreated on orchestration-cli-client --update-admin-node
mv /etc/netwitness/platform/logstash_rabbit/rsa-audit-server.rabbitmq.properties /tmp

echo "Restarting all NetWitness Launch Services"
systemctl restart rsa-nw-*
systemctl restart jetty && systemctl restart nginx

echo "Waiting 60 seconds before starting chef run on all host..."
echo "Please note that this process alone will take a long time and will start on the Admin Server."
sleep 60

orchestration-cli-client --update-admin-node -v

for i in `salt-key | sed -n '/Accepted Keys:/,/Denied Keys:/{ /Accepted Keys:/d; /Denied Keys:/d; p;}'`; do
  echo $i
  orchestration-cli-client --refresh-host -o $i -v
done

#We are rerunning a federation script on all host. If this doesn't finish fairly quick then that means you may have another problem.
#You'll need to search through the logs of the chef run or salt to figure out what that can be.
