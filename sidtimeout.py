#!/bin/python
#This is a quick and dirty script to change all SID timeouts to a value
#This script is in no way effiecient so please don't just for it. IT'S DOWN RIGHT DIRTY! JUST USE IT.

import xml.etree.ElementTree
import urllib2
import base64
import ssl
import json

#Rest login information
username="admin"
password="netwitness"
#Destination INformation
host="10.101.67.176"
port="50101"
protocol="http"
domain="mbc_lol"
context = ssl._create_unverified_context()

#You probably won't change these
message="/logcollection/windows/eventsources/"
sidvalue="360"
property="sids_timeout?msg=set&force-content-type=text/plain&value=" + sidvalue


#URL FORMAT
#http://10.101.67.176:50101/logcollection/windows/eventsources/mbc_lol/2k12-ecat-1-0_mbc_lol/sids_timeout?msg=set&force-content-type=text/plain&value=360

#Build URL to get list
url=protocol + "://" + host + ":" + port + message + domain + "/"
print("Opening for list of devices: " + url)
base64password = base64.b64encode('%s:%s' % (username, password))

request = urllib2.Request(url)
request.add_header("Authorization", "Basic %s" % base64password)
try:
    result=urllib2.urlopen(request)
except urllib2.HTTPError as e:
    if (e.code == 401):
        print ("401: Unauthorized. May want to check your username/password combination as well as your connection information.")
        exit()
    else:
        print ("Failed! Error code: " + str(e.code))
        exit()

#Parse list
#print(result.next())
xmltree = xml.etree.ElementTree.parse(result)
root = xmltree.getroot()
subroot = root[0]
pathList = [ ]
#print(root.tag)
#print(root.attrib)

for child in subroot.findall('node'):
    #print child.tag, child.attrib
    node = child.attrib
    print node["path"]
    if (not (node["path"].contains("username"))):
        print ("Ignoring " + node["path"] + " as it contains a white list word.")
    else:
        url = protocol + "://" + host + ":" + port + node["path"] + property
        request = urllib2.Request(url)
        request.add_header("Authorization", "Basic %s" % base64password)
        try:
            result=urllib2.urlopen(request)
        except urllib2.HTTPError as e:
            if (e.code == 401):
                print ("401: Unauthorized. May want to check your username/password combination as well as your connection information.")
                exit()
            elif (e.code == 404):
                print ("404: Not Found. This is expected if the element is not actually a name of a Windows host.")
                print("Target: " + url)
            else:
                print ("Failed! Error code: " + str(e.code))
                exit()



#Perform change on list
