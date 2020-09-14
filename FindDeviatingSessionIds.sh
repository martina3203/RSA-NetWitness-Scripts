#!/bin/bash
#This script was written to isolate where the database fault in a log decoder was as a result of a bug in the 11.3 release.
#This script will inform the user where there is a divergence in the database.

DIRECTORY_FILES="/var/netwitness/logdecoder/metadb/*.manifest"
GREP_OUTPUT_FILE="/tmp/sessiongrepoutput.txt"
PREVIOUS_SESSION_ID=0

grep session1 /var/netwitness/logdecoder/metadb/*.manifest > $GREP_OUTPUT_FILE

#For each file in the directory, we are looking for manifest
while IFS= read -r line; do 
    #Grab the field
    SESSION_ID=`echo "$line" | cut -d ':' -f 3`
    #The field now looks like " 1810173," so the space and , are still in play.
    #Remove the space and the , easily to just get a number.
    SESSION_ID="$(echo "$SESSION_ID" | tr -d '[:space:]' | tr -d ',')"
    #Now, let's compare and see if the value from above is higher than our last value. If so, the database is fine for this particular entry.
    #echo "$SESSION_ID < $PREVIOUS_SESSION_ID ?"
    if [ $SESSION_ID -le $PREVIOUS_SESSION_ID ];
    then
        echo "SessionID in file is found to be smaller than previous value! $line"
        echo "Perform your metadb timeroll just past the date of this file."
    fi
    PREVIOUS_SESSION_ID=$SESSION_ID
    #echo $SESSION_ID
done < "$GREP_OUTPUT_FILE"