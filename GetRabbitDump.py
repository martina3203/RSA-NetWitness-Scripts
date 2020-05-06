#!/bin/python
#This script is supposed to continiously monitor the rabbitmq usage of file descriptors and create a dump file when we violate a threshold.

import subprocess
import json
import logging
import os

#This is the threshold I have defined. Feel free to change it.
MAX_ALLOWED_DESCRIPTORS=3600

# Sets the logging for the script
logFormat = '%(asctime)s %(message)s'
logging.basicConfig(filename=os.path.abspath(__file__) + '.log', level=logging.INFO,format=logFormat)
logging.info('Starting ' + os.path.basename(__file__))

#This particular command only seems to want to work on 11.4 releases, it seems.
statusCommand=["/usr/sbin/rabbitmqctl status --formatter json"]
dumpCommand=["/usr/bin/kill -10 $(cat /var/netwitness/rabbitmq/mnesia/*.pid)"]

#This checks rabbitmq for the present status and parses json
output = subprocess.check_output(statusCommand,shell=True)
parsedJson = json.loads(output)
pidUsed = parsedJson["pid"]
total_used = parsedJson["file_descriptors"]["total_used"]
logging.info("Total File Descriptors Used: " + str(total_used))

#If the threshold is violated, we crash it.
if total_used > MAX_ALLOWED_DESCRIPTORS:
    #Crash it to get a dump file.
    logging.info("Killing Service " + str(pidUsed))
    output = subprocess.check_output(dumpCommand,shell=True)
    logging.info("Please check /var/log/rabbitmq/ for an erl_crash.dump file and supply with relevant /var/log/rabbitmq logs.")
else:
    logging.info("Total used is below threshold of " + str(MAX_ALLOWED_DESCRIPTORS) + ". Exitting without kill...")
