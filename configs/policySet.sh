#!/bin/bash
confFile=$1
adminCrt=$2
adminKey=$3
groupID=$4
set -eux pipefail

apiEndpoint="https://127.0.0.1:18443/nifi-registry-api"
# groupID="nifiAdminGenerated"
curlCmd="curl -ks --key $adminKey --cert $adminCrt"
userIDFile=$confFile



testConnection()
{
  local test=$($curlCmd $apiEndpoint/access --write-out '%{http_code}' --output /dev/null )
  if [[ ! $? -eq 0 ]] || [[ -z $test ]] || [[ ! $test -eq 200 ]];then
    echo "${FUNCNAME[0]}: nifi-registry API not ready"
    return 1 
  fi
}

getGroupIdentifier()
{
  local groupID=$1
  createGroup=false
  #get ID for group $groupID
  #curl --key key.pem --cert crt.pem -ks https://127.0.0.1:18443/nifi-registry-api/tenants/users|jq -r '.[]|select(.identity=="tt-90981@csast.cz").identifier'
  groupIdentifier=$($curlCmd $apiEndpoint/tenants/user-groups|jq -r --arg groupID "$groupID"  '.[]|select(.identity==$groupID).identifier')
  if [[ ! $? -eq 0 ]] ;then
    echo "${funcname[0]}: nifi-registry api not ready"
    return 1
  fi
  if [[ -z $groupIdentifier ]];then
    createGroup=true
  fi
}

createGroup()
{
local groupID=$1
groupIdentifier=$($curlCmd -0 -X POST $apiEndpoint/tenants/user-groups \
-H "Expect:" \
-H 'Content-Type: application/json; charset=utf-8' \
--data @- << EOF|jq -r '.identifier'
{
  "configurable": true,
  "identity": "$groupID"
}
EOF
)
if [[ ! $? -eq 0 ]] ;then
  echo "${funcname[0]}: cannot create group $groupID"
  return 1
fi
}

setGroupPolicy()
{
#add all policies to groupID
  local groupIdentifier=$1
  local groupID=$2
  #get all policy
  policyList=$($curlCmd $apiEndpoint/policies|jq -r '.[].identifier')
  for policy in $policyList
   do 
      policyGroupAddJson=$($curlCmd $apiEndpoint/policies/$policy|jq --arg groupID "$groupID" --arg groupIdentifier "$groupIdentifier" \
			'.userGroups +=[{ "configurable": true, "identifier": $groupIdentifier, "identity": $groupID}]')
			policyPut=$($curlCmd -X PUT $apiEndpoint/policies/$policy \
		  --write-out '%{http_code}' \
			--silent\
			--output /dev/null \
			-X PUT \
			-H 'Content-Type: application/json; charset=utf-8' \
			--data "${policyGroupAddJson}")
  		if [[ $policyPut -eq 200 ]];then
  		  echo "updated policy \"$policy\" "
  		else
  		  echo "cannot update \"$policy\" "
  		  echo ${http_code}
  		fi
   done

}

#create a user defined in config fajl and add this user to groupID
getUserIdentifier()
{
  local userID=$1
  createUser=false
  #get ID for group $groupID
  #curl --key key.pem --cert crt.pem -ks https://127.0.0.1:18443/nifi-registry-api/tenants/users|jq -r '.[]|select(.identity=="tt-90981@csast.cz").identifier'
  userIdentifier=$($curlCmd $apiEndpoint/tenants/users|jq -r --arg userID "$userID"  '.[]|select(.identity==$userID).identifier')
  if [[ ! $? -eq 0 ]] ;then
    echo "${funcname[0]}: nifi-registry api not ready"
    return 1
  fi
  if [[ -z $userIdentifier ]];then
    createUser=true
  fi
}

