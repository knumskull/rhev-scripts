#!/bin/bash
#
#
# Copyright (c) 2016 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
API_VERSION=3

# define API_HOST like, 'rhev-m.example.com'
API_HOST="rhevm-a.rhev.gsslab.bne.redhat.com"
API_URI="https://${API_HOST}/ovirt-engine/api"
API_USER=admin@internal

# the password is located separately in the file '.apipasswd' beside this script'
[[ -f '.apipasswd' ]] && [[ -n $(cat .apipasswd) ]] && API_PASSWD=$(cat .apipasswd)
[[ -z "API_PASSWD" ]] && echo "You need to specify API password in file '.apipasswd'" && exit 1

# check if ca.crt already exist
CACERT=ca.crt
[[ ! -f 'ca.crt' ]] && curl -o ca.crt "http://${API_HOST}/ovirt-engine/services/pki-resource?resource=ca-certificate&format=X509-PEM-CA"


########################################
### No modifications below this line ###
pushd `dirname $0` > /dev/null
BASE=$(pwd -P)
popd > /dev/null


API_CREDENTIALS="${API_USER}:${API_PASSWD}"

api_call () {
  api_uri=$1
  rc=$(curl -s --cacert ${CACERT} -X GET -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/${api_uri}")
  echo $rc
}

get_host_id () {
  _host_name=$1
  _stdout=$(curl -s --cacert ${CACERT} -X GET -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/hosts?search={$_host_name}" )
  _cnt=$(echo $_stdout | python -c "import sys, json; print len(json.load(sys.stdin)['host'])")
  _HOST_ID=$(echo $_stdout | python -c "import sys, json; print json.load(sys.stdin)['host'][0]['id']" 2>/dev/null)

  if [ -z "$_HOST_ID" ]; then
    echo "[$(date '+%c')] [ERROR] The Hypervisor Host with name '$_host_name' was not found: "
    #exit 1
  elif [ $_cnt -gt 1 ]; then
    echo "[$(date '+%c')] [ERROR] The name of the Hypervisor Host was not explicit enough. ($_host_name). There are multiple HOSTs ($_cnt) with a similar name."
    #exit 1
  else
    echo $_HOST_ID
  fi
}

get_pm_status () {
  _host_name=$1
  _host_id=$(get_host_id ${_host_name})
  _stdout=$(curl -s --cacert ${CACERT} -X GET -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/hosts/${_host_id}" )
  _HOST_PM_STATUS=$(echo $_stdout | python -c "import sys, json; print json.load(sys.stdin)['power_management']['enabled']" 2>/dev/null)

  echo $_HOST_PM_STATUS
}

usage () {
  echo "usage: `basename $0` [status|disable|enable] <hostname>"
  exit 1


}


main () {
  [ -n "$2" ] && _HOST=$2 || (echo "You need to specify a hostname"; usage)
  case $1 in
   "status")
       echo -n "Powermanagement Status of Host ${_HOST}: "
       _state=$(get_pm_status ${_HOST})
       [[ "${_state}" == "true" ]] && echo "ON" || echo "OFF"
       ;;
   "disable")
       echo -n "Disable Powermanagement on Host ${_HOST} ..."
       ;;
   "enable")
       echo -n "Enable Powermanagement on Host ${_HOST} ..."
       ;;
   *) echo invalid option;;
  esac


  #CHECK_MGMT_VM_STATUS && echo "[$(date '+%c')] [INFO ] Status of VM: $MGMT_VM O.K." | tee -a activity.log
}

###########  MAIN  ###########

# call the do_check_vm routine with parameter 'name of the vm, which needs to be checked'
 main $*