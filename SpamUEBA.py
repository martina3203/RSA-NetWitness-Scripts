#!/bin/python
"""
#This script is written with the naive intention of setting off UEBA events so that it seems like it's doing something. The idea is to run the script many different times at potentially different intervals to generate UEBA alerts for data that may already exist. The parameters are the potential meta keys that you would see in a normal winevent_nic event.
SpamUEBA.py --host 10.237.174.41 --user_dst martia49 --device_host ADExample.example.com --host_src MartinWorkstation --domain CS -e 4720
You can play with this script without sending any logs by providing the --do_not_send parameter. By default it will send.
"""
import datetime
import socket
import argparse

parser = argparse.ArgumentParser(description='This script sends events as defined to a log decoder to be ingested later by UEBA based on the criteria provided. The present events included in those script simulate those that come WinRM/winevent_nic integrations. Presently, only the following Windows events are available: 4624,4625,4720,4767')
parser.add_argument("--host", help='This is the Log Decoder/Syslog Server host we will be sending our packets to. It will default to localhost',default="localhost")
parser.add_argument("-p","--port", help='This is the port we will be sending our syslog to. It will default to 514',default=514)
parser.add_argument("--do_not_send",help='By default, we send the event to the destination log device. You can opt not to send it if you just want a template of what it would look like.',default=True,action="store_false")
parser.add_argument("-e","--event",help='This parameter tells the script what predefined Windows Event ID to send. It will default to 4625',default=4625)
parser.add_argument("--device_host",help='This is the value that typically occupies the device.host meta. Defaults to ad.example.com',default="ad.example.com")
parser.add_argument("--user_dst",help='This is the value that typically occupies the user.dst meta. Defaults to testuser',default="testuser")
parser.add_argument("--user_src",help='This is the value that typically occupies the user.src meta. Defaults to testuser',default="testuser2")
parser.add_argument("--domain",help='This is the value that typically occupies the domain meta. Defaults to example',default="example")
parser.add_argument("--host_src",help='This is the value that typically occupies the host_src meta. Think of it like the workstation that a login originated from. Defaults to ExampleWorkstation',default="ExampleWorkstation")
parser.add_argument("--ip_src",help='This is the value that typically occupies the ip.src meta.  Defaults to 1.1.1.1',default="1.1.1.1")
args = parser.parse_args()

#Below are the connection information we are going to use to send out log event
HOST = args.host
PORT = args.port 
EVENT_ID = int(args.event)
SEND = args.do_not_send
SYSLOG_EVENT=""

#We are going to generate a date that fits Windows logging methods. It must also be in UTC time for best results as the NetWitness environment is in UTC time.
#Tue Aug 25 15:47:26 2020
currentTime = datetime.datetime.utcnow()
EVENT_TIME=currentTime.strftime("%a %b %d %H:%M:%S %Y")

#Below will be some default values that may be overwritten on a case by case instance. Otherwise, they will be these. I have tried ot make them match the metakey that they will show up under.
DEVICE_HOST=args.device_host
USER_DST=args.user_dst
USER_SRC=args.user_src
DOMAIN=args.domain
HOST_SRC=args.host_src
IP_SRC=args.ip_src
SOURCE_PORT="59000"


#Based on the supplied Event ID, we will create a relevant syslog event that fits Winevent_nic/WinRM events.
#Account Successful Login Event
if EVENT_ID == 4624:
    WINDOWS_EVENT_4624="%NICWIN-4-Security_4624_Microsoft-Windows-Security-Auditing: Security,rn=7295417 cid=2276 eid=512," + EVENT_TIME + ",4624,Microsoft-Windows-Security-Auditing,,Audit Success," + DEVICE_HOST + ",Logon,,An account was successfully logged on. Subject: Security ID: S-1-0-0 Account Name: - Account Domain: - Logon ID: 0x0 Logon Type: 3 Impersonation Level: Impersonation New Logon: Security ID: S-1-5-21-3581538793-3767465783-4063912055-1106 Account Name: " + USER_DST + " Account Domain: " + DOMAIN + " Logon ID: 0x10E65569 Logon GUID: {96414F3F-A438-7191-C8CD-5FFEB01B75D5} Process Information: Process ID: 0x0 Process Name: - Network Information: Workstation Name: Source Network Address: - Source Port: - Detailed Authentication Information: Logon Process: Kerberos Authentication Package: Kerberos Transited Services: - Package Name (NTLM only): - Key Length: 0 This event is generated when a logon session is created. It is generated on the computer that was accessed. The subject fields indicate the account on the local system which requested the logon. This is most commonly a service such as the Server service, or a local process such as Winlogon.exe or Services.exe. The logon type field indicates the kind of logon that occurred. The most common types are 2 (interactive) and 3 (network). The New Logon fields indicate the account for whom the new logon was created, i.e. the account that was logged on. The network fields indicate where a remote logon request originated. Workstation name is not always available and may be left blank in some cases. The impersonation level field indicates the extent to which a process in the logon session can impersonate. The authentication information fields provide detailed information about this specific logon request. - Logon GUID is a unique identifier that can be used to correlate this event with a KDC event. - Transited services indicate which intermediate services have participated in this logon request. - Package name indicates which sub-protocol was used among the NTLM protocols. - Key length indicates the length of the generated session key. This will be 0 if no session key was requested."
    SYSLOG_EVENT=WINDOWS_EVENT_4624
