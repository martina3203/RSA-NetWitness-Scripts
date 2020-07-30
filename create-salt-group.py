#!/bin/python 
#Create salt-group
#I created this script with the idea of customization in mind. This script will allow an administrator the ability to run commands targetting specific appliances in a NetWitness environment.
#Taking the results from the DB, we can create individual salt groups based on the installedServices. 

import argparse
import os
import sys
import getpass
import subprocess
import json

MONGO_USER="deploy_admin"
MONGO_HOST="nw-node-zero"
MONGO_DATABASE="orchestration-server"
COLLECTION_NAME="host"
MONGO_PORT=27017

#This is the file where we will write our new salt settings.
GROUP_FILE_DIRECTORY = "/etc/salt/master.d/NetWitnessGroups.conf"

parser = argparse.ArgumentParser(description='This script queries the Mongo Database and then creates a config file inside of salt that allows for the group of salt nodes for easier management. The deployment password is required.')
parser.add_argument("-p","--password", help='Define the password the user will use to connect to the Mongo database. This should be your deployment password. If this parameter is not provided, you will be prompted')
args = parser.parse_args()

#This function exports the host collection out for us to parse.
def ExportMongoGroups(UserPassword):
    command = "mongoexport --jsonArray -h " + MONGO_HOST + " -u " + MONGO_USER + " -p " + UserPassword + " --authenticationDatabase=admin -d " + MONGO_DATABASE + " -c " + COLLECTION_NAME + " --quiet"
    try: 
        output = subprocess.check_output(command,shell=True)
    except:
        print("Failed to run mongoexport command. Please ensure the deployment password is correct and you are running this targetting the correct host.")
        exit(2)
    return output

#We maintain a dictionary called GroupArray that will hold each installed service with a corresponding list of host.
def AddToGroup(CurrentGroup,InstalledService,Host):
    newGroup = CurrentGroup
    hostList = [ ]
    #If the service exists in the group, add to it.
    if InstalledService in newGroup:
        hostList = newGroup[InstalledService]
        hostList.append(Host)
    #If the service does not already exist in the group, add it and the entry to it.
    else:
        hostList.append(Host)
    newGroup[InstalledService] = hostList
    return newGroup

    
#From the JSON, we will parse each device into a category. This category we will use within our files that we will create. Below is a sample object in the json.
#installedServices and ipv4 is what we care about.
#{
#        "_id" : "d82dead7-80f7-4fc4-9b19-a1dfca897725",
#        "hostname" : "10.237.174.41",
#        "ipv4" : "10.237.174.41",
#        "ipv4Public" : "",
#        "displayName" : "CS-NW-ENDPOINT-41",
#        "version" : {
#                "major" : 11,
#                "minor" : 4,
#                "servicePack" : 1,
#                "patch" : 1,
#                "snapshot" : false,
#                "rawVersion" : "11.4.1.1"
#        },
#        "thirdParty" : false,
#        "installedServices" : [
#                "EndpointLogHybrid"
#        ],
#        "meta" : {
#
#        },
#        "_class" : "com.rsa.asoc.orchestration.host.HostEntity"
#}
#We will finally return a dictionary that has each service and corresponding host in it.
def ParseAndGroupHostTypes(hostCollectionJson):
    GroupDictionary = { }
    try:
        hostsCollection =  json.loads(hostCollectionJson)
    except:
        print("Unable to parse JSON returned from Mongo Export! Aborting!")
        exit(3)
    for host in hostsCollection:
        if ({"ipv4","installedServices"} <= set(host.viewkeys())):
            for i in host["installedServices"]:
                #print (host["ipv4"].encode('utf-8'), i)
                serviceGroups = AddToGroup(GroupDictionary,i,host['ipv4'])
    return serviceGroups

#It does what it says. The password is the one that corresponds to the Mongo Database.
def GetUserPassword():
    deploymentPassword=getpass.getpass(prompt='Deployment Password:',stream=None)
    return deploymentPassword

#This function will create the Group Files in Question for the corresponding host. A file will be created for each category of host.
#We will be using the following documents to deteremine our file output.
#https://docs.saltstack.com/en/master/topics/targeting/compound.html#targeting-compound
#https://docs.saltstack.com/en/master/topics/targeting/nodegroups.html
def CreateGroupFile(Group,DestinationFile):
    try:
        file = open(GROUP_FILE_DIRECTORY,'w')
        file.write("nodegroups:" + "\n")
    except IOError:
        print("ERROR: Unable to access file. Is it currently open or owned by a different user?")
        exit(4)
    for serviceCategory in Group:
        file.write("  " + serviceCategory + ": \n")
        for host in Group[serviceCategory]:
            file.write('     - \'S@' + host + '\' \n')
    file.close()
    return

if __name__ == "__main__":
    GroupDictionary = { }
    if (args.password):
        userPassword = args.password
    else:
        userPassword = GetUserPassword()
    collectionResults = ExportMongoGroups(userPassword)
    GroupDictionary = ParseAndGroupHostTypes(collectionResults)
    print("The following device types were found in this environment and wil be converted to salt groups.")
    for i in GroupDictionary:
        print('  ' + i)
    CreateGroupFile(GroupDictionary,GROUP_FILE_DIRECTORY)
    print("The config was successfully created and can be found in " + GROUP_FILE_DIRECTORY)
    print("Please run a salt command using salt -N with the defined groups that were created above. For Example:")
    print("salt -N Concentrator cmd.run \"hostname\"")