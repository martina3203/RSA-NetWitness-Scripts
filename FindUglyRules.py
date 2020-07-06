#!/bin/python
#This script is meant to take a dump of the currently deployed rules on the ESA and create a text file of the ones that should be reviewed and be optimized, if at all possible.
#Note, the results of this script do not indicate that the rule is bad but that you should be absolutely sure that these are optimized as they are using elements that can be impactful on CPU.

import argparse
import json
import subprocess
import getpass

MONGO_PORT=27017
MONGO_DATABASE="sa"
MONGO_RULES_COLLECTION="rule"
MONGO_DEPLOYMENT_COLLECTION="synchronization"
MONGO_USER="deploy_admin"

#Set up parser parameters section.
parser = argparse.ArgumentParser(description='This script looks for common signs of rules that may be poorly optimized. Note, this may not indicate that the rule is 100% bad but may be worth reviewing.')
parser.add_argument("--host", help='By default, this script should be targetting the admin server (nw-node-zero). Use this parameter to override this functionality or if name resolution doesn\'t quite work',default="nw-node-zero")
parser.add_argument("-p","--password", help='Define the password the user will use to connect to the Mongo database. This should be your deployment password. If this parameter is not provided, you will be prompted')
args = parser.parse_args()

#Function that asks for password and connects to mongo
def GetUserPassword():
    deploymentPassword=getpass.getpass(prompt='Deployment Password:',stream=None)
    return deploymentPassword

#This function reaches out to the mongo instance to check any collections we may need to.
#We perform a dump because the UUIDs don't format properly in JSON
def GetEntriesInCollection(password,collectionName):
    command = "mongoexport --jsonArray -u " + MONGO_USER + " -p " + password + " --authenticationDatabase=admin -d " + MONGO_DATABASE + " -c " + collectionName + " --quiet"
    output = subprocess.check_output(command,shell=True)
    return output

def ReviewDeployedRules(deployments,rules):
    BadRuleCounter=0
    #Check the Collection for each deployment the customer has.    
    deploymentJson =  json.loads(deployments)
    for deployment in deploymentJson:
        #Grab the list of rules
        print("Deployment Name: " + str(deployment["name"]))
        deploymentRuleList = deployment["esaRuleInfos"]
        #Now, find the correspond rule and inspect it for ugliness
        for i in deploymentRuleList:
            ruleResult = ParseRuleText(i,rules)
            if (len(ruleResult) != 0):
                printStandardOutput(ruleResult)
                BadRuleCounter = BadRuleCounter + 1
        BadRuleCounter = 0
    return

def ParseRuleText(rule,jsonRuleOutput):
    output={}
    ruleCollection = json.loads(jsonRuleOutput)
    #Find the corresponding rule in the collection.
    ruleId = rule["ruleId"]
    for rule in ruleCollection:
        #Not all rules will actually have text tied with them. Think rule builder or Endpoint Rules.
        if "text" in rule:
            #I had to compile a string that matches a unicode formatted string for laziness. There is probably a better way to do this but this works.
            oidString="{u'$oid': u'" + ruleId +"'}"
            if (ruleId == rule["_id"]) or (oidString == str(rule["_id"])):
                #Now, we give the raw text and run some basic test to determine if it's ugly or not. If so, we shall tell you why I think that.
                isItUgly = Ugly(rule["text"])
                if (isItUgly):
                    output["name"] = str(rule["name"])
                    output["text"] = str(rule["text"])
                    output["uglyReason"] = isItUgly
                    #print("The Rule name is: " + str(rule["name"]))
                    #print("Raw Rule Text: " + str(rule["text"]) + "\n")
                    #print("Advice/Suggestion:")
                    #print(isItUgly + "\n")
                    break
    #print(ruleText)
    return output

#This function goes through the raw text of the rule and then isolates attributes of it that can be detrimental to performance.
def Ugly(rawRuleText):
    ugly=""
    #Check for REGEXP in the raw text.
    if ("REGEXP" in rawRuleText or "regexp" in rawRuleText):
        ugly = ugly + "REGEXP is a potentially CPU expensive operation. Please ensure you are using it properly and deem it absolutely necessary. Otherwise, disable the rule or optimize it further."
    if (".toLowerCase()" in rawRuleText):
        ugly = ugly + "Be sure that you are using the toLowerCase() function correctly. For instance, if you use it on a numerical value, such as a port number, this will prove redundant and will be a waste of CPU resources."
    if (".std:groupwin(" in rawRuleText):
        ugly = ugly + "Please be sure that you need to be using groupwin in this case as it is known to take up more memory than necessary. Please see https://community.rsa.com/docs/DOC-104243 for an example."
    return ugly

#This function is what we will use to print the rules as we see them.
def printStandardOutput(ruleInfo):
    print("The Rule name is: " + str(ruleInfo["name"]))
    print("Raw Rule Text: " + str(ruleInfo["text"]) + "\n")
    print("Advice/Suggestion:")
    print(str(ruleInfo["uglyReason"]) + "\n")

#MAIN
if __name__ == "__main__":
    MONGO_HOST = args.host
    if (args.password):
        userPassword = args.password
    else:
        userPassword = GetUserPassword()
    rulesOutput = GetEntriesInCollection(userPassword,MONGO_RULES_COLLECTION)
    deploymentOutput = GetEntriesInCollection(userPassword,MONGO_DEPLOYMENT_COLLECTION)
    ReviewDeployedRules(deploymentOutput,rulesOutput)