#Account Failed Login Event
elif EVENT_ID == 4625:
    #Below are the variables we are going to use for substitution into a log event
    WINDOWS_EVENT_4625="%NICWIN-4-Security_4625_Microsoft-Windows-Security-Auditing: Security,rn=3269077052 cid=8636 eid=720," + EVENT_TIME + ",4625,Microsoft-Windows-Security-Auditing,,Audit Failure," + DEVICE_HOST + ",Logon,,An account failed to log on. Subject: Security ID: S-1-0-0 Account Name: - Account Domain: - Logon ID: 0x0 Logon Type: 3 Account For Which Logon Failed: Security ID: S-1-0-0 Account Name: " + USER_DST + " Account Domain: " + DOMAIN + " Failure Information: Failure Reason: Unknown user name or bad password. Status: 0xC000006D Sub Status: 0xC0000064 Process Information: Caller Process ID: 0x0 Caller Process Name: - Network Information: Workstation Name: " + HOST_SRC + " Source Network Address: " + IP_SRC + " Source Port: " + SOURCE_PORT + " Detailed Authentication Information: Logon Process: NtLmSsp Authentication Package: NTLM Transited Services: - Package Name (NTLM only): - Key Length: 0 This event is generated when a logon request fails. It is generated on the computer where access was attempted. The Subject fields indicate the account on the local system which requested the logon. This is most commonly a service such as the Server service, or a local process such as Winlogon.exe or Services.exe. The Logon Type field indicates the kind of logon that was requested. The most common types are 2 (interactive) and 3 (network). The Process Information fields indicate which account and process on the system requested the logon. The Network Information fields indicate where a remote logon request originated. Workstation name is not always available and may be left blank in some cases. The authentication information fields provide detailed information about this specific logon request. - Transited services indicate which intermediate services have participated in this logon request. - Package name indicates which sub-protocol was used among the NTLM protocols. - Key length indicates the length of the generated session key. This will be 0 if no session key was requested."
    SYSLOG_EVENT=WINDOWS_EVENT_4625

#A user account was created
elif EVENT_ID == 4720:
    WINDOWS_EVENT_4720="%NICWIN-4-Security_4720_Microsoft-Windows-Security-Auditing: Security,rn=7321594 cid=1248 eid=512," + EVENT_TIME + ",4720,Microsoft-Windows-Security-Auditing,,Audit Success," + DEVICE_HOST + ",User Account Management,,A user account was created. Subject: Security ID: S-1-5-21-3581538793-3767465783-4063912055-1107 Account Name: " + USER_DST + " Account Domain: " + DOMAIN + " Logon ID: 0x3C207F New Account: Security ID: S-1-5-21-3581538793-3767465783-4063912055-1130 Account Name: " + USER_SRC + " Account Domain: " + DOMAIN + " Attributes: SAM Account Name: " + USER_SRC + " Display Name: " + USER_SRC + " User Principal Name: " + USER_SRC + "@" + DOMAIN + " Home Directory: - Home Drive: - Script Path: - Profile Path: - User Workstations: - Password Last Set: <never> Account Expires: <never> Primary Group ID: 513 Allowed To Delegate To: - Old UAC Value: 0x0 New UAC Value: 0x15 User Account Control: Account Disabled 'Password Not Required' - Enabled 'Normal Account' - Enabled User Parameters: - SID History: - Logon Hours: <value not set> Additional Information: Privileges -"
    SYSLOG_EVENT=WINDOWS_EVENT_4720
#A user account was unlocked
elif EVENT_ID == 4767:
    WINDOWS_EVENT_4767="%NICWIN-4-Security_4767_Microsoft-Windows-Security-Auditing: Security,rn=7311615 cid=2788 eid=512," + EVENT_TIME + ",4767,Microsoft-Windows-Security-Auditing,,Audit Success," + DEVICE_HOST + ",User Account Management,,A user account was unlocked. Subject: Security ID: S-1-5-21-3581538793-3767465783-4063912055-1107 Account Name: " + USER_DST + " Account Domain: " + DOMAIN + " Logon ID: 0x3C207F Target Account: Security ID: S-1-5-21-3581538793-3767465783-4063912055-1106 Account Name: " + USER_SRC + " Account Domain: "+ DOMAIN
    SYSLOG_EVENT=WINDOWS_EVENT_4767
else:
    print("This script does not contain a log template for event " + EVENT_ID)
    exit(1)

print("The following event was created with a default syslog header:")
SYSLOG_EVENT="<1>" + SYSLOG_EVENT
print(SYSLOG_EVENT)

if (SEND):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect((HOST, PORT))
        s.sendall(SYSLOG_EVENT)
        print("Log successfully sent to " + str(HOST) + ":" + str(PORT) + " using UDP")
    except socket.error as error:
        print "Error while sending log: ", error
