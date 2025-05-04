#!/system/bin/sh
#
#h#
#h# enable_wireless_adb.sh - enable adb via WiFi on a phone or tablet running the Android OS 
#h#
#h# Usage:
#h#
#h#    enable_wireless_adb.sh [--ignore_BSSID|-i] [--print_port|-p] [--print_port_file] [--reset_port|-r] [--nostatus|-s] [--verbose|-v]
#h#
#h#    --ignore_BSSID    - do NOT add the BSSID of the current WLAN to the adbd keystore
#h#                        Without this parameter the script adds the BSSID of the current WLAN to the adbd keystore if root access is available
#h#
#h#    --print_port      - only print the port used for adb via WiFI and exit
#h#
#h#    --print_port_file - print only the name of the file with the port created by this script
#h#
#h#    --reset_port      - disable adb via WiFi and then enable it again (this is useful for machines without root access (see below)
#h#
#h#    --nostatus        - do not create the semfile for this script
#h#
#h#    --verbose         - print more messages
#h#

#H#    The script waits up to 60 seconds until the settings command can be used and then activates
#H#    the development option, the adb via usb connection, and the adb via WiFi connection.
#H#
#H#    The script does nothing if the file "/cache/enable_wireless_adb_disabled" exists.
#H#    The script writes the messages to the file "/cache/enable_wireless_adb.log" if it runs in a session without tty
#H#
#H#    The script must run on the phone while the Android OS is running.
#H#
#H#    The script can be used as a script in the service.d for Magisk.
#H#
#H#    The script can be run as either root or non-root user; if run as non-root user without su support, the script
#H#    cannot correct the adbd keystore and, in most cases, not read the port used by adbd.
#H#
#H#    The script saves the port used for adb via WiFi in a file, if it can read the port -- either in the file /data/local/tmp/wireless_adb_port, if the
#H#    directory /data/local/tmp/ exists or, if not, in the file /cache/wireless_adb_port
#H#    Set the environment variable WIRELESS_ADB_PORT_FILE before running the script to use a different file.
#H#
#H#    The script assumes that adb via USB is already enabled and the adbd keystore is already configured with the rsa key for the host
#H#
#H#    If running without a tty (e.g from within the service.sh script from Magisk) the script writes all messages to the logfile /data/local/tmp/enable_wireless_adb.log if the
#H#    directory /data/local/tmp exists or, if not, in the file /cache/enable_wireless_adb.log
#H#    Set the environment variable ENABLE_WIRELESS_ADB_LOGFILE before running the script to use a different file.
#H#
#H#    If running as non-root user the code to find the TCP port used for adb ignores these ports:
#H#
#H#      5800 and 5900 (VNC ports)
#H#      all ports opened by an sshd started by the current user
#H#      all ports only listened on the local IP 127.0.0.1
#H#      

#
# History
#   15.01.2024 1.0.0.0 /bs
#     initial release
#
#   03.05.2025 2.0.0.0 /bs
#     added the missing su prefix to the chmod, chown, chcon commands for the file /data/misc/adb/adb_temp_keys.xml
#     the script now ignores adb via WiFi connections configured using the port configured in the property "persist.adb.tcp.port"
#     added the parameter "--ignore_BSSID" to disable adding the BSSID to the adbd keystore file
#     added the parameter "--print_port" to print the port used
#     added the parameter "--print_port_file" to print the file used to store the port 
#     added the parameter "--help" to print the script usage
#     added the parameter "--nostatus" to disable creating the semaphor file "/cache/enable_wireless_adb_disabled"
#     the script now saves the port used for adb via WiFi in a file, if it can read the port -- either in the file /data/local/tmp/wireless_adb_port, if the
#       directory /data/local/tmp/ exists or, if not, in the file /cache/wireless_adb_port
#     added code to read the port used by adb via WiFi if there is no root access:
#       the code works in most cases if adb via WiFi is not yet activated, 
#       but it does not work in most cases if adb via WiFI is already activated
#     the logfile of the script is now /data/local/tmp/enable_wireless_adb.log if the directory /data/local/tmp exists
#       if the directory does not exist the log file is /cache/enable_wireless_adb.log
#     added support for the variable ENABLE_WIRELESS_ADB_LOGFILE
#