createUser()
{
local userID=$1
userIdentifier=$($curlCmd -0 -X POST $apiEndpoint/tenants/users \
-H "Expect:" \
-H 'Content-Type: application/json; charset=utf-8' \
--data @- << EOF|jq -r '.identifier'
{
  "configurable": true,
  "identity": "$userID"
}
EOF
)
if [[ ! $? -eq 0 ]] ;then
  echo "${funcname[0]}: cannot create group $groupID"
  return 1
fi
}

addUserToGroup()
{
local groupIdentifier=$3
local userIdentifier=$2
local userID=$1

userGroupAddJson=$($curlCmd $apiEndpoint/tenants/user-groups/$groupIdentifier \
|jq --arg userID "$userID" --arg userIdentifier "$userIdentifier" \
'.users +=[{ "configurable": true, "identifier": $userIdentifier, "identity": $userID}]')

userPut=$($curlCmd -X PUT $apiEndpoint/tenants/user-groups/$groupIdentifier \
--write-out '%{http_code}' \
--silent \
--output /dev/null \
-X PUT \
-H 'Content-Type: application/json; charset=utf-8' \
--data "${userGroupAddJson}")

if [[ $userPut -eq 200 ]];then
  echo "User $userID added to group $groupIdentifier "
else
  echo "Cannot add $userID to group $groupIdentifier "
  echo ${http_code}
fi
}

getUsersInGroup()
{
local groupID=$1
usersInGroup=$($curlCmd $apiEndpoint/tenants/user-groups|jq -r --arg groupID "$groupID" '.[]|select(.identity==$groupID).users[].identity')
}

deleteUserFromGroup()
{
local userID=$1
local groupIdentifier=$2
deleteGroupUserJson=$($curlCmd $apiEndpoint/tenants/user-groups/$groupIdentifier|jq --arg userID "$userID" 'del(.users[] | select(.identity==$userID))')
userDelete=$($curlCmd -X PUT $apiEndpoint/tenants/user-groups/$groupIdentifier \
--write-out '%{http_code}' \
--silent \
--output /dev/null \
-X PUT \
-H 'Content-Type: application/json; charset=utf-8' \
--data "${deleteGroupUserJson}")

if [[ $userDelete -eq 200 ]];then
  echo "User $userID deleted from group $groupIdentifier"
else
  echo "Cannot delete $userID from group $groupIdentifier"
  echo ${http_code}
fi
}

#-----main body------------#
LTIME=0

while true
 do
   ATIME=$(stat -c %Z $userIDFile)

    if [[ "$ATIME" != "$LTIME" ]]
    then
        LTIME=$ATIME

until testConnection;do
  sleep 10
done

getGroupIdentifier $groupID
#naplnena promena groupIdentifier bud existuje a nebo byla vytvorena
if [[ "$createGroup" = true ]];then
  createGroup $groupID
  setGroupPolicy $groupIdentifier $groupID
fi
if [[ -f "$userIDFile" ]]; then
  usersInFile=$(cat  $userIDFile |tr "\n" " ")
  for userID in $usersInFile
  do
  getUserIdentifier $userID
    if [[ "$createUser" = true ]];then
      createUser $userID
      addUserToGroup $userID $userIdentifier $groupIdentifier
    fi
  done
fi
#now remove from groupID users not in configFile
#Get the list of elements that appear in B and are not available in A, i.e. B\A
#$ echo ${A[@]} ${B[@]} | sed 's/ /\n/g' | sort | uniq -d | xargs echo ${B[@]} | sed 's/ /\n/g' | sort | uniq -u
getUsersInGroup $groupID
usersToRemove=$(echo $usersInFile $usersInGroup|sed 's/ /\n/g'|sort|uniq -d|xargs echo $usersInGroup|sed 's/ /\n/g'|sort|uniq -u)
if [[ ! -z "$usersToRemove" ]];then
 for userID in $usersToRemove
 do
   deleteUserFromGroup $userID $groupIdentifier
 done
fi

fi
sleep 10
done
