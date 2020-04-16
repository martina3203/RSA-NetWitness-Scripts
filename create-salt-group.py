#Create salt-group
#I created this script with the idea of customization in mind.
#Taking the results from the DB, we can create individual salt groups based on some criteria. This script will do it based on installed services.

import argparse
import os
import sys

#This is the file where we will write our new salt settings.
groupfile = "/etc/salt/master.d/groups.conf"
groups = ["AdminServer","UEBA","LogHybrid"]

#If there is not enough arguments
if len(sys.argv) < 2 or len(sys.argv) >= 4:
    print("Please supply your deployment password while running this script. If you wish to hide your password, pass the -p option")
    print("Example:")
    print("./create-salt-group.py netwitness")
    print("./create-salt-group.py -p")
    exit()
elif sys.argv[1] == "-p":
    print("Please input your deployment password:")
    #Grab deployment password
else:
    #Let the first argument be the password then
    password == sys.argv[1]


print("Password is:" + password)

def