# for debugging:
#
# set -x

# define some constants
#
__TRUE=0
__FALSE=1

# -----------------------------------------------------------------------------

QUIET_MODE=${__FALSE}
[[ " $* " == *\ --print_* || " $* " == *\ --print-* ||  " $* " == *\ -p\ * ]] && QUIET_MODE=${__TRUE} 

# -----------------------------------------------------------------------------

function LogMsg {
  typeset THISRC=${__FALSE}  

  if [ ${QUIET_MODE} != ${__TRUE} ] ; then
    echo "$*"
    THISRC=${__TRUE}
  fi

  return ${THISRC}
}


function LogRotate {
  typeset CUR_FILE
  typeset i=0
  typeset j=0
  
  while [ $# -ne 0 ] ; do
    CUR_FILE="$1"
    shift

    [ ! -r "${CUR_FILE}" ] && continue

    for i in 8 7 6 5 4 3 2 1 0 ; do
      let j=i+1
      [ -r "${CUR_FILE}.${i}" ] && mv "${CUR_FILE}.${i}" "${CUR_FILE}.${j}"
    done
    mv "${CUR_FILE}" "${CUR_FILE}.0"
  done
}

# -----------------------------------------------------------------------------

LogMsg "$0 -- enabling adb connections via WLAN"

# -----------------------------------------------------------------------------
#
# logfile to use if running in a session without tty (e.g from within a Magisk Module)
#
if [ "${ENABLE_WIRELESS_ADB_LOGFILE}"x = ""x ] ; then
  if [ -d /data/local/tmp ] ; then
    ENABLE_WIRELESS_ADB_LOGFILE="/data/local/tmp/enable_wireless_adb.log"
  else
    ENABLE_WIRELESS_ADB_LOGFILE="/cache/enable_wireless_adb.log"
  fi
fi

# ---------------------------------------------------------------------
#
# check if we're running in a session with tty
#
if [ ${QUIET_MODE} != ${__TRUE} ] ; then

  /system/bin/tty -s 
  if [ $? -eq 0 ] ; then 
    LogMsg "Running in a session with tty "
    RUNNING_WITH_TTY_SESSION=${__TRUE}
  else
    LogRotate "${ENABLE_WIRELESS_ADB_LOGFILE}"

    LogMsg "Running in a session without tty -- using the logfile \"${ENABLE_WIRELESS_ADB_LOGFILE}\" "
    exec 2>"${ENABLE_WIRELESS_ADB_LOGFILE}" 1>&2
    RUNNING_WITH_TTY_SESSION=${__FALSE}
  fi

  if [ -r /data/local/tmp/trace ] ; then
    set -x
  fi    

fi

# ---------------------------------------------------------------------
#
# check if root access is working
#
ROOT_ACCESS_OKAY=${__TRUE}

# the user running this script
#
CUR_USER="$( id -un )"

SU_PREFIX=""

if [ "${CUR_USER}" != "root"x ] ; then
  LogMsg "Running as non-root user"
  CUR_OUTPUT="$( su - -c "id -un" 2>/dev/null )"
  if [ "${CUR_OUTPUT}"x != "root"x ] ; then
    LogMsg "WARNING: root access not supported -- can not correct the adbd keystore and can not check the port used by the adbd"
    ROOT_ACCESS_OKAY=${__FALSE}
  else
    LogMsg "root access via \"su\" command works"
    SU_PREFIX="su - -c "      
  fi
fi

# ---------------------------------------------------------------------
# semaphor file - the script will do nothing if this file exists 
# The semphore is only used if the script is running as root user (e.g. from within a Magisk Module)
#
SEMFILE="/cache/enable_wireless_adb_disabled"

# ---------------------------------------------------------------------

# file with the port used for adb via WiFi; this file is created by this script
#
if [ "${WIRELESS_ADB_PORT_FILE}"x = ""x ] ;then
  if [ -d /data/local/tmp/ ] ; then
    WIRELESS_ADB_PORT_FILE="/data/local/tmp/wireless_adb_port"
  else
    WIRELESS_ADB_PORT_FILE="/cache/wireless_adb_port"
  fi
fi

# ---------------------------------------------------------------------
# return code 
#
THISRC=${__TRUE}

# help variable for the script flow
#
CONT=${__TRUE}

VERBOSE=${__FALSE}

# maximum time in seconds to wait until the command "settings" work
#
MAX_WAIT_TIME_IN_SECONDS=60

# maximum time in seconds to wait until the network config is done
#
MAX_IP_TIME_IN_SECONDS=60


# do not add the BSSID to the adbd keystore if this variable is ${__TRUE}
#
IGNORE_BSSID=${__FALSE}

#
# executable to change the settings
#
SETTINGS="/system/bin/settings"

# this variable will be set to true if the settings binary is working
#
SETTINGS_IS_WORKING=${__FALSE}


# directory with the adbd keystore
#
ADBD_KEYSTORE_DIRECTORY="/data/misc/adb"

# temporary files used to check and correct the adbd keystore
#
ADB_TEMP_KEYSTORE="${ADBD_KEYSTORE_DIRECTORY}/adb_temp_keys.xml"
ADB_TEMP_KEYSTORE_PLAIN_XML="${ADB_TEMP_KEYSTORE}.plain.$$"
ADB_TEMP_KEYSTORE_NEW="${ADB_TEMP_KEYSTORE}.new.$$"
ADB_TEMP_KEYSTORE_BACKUP="${ADB_TEMP_KEYSTORE}.backup.$$"

ADB_WIFI_IS_ALREADY_ENABLED=${__FALSE}

ENABLING_ADB_WIFI_WAS_SUCCESSFULL=${__FALSE}

# the TMP_SCRIPT is only used if root access is working
#
TMP_SCRIPT="/cache/conv_xml.$$.sh"

PERSIST_ADB_PORT="$( getprop persist.adb.tcp.port )"

# disable adb via WiFi and then enable it again if this variable is ${__TRUE}
#
RESET_ADB_VIA_WIFI=${__FALSE}

# ---------------------------------------------------------------------
#

PRINT_USAGE=${__FALSE}

CREATE_SEMAPHOR_FILE=${__TRUE}

while [ $# -ne 0 ] ; do

  CUR_PARAMETER="$1"
  shift
  
  case ${CUR_PARAMETER} in

    --print_port | --print-port | -p )
      cat "${WIRELESS_ADB_PORT_FILE}" 
      exit 0
      ;;

    --print_port_file )
      echo "${WIRELESS_ADB_PORT_FILE}" 
      exit 0
      ;;

    --help | -h )
      PRINT_USAGE=${__TRUE}
      ;;

    --verbose | -v )
      VERBOSE=${__TRUE}
      ;;

    --ignore_BSSID | --ignore-BSSID |-i )
      LogMsg "Disabling adding the WLAN BSSID to the adbd keystore"
      IGNORE_BSSID=${__TRUE}
      ;;

    --reset_port | --reset-port | -r )
      RESET_ADB_VIA_WIFI=${__TRUE}
      ;;

    --nostatus | -s )
      CREATE_SEMAPHOR_FILE=${__FALSE}
      ;;

    * )
      LogMsg "ERROR: Invalid parameter found: ${CUR_PARAMETER}"
      exit 10
      ;;
  esac
