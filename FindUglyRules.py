#!/bin/python
#This script is meant to take a dump of the currently deployed rules on the ESA and create a text file of the ones that should be reviewed and be optimized, if at all possible.
#Note, the results of this script do not indicate that the rule is bad but that you should be absolutely sure that these are optimized as they are using elements that can be impactful on CPU.
#This script is meant for Python 2.7 and assumes mongoexport is in the PATH.

import argparse
import json
import subprocess
import getpass

MONGO_DATABASE="sa"
MONGO_RULES_COLLECTION="rule"
MONGO_DEPLOYMENT_COLLECTION="synchronization"
MONGO_USER="deploy_admin"

#Set up parser parameters section.
parser = argparse.ArgumentParser(description='This script looks for common signs of rules that may be poorly optimized. Note, this may not indicate that the rule is 100% bad but may be worth reviewing. \
This script is meant for Python 2.7 and assumes mongoexport is in the PATH.')
parser.add_argument("--host", help='By default, this script should be targetting the admin server (nw-node-zero). Use this parameter to override this functionality or if name resolution doesn\'t quite work. \
You can also concatenate a port at the end of the host to use it.',default="nw-node-zero")
parser.add_argument("-p","--password", help='Define the password the user will use to connect to the Mongo database. This should be your deployment password. If this parameter is not provided, you will be prompted')
args = parser.parse_args()

#Function that asks for password and connects to mongo
def GetUserPassword():
    deploymentPassword=getpass.getpass(prompt='Deployment Password:',stream=None)
    return deploymentPassword

#This function reaches out to the mongo instance to check any collections we may need to.
#We perform a dump because the UUIDs don't format properly in JSON
def GetEntriesInCollection(password,collectionName):
    command = "mongoexport --jsonArray -h " + MONGO_HOST + " -u " + MONGO_USER + " -p " + password + " --authenticationDatabase=admin -d " + MONGO_DATABASE + " -c " + collectionName + " --quiet"
    try: 
        output = subprocess.check_output(command,shell=True)
    except:
        print("Failed to run mongoexport command. Please ensure the deployment password is correct and you are running this targetting the correct host.")
        exit(2)
    return output

def ReviewDeployedRules(deployments,rules):
    BadRuleCounter=0
    #Check the Collection for each deployment the customer has.
    try:   
        deploymentJson =  json.loads(deployments)
        for deployment in deploymentJson:
            #Grab the list of rules
            deploymentName = deployment["name"]
            deploymentRuleList = deployment["esaRuleInfos"]
            #Now, find the correspond rule and inspect it for ugliness
            for i in deploymentRuleList:
                #We will attempt to treat it as an AdvancedRule
                ruleResult = ParseRuleText(i,rules)
                if (len(ruleResult) != 0):
                    printStandardOutput(deploymentName,ruleResult)
                    BadRuleCounter = BadRuleCounter + 1
        BadRuleCounter = 0
    except:
        print("Failed to parse Synchroninzation JSON. Please confirm the mongoexport of synchronization collection is valid JSON.")
        exit(3)
    return

def ParseRuleText(rule,jsonRuleOutput):
    output={}
    try:
        ruleCollection = json.loads(jsonRuleOutput)
        #Find the corresponding rule in the collection.
        ruleId = rule["ruleId"]
        for rule in ruleCollection:
            #Not all rules will actually have text tied with them. Think rule builder or Endpoint Rules.
            #I had to compile a string that matches a unicode formatted string for laziness. There is probably a better way to do this but this works. 
            oidString="{u'$oid': u'" + ruleId +"'}"
            if (ruleId == rule["_id"]) or (oidString == str(rule["_id"])):
                if (rule["type"] == "ESA_ADVANCED"):
                    if "text" in rule:
                        #Now, we give the raw text and run some basic test to determine if it's ugly or not. If so, we shall tell you why I think that.
                        isItUgly = Ugly(rule["text"])
                        if (isItUgly):
                            output["name"] = str(rule["name"])
                            output["type"] = str(rule["type"])
                            output["text"] = str(rule["text"])
                            output["uglyReason"] = isItUgly
                            return output
                #We have to inspect the individual elements of the BASIC Rule since no Esper is compiled until runtime.
                elif (rule["type"] == "ESA_BASIC"):
                    if "statements" in rule:
                        statementArray = rule["statements"]
                        for statement in statementArray:
                            if ("statementLines" in statement):
                                rawText=""
                                #This section reviews each individual statement looking for certain attribtutes such as Contains or ToLowerCase()
                                for individualStatement in statement["statementLines"]:
                                    if ("Contains" in individualStatement and "metaKeyId" in individualStatement):
                                        rawText = rawText + "LIKE paired with " + individualStatement["metaKeyId"] + "\n"
                                    elif ("ignoreCase" in individualStatement and "metaKeyId" in individualStatement):
                                        rawText = rawText + ".toLowerCase paired with " + individualStatement["metaKeyId"] + "\n"
                                isItUgly = Ugly(rawText)
                                if (isItUgly):
                                    output["name"] = str(rule["name"])
                                    output["type"] = str(rule["type"])
                                    output["text"] = str(rawText)
                                    output["uglyReason"] = isItUgly
                                    return output
    except: 
        print("Failed to parse Rule JSON. Please confirm the mongoexport of rules collection is valid JSON." )
        exit(4)
    return output

#This function goes through the raw text of the rule and then isolates attributes of it that can be detrimental to performance.
#We concatenate a string with advise based on the words encountered in it.
def Ugly(rawRuleText):
    ugly=""
    #Check for REGEXP in the raw text.
    if ("REGEXP" in rawRuleText or "regexp" in rawRuleText):
        ugly = ugly + "REGEXP is a potentially CPU expensive operation. Please ensure you are using it properly and deem it absolutely necessary. Otherwise, disable the rule or optimize it further."
    #Check for lower case or upper case functions which can be unnecessary.
    if (".toLowerCase" in rawRuleText or ".toUpperCase" in rawRuleText):
        ugly = ugly + "Be sure that you are using the toLowerCase(), toUpperCase() or isOneOfIgnoreCase functions correctly. For instance, if you use it on a numerical value, such as a port number, this will prove redundant and will be a waste of CPU resources."
    #Check for groupwin which may not be necessary.
    if (".std:groupwin" in rawRuleText):
        ugly = ugly + "Please be sure that you need to be using groupwin in this case as it is known to take up more memory than necessary. Please see https://community.rsa.com/docs/DOC-104243 for an example."
    #Check for LIKE statements or similar.
    if ("LIKE" in rawRuleText or "matchLike" in rawRuleText or "matchRegex" in rawRuleText):
        ugly = ugly + "Please be mindful that any LIKE or REGEX operations can be CPU expensive, especially for long string values such as event_desc. Please be sure that you are using them efficiently."
    return ugly

#This function is what we will use to print the rules as we see them.
def printStandardOutput(deploymentName,ruleInfo):
    print("<--------------------------------------------------")
    print("Deployment Name: " + str(deploymentName))
    print("Rule Name: " + str(ruleInfo["name"]))
    print("ESA Rule Type: " + str(ruleInfo["type"]))
    print("Raw Rule Text: \n" + str(ruleInfo["text"]))
    print("===================================================")
    print("Advice/Suggestion:")
    print(str(ruleInfo["uglyReason"]) + "\n")
    print("-------------------------------------------------->")

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
