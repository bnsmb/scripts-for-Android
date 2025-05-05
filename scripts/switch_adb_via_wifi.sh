#!/system/bin/sh
#
#h# switch_adb_via_wifi.sh - enable or disable the adb via WiFi
#h#
#h# Usage:  switch_adb_wifi.sh [-h|--help] [-v|--verbose] [-q|--quiet] [start|stop|enable|disable|status|query]
#h#
#H# Parameter:
#H# 
#H# start or enable   - enable adb via WiFi; return code is 0 if adb via WiFi is enabled; else an error occured
#H# stop or disable   - disable adb via WiFi; return code is 0 if adb via WiFi is disabled; else an error occured
#H# status            - return the current status of adb via WiFi: 0 - adb via WiFi is enabled; 1 adb via Wifi is disabled; else an error occured
#H# query             - like status but without any message
#H#
#
# History
#
#   05.05.2025 v1.0.0
#     initial version
#

# -----------------------------------------------------------------------------
# define constants
#
__TRUE=0
__FALSE=1

# -----------------------------------------------------------------------------
#

SCRIPT_NAME="${0##*/}"

SCRIPT_DIR="${0%/*}"

VERBOSE=${__FALSE}

QUIET=${__FALSE}

ACTION=""

PRINT_USAGE=${__FALSE}

# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
#
function LogMsg {
  if [ ${QUIET} = ${__FALSE} ] ; then
    echo "$*"
  fi
}

function LogInfo {
  if [ ${VERBOSE} = ${__TRUE} ] ; then
    LogMsg "INFO: $*"
  fi
}

function LogWarning {
  LogMsg "WARNING: $*" >&2
}

function LogError {
  LogMsg "ERROR: $*" >&2
}

# ----------------------------------------------------------------------
# die
#
# function: print a message and end the script
#
# usage: die [script_exit_code] [message]
#
# the parameter "message" is optional; the script will add a leading "ERROR: "
# to the message if the script_exit_code is not zero
#
# returns: n/a
#
function die  {
  THISRC=$1
  [ $# -ne 0 ] && shift
  THISMSG="$*"

  if [ "${THISMSG}"x != ""x ] ; then
    if [ ${THISRC} != 0 ] ; then
      LogError "${THISMSG} (RC=${THISRC})" 
    else
      LogMsg "${THISMSG}"
    fi
  fi

  exit ${THISRC}
}
# -----------------------------------------------------------------------------

[ $# -eq 0 ] && PRINT_USAGE=${__TRUE}

while [ $# -ne 0 ] ; do

  CUR_PARAMETER="$1"
  shift
  
  case ${CUR_PARAMETER} in
  
    -h | --help | help )
      PRINT_USAGE=${__TRUE}
      ;;

    -v | --verbose )
      VERBOSE=${__TRUE}
      ;;

    -q | --quiet )
      QUIET=${__TRUE}
      ;;

    start | stop | status | query | enable | disable )
      if [ "${ACTION}"x != ""x ] ; then
        die 5 "Duplicate action parameter found: ${CUR_PARAMETER}"
      fi
      ACTION="${CUR_PARAMETER}"
      [ "${CUR_PARAMETER}"x = "query"x ] && QUIET=${__TRUE}
      ;;

    * )
      die 10 "Unknown parameter found: ${CUR_PARAMETER}"
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

# -----------------------------------------------------------------------------

THISRC=0

SETTINGS="$( which settings 2>/dev/null )"
[ "${SETTINGS}"x = ""x ] && die 15 "This script must run in a shell on a phone or tablet running Android"


[ ${VERBOSE} = ${__TRUE} ] && set -x
CUR_DEVELOPER_OPTIONS="$( "${SETTINGS}" get global development_settings_enabled 2>/dev/null )"
CUR_ADB_ENABLED_OPTION="$( "${SETTINGS}" get global adb_enabled 2>/dev/null )"
CUR_WIRELESS_ENABLED_OPTION="$( "${SETTINGS}" get global adb_wifi_enabled 2>/dev/null )"
[ ${VERBOSE} = ${__TRUE} ] && set +x
 
case ${ACTION} in

  start | enable )
    if [ "${CUR_WIRELESS_ENABLED_OPTION}"x = "1"x ] ; then
      LogMsg "adb via WiFI is already enabled"
      THISRC=0
    else
      LogMsg "Enabling adb via WiFi ..."

      [ ${VERBOSE} = ${__TRUE} ] && set -x
      
      [ "${CUR_DEVELOPER_OPTIONS}"x != "1"x ] && "${SETTINGS}"  put global "development_settings_enabled" 1 
      [ "${CUR_ADB_ENABLED_OPTION}"x != "1"x ] && "${SETTINGS}"  put global "adb_enabled" 1
      [ "${CUR_WIRELESS_ENABLED_OPTION}"x != "1"x ] && "${SETTINGS}"  put global "adb_wifi_enabled" 1

      [ ${VERBOSE} = ${__TRUE} ] && set +x

      CUR_WIRELESS_ENABLED_OPTION="$( "${SETTINGS}" get global adb_wifi_enabled 2>/dev/null )"
      if [ "${CUR_WIRELESS_ENABLED_OPTION}"x = "1"x ] ; then
        LogMsg "adb via WiFI is enabled now"
        THISRC=0
      else
        LogError "Error enabling adb via WiFi"
        THISRC=1
      fi
    fi
    ;;
      
  stop | disable )
    if [ "${CUR_WIRELESS_ENABLED_OPTION}"x = "0"x ] ; then
      LogMsg "adb via WiFI is already disabled"
      THISRC=0
    else
      LogMsg "Disabling adb via WiFi ..."
      "${SETTINGS}"  put global "adb_wifi_enabled" 0
      CUR_WIRELESS_ENABLED_OPTION="$( "${SETTINGS}" get global adb_wifi_enabled 2>/dev/null )"
      if [ "${CUR_WIRELESS_ENABLED_OPTION}"x = "0"x ] ; then
        LogMsg "adb via WiFI is disabled now"
        THISRC=0
      else
        LogError "Error disabling adb via WiFi"
        THISRC=1
      fi
    fi
    ;;
      
  status | query )
    if [ "${CUR_WIRELESS_ENABLED_OPTION}"x = "1"x ] ; then
      LogMsg "adb via WiFI is enabled"
      THISRC=0
    else
      LogMsg "adb via WiFI is disabled"
      THISRC=1
    fi
    ;;
    
esac

exit ${THISRC}