done  

if [ ${PRINT_USAGE} = ${__TRUE} ] ; then

  grep "^#h#" $0 | cut -c4-
  
  if [ ${VERBOSE} = ${__TRUE} ] ; then
    grep "^#H#" $0 | cut -c4-
  fi
  
  exit 0

fi


# ---------------------------------------------------------------------
#
# check if the sempahor file exists
#
if [ -r "${SEMFILE}" ] ; then
  if [ ${RUNNING_WITH_TTY_SESSION} = ${__TRUE} ] ; then
    LogMsg "WARNING: The file \"${SEMFILE}\" exists but we're running in a tty session"
  else
    LogMsg "$0: The file \"${SEMFILE}\" exists -- will do nothing "
    THISRC=${__TRUE}
    CONT=${__FALSE}
  fi
fi

# ---------------------------------------------------------------------
# delete the output file
#
[ -r "${WIRELESS_ADB_PORT_FILE}" ] && ${SU_PREFIX} \rm -f "${WIRELESS_ADB_PORT_FILE}"

# ---------------------------------------------------------------------

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  LogMsg "Waiting up to ${MAX_WAIT_TIME_IN_SECONDS} seconds until the network config is done ..."

  i=0
  while [ $i -lt ${MAX_IP_TIME_IN_SECONDS} ] ; do
