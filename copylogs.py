#!/bin/python

#Author: Aaron Martin
#Date Created: 03/22/2018
#Version: 1.0
#The whole purpose of this script was to bypass an issue with the SFTP agent for MSSQl File Collection
#The pos file would never reset because the file's name would never change.
#The workaround was to set sftp to read ERRORLOG.1, for example, and set it to delete the file at the end. However, this would destroy the customer's physical logging capability.
#This script will copy ERRORLOG.1 as a scheduled event if the modified time has changed since the last time it was copied.
#That way, we preserve the file

import os
import time
import shutil

#Please place the full path to the file here
targetFile = "C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Log\ERRORLOG.1"
#Please place the individual file name here
targetFileName="ERRORLOG.1"


#Grab the directory this script is running in
workingDirectory = os.path.dirname(os.path.realpath(__file__))
targetDestination = workingDirectory + "/" + targetFileName
print("Current Working Directory: " + workingDirectory)
#Designate our index file path and name
indexFile = workingDirectory + "/index.txt"

#If our index file doesn't exists, create one
if os.path.isfile(indexFile) == False:
    #Create file
    try:
        print("Index file does not exist. Creating...")
        file = open(indexFile,"w")
        #Setting it the ever simple value of beginning of linux epoch time
        file.write("0")
        file.close()
    except:
        print("Unable to create/read file: " + indexFile + " Exiting...")
        exit()

#Collect our file times
try:
    file = open(indexFile,"r")
    index_date = file.read()
    file.close()
except OSError as e:
    print(e)
    print("Unable to read file: " + indexFile + " Exiting...")
    exit()

print ("Index time as Linux epoch: " + index_date)

try:
    target_file_date = os.path.getmtime(targetFile)
except OSError as e:
    print(e)
    print("Failed to read target file: " + targetFile + " Exiting...")
    exit()

print ("Time of target file: " + str(target_file_date))

#I'm adding a margin of error of 5 seconds as floats can offset it if it was just touched
if (float(target_file_date)) > float(index_date):
    try:
		print("Copying target file to working directory....")
		print(targetFile + " to " + targetDestination)
        #Copy the target file to the current working directory
		shutil.copyfile(targetFile,targetDestination)
		print("Copy complete!")
    except OSError as e:
        print(e)
        print("Failed to copy file to working directory. Exiting...")
        exit()
    #Once copy is complete, update the index to reflect this for the next run
    index_date = target_file_date
    print("Updating index file...")
    file = open(indexFile,"w")
    file.write(str(index_date))
    print("Index updated! Exitting...")
else:
    print("No change to target file detected. Exitting...")