#
# the IP in the WLAN on the running Android OS 
#
    CUR_IP="$( ip addr list | grep -e "global wlan0" | awk '{ print $2}' | cut -f1 -d "/" )"

#    CUR_IP="$( ifconfig wlan0 | grep "inet addr" | awk '{ print $2}' | cut -f2 -d ":" )"

    if [ "${CUR_IP}"x != ""x ] ; then
      break
    else
      let i=i+1
      sleep 1
      printf "."
   fi
  done
  printf "\n"
fi

# the BSSID of the currently connected WLAN
#

if [ "${CUR_IP}"x != ""x ] ; then
  LogMsg "The network config is done after ${i} seconds"

  WIFI_BSSID="$( dumpsys wifi | grep mLastBssid | awk '{ print $2}'   )"
else
  LogMsg "The network config is not done after ${i} seconds."

  WIFI_BSSID=""
fi

# ---------------------------------------------------------------------


if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  LogMsg "Waiting up to ${MAX_WAIT_TIME_IN_SECONDS} seconds until the settings command works ..."

  i=0
  while [ $i -lt ${MAX_WAIT_TIME_IN_SECONDS} ] ; do
    if [ -x "${SETTINGS}" ] ; then
      "${SETTINGS}" get global development_settings_enabled 2>/dev/null  1>/dev/null 
      if [ $? -eq 0 ] ; then
        SETTINGS_IS_WORKING=${__TRUE}
        break
      fi
    fi
    let i=i+1    
    sleep 1
    printf "."

  done
  printf "\n"

  if [ ${SETTINGS_IS_WORKING} != ${__TRUE} ] ; then
    LogMsg "ERROR: The command settings still does not work - probably you should increase the  wait time; current value is ${MAX_WAIT_TIME_IN_SECONDS} seconds"
    CONT=${__FALSE}
    THISRC=${__FALSE}
  else
    LogMsg "The time to wait until the command \"${SETTINGS}\" works was ${i} seconds"
  fi  
fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then

  LogMsg "Retrieving the current values for the adb connections ..."
  
  ADB_ENABLED="$( "${SETTINGS}" get global adb_enabled )"

  ADB_WIFI_ENABLED="$( "${SETTINGS}" get global adb_wifi_enabled )"

  LogMsg "The current value for the setting \"global adb_enabled\" is : ${ADB_ENABLED}"
  LogMsg "The current value for the setting \"global adb_wifi_enabled\" is : ${ADB_WIFI_ENABLED}"

  if [ "${ADB_WIFI_ENABLED}"x = "1"x ] ; then
    LogMsg "The adb WIFI connection is already enabled"
    ADB_WIFI_IS_ALREADY_ENABLED=${__TRUE}

    if [ ${RESET_ADB_VIA_WIFI} = ${__TRUE} ] ; then
      LogMsg "Reset the adb via Wifi connection requested via parameter -- now temporary disabling adb via Wifi ..."
      "${SETTINGS}" put global adb_wifi_enabled 0

    else
      THISRC=${__TRUE}
      CONT=${__FALSE}
    fi
  fi
fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then

  DEVELOPMENT_SETTINGS_ENABLED="$( "${SETTINGS}" get global development_settings_enabled )"
  
  LogMsg "The current value for the setting \"global development_settings_enabled\" is : ${DEVELOPMENT_SETTINGS_ENABLED}"

  if [ "${DEVELOPMENT_SETTINGS_ENABLED}"x = "1"x ] ; then
    LogMsg "The development settings are already enabled"
  else
    LogMsg "Now enabling the development settings ...."
    "${SETTINGS}" put global development_settings_enabled 1 
    if [ $? -ne 0 ] ; then
      LogMsg "ERROR: Something went wrong enabling the development settings"
      THISRC=${__FALSE}
      CONT=${__FALSE}
    fi
  fi
fi



if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} -a ${IGNORE_BSSID} != ${__TRUE} ] ; then

  LogMsg "Checking if the current WLAN is already configured in the adbd keystore ..."

  if [ "${WIFI_BSSID}"x = ""x ] ; then
    LogMsg "Can not detect the BSSID of the connected WLAN"
  else
    LogMsg "The BSSID of the connected WLAN is \"${WIFI_BSSID}\" "
  fi

  if [ "${WIFI_BSSID}"x = ""x ] ; then
    :
  elif [ ${ROOT_ACCESS_OKAY} != ${__TRUE} ]; then
    LogMsg "WARNING: Can neither read nor write the adbd keystore without root access"
  elif ! ${SU_PREFIX} test -r "${ADB_TEMP_KEYSTORE}" ; then
    LogMsg "WARNING: The adbd keystore \"${ADB_TEMP_KEYSTORE}\" does not yet exist"
  else
    LogMsg "Converting the file \"${ADB_TEMP_KEYSTORE}\" to a plain xml file \"${ADB_TEMP_KEYSTORE_PLAIN_XML}\" ..."
    ${SU_PREFIX} abx2xml "${ADB_TEMP_KEYSTORE}" "${ADB_TEMP_KEYSTORE_PLAIN_XML}"
    if [ $? -ne 0 ] ; then
      LogMsg "ERROR: Error converting the file \"${ADB_TEMP_KEYSTORE}\" to a plain xml file \"${ADB_TEMP_KEYSTORE_PLAIN_XML}\""
      ${SU_PREFIX} \rm -f "${ADB_TEMP_KEYSTORE_PLAIN_XML}" 2>/dev/null
    else
      LogMsg "Checking if the BSSID \"${WIFI_BSSID}\" is already configured in the adbd temporary keystore ..."
      
      ADBD_KEYSTORE_ALREADY_OKAY=${__TRUE}

      NEW_ADBD_KEYSTORE_ENTRIES=""

if [ 1 = 0 ] ; then
      ${SU_PREFIX} grep "adbKey key" "${ADB_TEMP_KEYSTORE_PLAIN_XML}" | grep "${CURRENT_PUB_KEY}" >/dev/null
      if [ $? -eq 0 ] ; then
        LogMsg "The current public key is already configured in the adbd keystore "
        NEW_ADBD_KEYSTORE_ENTRIES="${NEW_ADBD_KEYSTORE_ENTRIES}
<adbKey key=\"${CURRENT_PUB_KEY}\""
      else
        ADBD_KEYSTORE_ALREADY_OKAY=${__FALSE}
      fi
fi
            
      ${SU_PREFIX} grep "${WIFI_BSSID}" "${ADB_TEMP_KEYSTORE_PLAIN_XML}"
      if [ $? -eq 0 ] ; then
        LogMsg "The BSSID \"${WIFI_BSSID}\" is already configured in the adb temporary keystore "
      else
        ADBD_KEYSTORE_ALREADY_OKAY=${__FALSE}
      fi
 
      NEW_ADBD_KEYSTORE_ENTRIES="$( echo "${NEW_ADBD_KEYSTORE_ENTRIES}" | egrep -v "^$" )"

      LogMsg "New entries for the keystore: "
      LogMsg "---"
      LogMsg "${NEW_ADBD_KEYSTORE_ENTRIES}"
      LogMsg "---"


      ${SU_PREFIX} chmod 0600 /data/misc/adb/adb_temp_keys.xml
      ${SU_PREFIX} chown system:shell /data/misc/adb/adb_temp_keys.xml
      ${SU_PREFIX} chcon -v u:object_r:adb_keys_file:s0 /data/misc/adb/adb_temp_keys.xml   
      
      if [ ${ADBD_KEYSTORE_ALREADY_OKAY} = ${__TRUE} ] ; then
        ${SU_PREFIX} \rm -f "${ADB_TEMP_KEYSTORE_PLAIN_XML}" 2>/dev/null
      else
        LogMsg "The BSSID \"${WIFI_BSSID}\" is not yet configured in the adbd keystore - will add it now ...."
          cat <<EOT >"${TMP_SCRIPT}"
          set -x
          ps -ef | grep adbd
          stop adbd
          ps -ef | grep adbd
          sed -i "s#</keyStore>#  <wifiAP bssid=\"${WIFI_BSSID}\" />\n</keyStore>#g" "${ADB_TEMP_KEYSTORE_PLAIN_XML}" 
          unix2dos "${ADB_TEMP_KEYSTORE_PLAIN_XML}" 
          xml2abx "${ADB_TEMP_KEYSTORE_PLAIN_XML}" "${ADB_TEMP_KEYSTORE_NEW}" 
          cp "${ADB_TEMP_KEYSTORE}" "${ADB_TEMP_KEYSTORE_BACKUP}"
          cp "${ADB_TEMP_KEYSTORE_NEW}" "${ADB_TEMP_KEYSTORE}"  
          chmod 0600 "${ADB_TEMP_KEYSTORE}"
          chown system:shell "${ADB_TEMP_KEYSTORE}"
          chcon -v u:object_r:adb_keys_file:s0 "${ADB_TEMP_KEYSTORE}"
          ps -ef | grep adbd
          start adbd
          ps -ef | grep adbd
EOT
        ${SU_PREFIX} sh "${TMP_SCRIPT}"

        if [ $? -ne 0 ] ; then
          LogMsg "WARNING: Error adding the BSSID \"${WIFI_BSSID}\" to the xml file"
#          CONT=${__FALSE}
        fi
      fi
    fi
  fi
fi



if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then

  CUR_TCP_LISTEN_CONNECTIONS="$( netstat -tnl 2>/dev/null | grep LISTEN )"
  
  LogMsg "Now enabling the adb WIFI connection  ...."
  "${SETTINGS}" put global adb_wifi_enabled 1 
  if [ $? -ne 0 ] ; then
    LogMsg "${CUR_OUTPUT}"
    LogMsg "ERROR: Something went wrong enabling the adb WIFI connection"
    THISRC=${__FALSE}
  else
    LogMsg "Enabling the adb WIFI connection was successfull"

    LogMsg "Re-reading the values for the changed settings now ..."
  
    NEW_ADB_WIFI_ENABLED="$( "${SETTINGS}" get global adb_wifi_enabled )"
    LogMsg "The current value for the setting \"global adb_wifi_enabled\" is now : ${NEW_ADB_WIFI_ENABLED}"


    NEW_TCP_LISTEN_CONNECTIONS="$( netstat -tnl 2>/dev/null | grep LISTEN )"

    TEMP_LIST="${CUR_TCP_LISTEN_CONNECTIONS}                                                                                                  
${NEW_TCP_LISTEN_CONNECTIONS}"

    NEW_TCP_PORT="$( echo "${TEMP_LIST}" | egrep -v "^$" | tr "\t" " " | tr -s " " | sort | uniq -u  )"
    
    NO_OF_TCP_PORTS=$( echo "${NEW_TCP_PORT}" | egrep -v "127.0.0.1|sshd|:5800|:5900" | wc -l )

    if [ ${NO_OF_TCP_PORTS} -eq 1 ] ; then
      ENABLING_ADB_WIFI_WAS_SUCCESSFULL=${__TRUE}
    else
      NEW_TCP_PORT=""
    fi
    
  fi

fi

if [ ${ENABLING_ADB_WIFI_WAS_SUCCESSFULL} = ${__TRUE} -o ${ADB_WIFI_IS_ALREADY_ENABLED} = ${__TRUE} ] ; then
  LogMsg "Retrieving the port used for the adbd WiFi connection ..."
  CUR_OUTPUT="$(  ${SU_PREFIX} netstat -alnp 2>/dev/null | grep adb | grep " LISTEN "  )"
  
  if [ "${PERSIST_ADB_PORT}"x != ""x ] ; then
    LogMsg "INFO: adb via WiFi is also configured on port ${PERSIST_ADB_PORT} via the property \"persist.adb.tcp.port\" "
    CUR_OUTPUT="$( echo "${CUR_OUTPUT}" | grep -v  ":${PERSIST_ADB_PORT} " )"
  fi
      
  if [ "${CUR_OUTPUT}"x = ""x ] ; then

    if [ "${NEW_TCP_PORT}"x != ""x ] ; then
      LogMsg "WARNING: Can not read the port used by adb from the output of netstat (most probably there is no root access)"
      LogMsg "         Assuming this is the port used by adb via WiFi: \"${NEW_TCP_PORT}\" "
      CUR_OUTPUT="${NEW_TCP_PORT}"

    else

      LogMsg "WARNING: Can not read the port used by adb for WiFi connections from the output of netstat (most probably there is no root access)"

      NEW_TCP_PORT="$( netstat -ntlp  2>/dev/null | grep LISTEN  | tr "\t" " " | tr -s " " | grep -v ":${PERSIST_ADB_PORT} " | egrep -v "127.0.0.1|sshd|:5800 |:5900 " )"
      NO_OF_TCP_PORTS=$( echo "${NEW_TCP_PORT}" | wc -l )

      if [ ${NO_OF_TCP_PORTS} -eq 1 ] ; then
        LogMsg "         Assuming this is the port used by adb via WiFi: \"${NEW_TCP_PORT}\" "
        CUR_OUTPUT="${NEW_TCP_PORT}"
      else
        LogMsg "         TCP port used by adb via WiFi not found"
        NEW_TCP_PORT=""    
      fi
    fi
  fi

  if [ "${CUR_OUTPUT}"x = ""x ] ; then
    LogMsg "WARNING: Can not detect the port used by the adbd for WiFi connections -- please check the GUI on the phone for a confirmation request"
  else
    CUR_ADBD_PORT="$( echo "${CUR_OUTPUT}" | awk '{ print $4}' | awk -F:  '{ print $NF}' )"
    if [ "${CUR_ADBD_PORT}"x = ""x ] ; then
      LogMsg "WARNING: Can not detect the port used by the adbd for WiFi connections -- please check the GUI on the phone for a confirmation request"
    else
    
      LogMsg "${CUR_ADBD_PORT}" >"${WIRELESS_ADB_PORT_FILE}" 
  
      LogMsg "The adbd is listening on the port ${CUR_ADBD_PORT}"
      LogMsg "Use

adb -e -L tcp:localhost:5237 connect ${CUR_IP}:${CUR_ADBD_PORT}

to connect to the adbd via WiFi (5237 can be any free port on the PC)"
    fi
  fi
fi
 
if [ ${RUNNING_WITH_TTY_SESSION} = ${__FALSE} ] ; then
  if [ ${CREATE_SEMAPHOR_FILE} = ${__TRUE} ] ; then
    if [ ${ENABLING_ADB_WIFI_WAS_SUCCESSFULL} = ${__TRUE} ] ; then
  
      LogMsg "Enabling adb was successfull - will now disable the automatic start of this script"
#
# disable the automatic start of the script for the next reboots if executed via Magisk
#
      touch "${SEMFILE}"    
    else
      LogMsg "Enabling adb via WiFi was not successfull - will not disable the automatic start of this script"
    fi
  else
    rm -f "${SEMFILE}" 
  fi
fi

exit 0
