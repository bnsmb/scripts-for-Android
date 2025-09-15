#!/bin/bash
# 
# init_magisk_db.sh - shell script to enable root access via Magisk for specified apps
#
# History
#  05.12.2022 v1.0.0.0  /bs #VERSION
#    initial release
#  16.12.2022 v1.0.0.1  /bs #VERSION
#    corrected some errors in the messages of the script
#    corrected some minor errors in the comments in the script
#    replaced "echo" with "LogMsg" 
#  28.01.2023 v1.0.1.0  /bs #VERSION
#    the script did not work correct if more then one phone was connected due to missing adb options -- fixed
#  01.05.2023 v1.0.2.0 /bs #VERSION
#    in some cases the script ended with RC=0 even if enabling the root access failed -- fixed
#
#  30.04.2024 v1.0.3.0 /bs #VERSION
#    the script returned ${__TRUE} even if the final reboot failed -- fixed
#
#  08.08.2025 v1.0.4.0 /bs #VERSION
#    the script did not select the correct TWRP image in all cases --fixed
#

# This script can be used to enable root access via Magisk by adding the necessary entries to the sqlite database used by Magisk
#
# The script will boot the phone from an TWRP image and add the necessary entries in an adb session in TWRP to the sqlite database from Magisk.
#
# The script uses the script 
#
#    boot_phone_from_twrp.sh 
#
# to reboot the phone. The script "boot_phone_from_twrp.sh" must be available via PATH or in the directory with this script.
# The script can be downloaded from here: 
#
#     http://bnsmb.de/files/public/Android/boot_phone_from_twrp.sh
#
# The script uses the script
# 
#    enable_root_access_via_magisk.sh
#
# to process the Magisk sqlite database. The script "enable_root_access_via_magisk.sh" must be available via PATH or in the directory with this script.
# The script can be downloaded from here: 
#
#     http://bnsmb.de/files/public/Android/enable_root_access_via_magisk.sh
#
#H# Usage
#H# 
#h#    init_magisk_db.sh [-h|help|-H] [--list|-l] [--force|-f] [--reboot|--noreboot] [apps=app1,..,app#] 
#h#
#H# All parameter are optional. The parameter can be used in any order.
#H#
#H# Use the parameter "help" or "-H" to print the detailed usage help; use the parameter "-h" to print only the short usage help
#H#
#H# If the parameter "--list" is used the script will only print all apps for which root access would be enabled and exit
#H# 
#H# Use the parameter "--force" if the used Magisk version is not official supported by the script enable_root_access_via_magisk.sh.
#H#
#H# If the parameter "--reboot" is used the script will reboot the phone after enabling the root access; to disable the automatic reboot use the parameter "--noreboot".
#H# Default is to ask the user for confirmation to reboot the phone.
#H#
#H# The parameter "apps=app#" can be used to define the apps for which root access should be enabled. apps can be either the "name" of an app or the UID of an app.
#H# e.g.
#H# 
#H#     apps=com.android.shell,10123,com.keramidas.TitaniumBackup
#H# 
#H# The value of the parameter apps= will overwrite the default list of apps to be root enabled hardcoded in the script; to append the apps to the list of 
#H# hardcoded apps use a leading "+", e.g. apps="+app1,..,app#".
#H# The parameter can be used more then once; the leading "+" is mandatory in this case for all but the first occurance.
#H#
#H# To change some of the values used by the script you can set environment variables before starting the script:
#H#
#H#   Set the environment variable REBOOT to "yes" before starting the script to automatically reboot the phone after enabling the root access 
#H#   Set the environment variable REBOOT to "no" before starting the script to disable the automatic reboot after enabling the root access 
#H#
#H# See also the source code of the script
#H#
#H#   boot_phone_from_twrp.sh 
#H#
#H# for environment variables supported by this script
#H#
#H#
#H# Notes
#H#
#H# Use the Android command
#H# 
#H#   pm list packages 
#H# 
#H# in an adb shell to get the names of the installed apps; 
#H# 
#H# use the Android command
#H# 
#H#   pm list packages -U <appname> | cut -f3 -d ":"  
#H# 
#H# to get the UID of an app.
#H# 
#H#
#H# Prerequisites
#H#
#H# - a phone with installed Magisk
#H# - working adb and fastboot binaries on the PC
#H# - the phone must be connected via USB
#H# - access via adb must be enabled on the phone
#H#
#H# Details
#H#
#H# If the list of apps for enabling root access contains one or more app names the script will first boot the phone into the normal mode if not already running in that mode 
#H# to get the UIDs for these apps.
#H#

SCRIPT_VERSION="$( grep "^#" $0 | grep "#VERSION" | grep "v[0-9]" | tail -1 | awk '{ print $3}' )"

SCRIPT_NAME="${0##*/}"
SCRIPT_PATH="${0%/*}"

#
# for testing only
#
# PREFIX="echo"
PREFIX=""

#
# define constants
#
__TRUE=0
__FALSE=1

# Script return code
#
THISRC=${__TRUE}


# define global variables
#

# helper script to boot the phone from the TWRP image
#
TWRP_REBOOT_HELPER_SCRIPT="boot_phone_from_twrp.sh"

# helper script to add the entries to the Magisk sqlite database on the phone
#
MAGISK_DB_HELPER_SCRIPT="enable_root_access_via_magisk.sh"

# default apps that should be enabled for root access via Magisk (Shell only)
#
DEFAULT_APPS_FOR_ROOT_ACCESS="com.android.shell"



# ---------------------------------------------------------------------
# functions
#


# ----------------------------------------------------------------------
# LogMsg
#
# function: write a message to STDOUT
#
# usage: LogMsg [message]
#
function LogMsg {
  [ "$1"x = "-"x ] && shift

  echo "$*"
}

# ----------------------------------------------------------------------
# LogError
#
# function: write a message prefixed with "ERROR:" to STDERR
#
# usage: LogError [message]
#
function LogError {
  typeset THISMSG="$*"

  LogMsg "ERROR: ${THISMSG}" >&2
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
  typeset THISRC=$1
  [ $# -ne 0 ] && shift
  typeset THISMSG="$*"

  if [ "${THISMSG}"x != ""x ] ; then
    if [ ${THISRC} != 0 ] ; then
      LogError "${THISMSG} (RC=${THISRC})" >&2
    else
      LogMsg "${THISMSG}"
    fi
  fi

  exit ${THISRC}
}


# ----------------------------------------------------------------------
# isNumber
#
# function: check if a value is an integer
#
# usage: isNumber testValue
#
# returns: ${__TRUE} - testValue is a number else not
#
function isNumber {	
  typeset THISRC=${__FALSE}

  [[ $1 == +([0-9]) ]] && THISRC=${__TRUE} || THISRC=${__FALSE}

  return ${THISRC}
}

# ---------------------------------------------------------------------
# main function
#

LogMsg "${SCRIPT_NAME} version - ${SCRIPT_VERSION} - shell script to enable root access via Magisk for specified apps"
LogMsg ""

if [ "$1"x = "-h"x ] ; then
  grep "^#h#" $0 | cut -c4-
  die 10

elif [ "$1"x = "-H"x -o "$1"x = "--help"x -o "$1"x = "help"x -o "$1"x = "-help"x ] ; then
#
# extract the usage help from the script source
#
  grep -E "^#H#|^#h#" $0 | cut -c4-
 
  echo " The scripts boot_phone_from_twrp.sh and enable_root_access_via_magisk.sh are required by this script -- see the source code of the script"
  echo ""
  exit 1
fi


# default : do not reboot the phone when done
#
DO_REBOOT_THE_PHONE=${__TRUE}

#
# default for the parameter --list
#
LIST_APPS_AND_EXIT="${__FALSE}"

# 
# list of apps for which root access should be enabled
#
APPS_FOR_ROOT_ACCESS="${DEFAULT_APPS_FOR_ROOT_ACCESS}"

# work also with non-supported Magisk version if ${__TRUE}
#
FORCE=${__FALSE}

#
# process the parameter 
#
#    init_magisk_db.sh [-h|help|-H] [-list] [apps=app1,..,app#] 
#
while [ $# -ge 1 ] ; do

  case $1 in
    -list | --list | list | -l )
      LIST_APPS_AND_EXIT="${__TRUE}"
      ;;

    force | --force | -force | -f )
      FORCE=${__TRUE}
      ;;
      
    reboot | --reboot | -reboot )
      REBOOT=yes
      ;;

    noreboot | --noreboot | -noreboot )
      REBOOT=no
      ;;

    apps=* )
      CUR_APPS="${1#*=}"

      if [[ ${CUR_APPS} = +* ]] ; then
        APPS_FOR_ROOT_ACCESS="${APPS_FOR_ROOT_ACCESS},${CUR_APPS#*+}"
      else
        APPS_FOR_ROOT_ACCESS="${CUR_APPS}"
      fi    
      ;;

    * )
      die 6 "ERROR: Unknown parameter found: \"$1\" "
      ;;

  esac
  shift

done  


if [ ${LIST_APPS_AND_EXIT} =  ${__TRUE} ] ; then
  LogMsg ""
  LogMsg "Apps for which root access would be enabled using these parameter are:" 
  LogMsg ""
  LogMsg "  ${APPS_FOR_ROOT_ACCESS}"
  LogMsg ""
  LogMsg "The list of apps for enabling root access hardcoded in the script is:"
  LogMsg ""
  LogMsg "  ${DEFAULT_APPS_FOR_ROOT_ACCESS}"
  LogMsg ""

  die 0
fi

ERRORS_FOUND=${__FALSE}

if [ "${APPS_FOR_ROOT_ACCESS}"x = ""x ] ; then
  LogError "No apps for enabling root access defined"
  ERRORS_FOUND=${__TRUE}
fi

if [ -r "${SCRIPT_PATH}/${TWRP_REBOOT_HELPER_SCRIPT}" ] ; then
  CUR_TWRP_REBOOT_HELPER_SCRIPT="${SCRIPT_PATH}/${TWRP_REBOOT_HELPER_SCRIPT}"
else
  CUR_TWRP_REBOOT_HELPER_SCRIPT="$( which "${TWRP_REBOOT_HELPER_SCRIPT}" )"
fi

if [ "${CUR_TWRP_REBOOT_HELPER_SCRIPT}"x = ""x ] ; then
  LogError "TWRP helper script \"${TWRP_REBOOT_HELPER_SCRIPT}\" not found"
  ERRORS_FOUND=${__TRUE}
else
  LogMsg "Using the TWRP helper script \"${CUR_TWRP_REBOOT_HELPER_SCRIPT}\" "
fi

if [ -r "${SCRIPT_PATH}/${MAGISK_DB_HELPER_SCRIPT}" ] ; then
  CUR_MAGISK_DB_HELPER_SCRIPT="${SCRIPT_PATH}/${MAGISK_DB_HELPER_SCRIPT}"
else
  CUR_MAGISK_DB_HELPER_SCRIPT="$( which "${MAGISK_DB_HELPER_SCRIPT}" )"
fi

if [ "${CUR_MAGISK_DB_HELPER_SCRIPT}"x = ""x ] ; then
  LogError "Magisk helper script \"${MAGISK_DB_HELPER_SCRIPT}\" not found"
  ERRORS_FOUND=${__TRUE}
else
  LogMsg "Using the Magisk helper script \"${CUR_MAGISK_DB_HELPER_SCRIPT}\" "
fi

if [ ${ERRORS_FOUND} = ${__TRUE} ] ; then
  die 100 "One or more errors found. Exiting"
fi


if [ ${FORCE} = ${__TRUE} ] ; then
  MAGISK_HELPER_SCRIPT_PARAMETER=" -f "
else  
  MAGISK_HELPER_SCRIPT_PARAMETER=""
fi

#
# check if there are app names in the list of apps
#
APP_NAMES_FOUND=${__FALSE}

APPS_FOR_ROOT_ACCESS="$( echo " ${APPS_FOR_ROOT_ACCESS}" | tr "," " " )"

LogMsg "The apps for which root access should be enabled are: "
LogMsg "  ${APPS_FOR_ROOT_ACCESS}"

LIST_OF_APP_UIDS=""
LIST_OF_APP_NAMES=""

for THIS_APP in ${APPS_FOR_ROOT_ACCESS} ; do
  isNumber "${THIS_APP}"
  if [ $? -eq 0 ] ; then
    LIST_OF_APP_UIDS="${LIST_OF_APP_UIDS} ${THIS_APP}"
  else
    LIST_OF_APP_NAMES="${LIST_OF_APP_NAMES} ${THIS_APP}"
    APP_NAMES_FOUND=${__TRUE}
  fi
done

LogMsg "Apps that should be enabled are: ${LIST_OF_APP_NAMES}"
LogMsg "UIDs that should be enabled are: ${LIST_OF_APP_UIDS}"

if [ ${APP_NAMES_FOUND} = ${__TRUE} ] ; then
  LogMsg "Found one more app names in the list of apps "
fi


LogMsg "Reading the helper script \"${TWRP_REBOOT_HELPER_SCRIPT}\" ..."

. ${CUR_TWRP_REBOOT_HELPER_SCRIPT}

LogMsg "Retrieving the current status of the phone ..."

retrieve_phone_status

print_phone_status

if [ ${APP_NAMES_FOUND} = ${__TRUE} ] ; then

  LogMsg "Retrieving the UIDs for the app names ..."
  
  reboot_phone || die 100 "Can not boot the phone into the Android OS"
    
  for CUR_APP_NAME in ${LIST_OF_APP_NAMES} ; do
    LogMsg "Retrieving the UID for the app \"${CUR_APP_NAME}\" ..."
    CUR_APP_ID="$( ${ADB} ${ADB_OPTIONS} shell "pm list packages -U ${CUR_APP_NAME}  | grep -E "^package:${CUR_APP_NAME}[[:space:]]" | cut -f3 -d ':' " )"
    if [ "${CUR_APP_ID}"x = ""x ] ; then
      LogMsg "WARNING: The app \"${CUR_APP_NAME}\" is not installed; this app will be ignored"
    else
      LogMsg "The UID for the app \"${CUR_APP_NAME}\" is \"${CUR_APP_ID}\" "
      LIST_OF_APP_UIDS="${LIST_OF_APP_UIDS} ${CUR_APP_ID}"
    fi
  done
fi

if [ "${LIST_OF_APP_UIDS}"x = ""x ] ; then
  die 105 "The list of UIDs for enabling the root access is empty now"
fi

LogMsg "Will enable the root access via Magisk for these UIDs: ${LIST_OF_APP_UIDS}"

# reboot the script from the correct TWRP image
#
boot_phone_from_the_TWRP_image "${TEMP_TWRP_IMAGE_TO_USE}" || die 110 "Can not boot the phone from the TWRP image"


MAGISK_HELPER_SCRIPT_ON_THE_PHONE="/cache/${CUR_MAGISK_DB_HELPER_SCRIPT##*/}"
#MAGISK_HELPER_SCRIPT_ON_THE_PHONE="/tmp/${CUR_MAGISK_DB_HELPER_SCRIPT##*/}"

LogMsg "Copying the Magisk helper script \"${CUR_MAGISK_DB_HELPER_SCRIPT}\" to ${MAGISK_HELPER_SCRIPT_ON_THE_PHONE} on the phone ..."

CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} push ${CUR_MAGISK_DB_HELPER_SCRIPT} ${MAGISK_HELPER_SCRIPT_ON_THE_PHONE} 2>&1 )"
TEMPRC=$?
LogMsg "${CUR_OUTPUT}"
[ ${TEMPRC} != 0 ] && die 115 "Error copying the Magisk helper script \"${CUR_MAGISK_DB_HELPER_SCRIPT}\" to \"${MAGISK_HELPER_SCRIPT_ON_THE_PHONE}\" on the phone"

LogMsg "Executing the Magisk helper script \"${MAGISK_HELPER_SCRIPT_ON_THE_PHONE}\" on the phone now ..."

CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell sh "${MAGISK_HELPER_SCRIPT_ON_THE_PHONE} ${MAGISK_HELPER_SCRIPT_PARAMETER} ${LIST_OF_APP_UIDS}"  2>&1 )"
TEMPRC=$?
LogMsg "${CUR_OUTPUT}"
LogMsg ""

if [ ${TEMPRC} -eq ${__TRUE} ] ; then
  LogMsg "root access for the UIDs via Magisk successfully enabled"
  THISRC=0
else
  LogError "Error executing the Magisk helper script \"${MAGISK_HELPER_SCRIPT_ON_THE_PHONE}\" on the phone "
  THISRC=120
  REBOOT="no"
fi

if [ "${REBOOT}"x = "yes"x -o "${REBOOT}"x = "YES"x ] ; then
  DO_REBOOT_THE_PHONE=${__TRUE}
elif [ "${REBOOT}"x = "no"x -o "${REBOOT}"x = "NO"x ] ; then
  LogMsg "Automatically rebooting the phone is disabled"
  DO_REBOOT_THE_PHONE=${__FALSE}
else
  LogMsg ""
  printf "*** Press return to reboot the phone now"
  read USER_INPUT
  printf "\n"

  if [ "${USER_INPUT}"x = "n"x -o "${USER_INPUT}"x = "N"x ] ; then
    DO_REBOOT_THE_PHONE=${__FALSE}
  else
    DO_REBOOT_THE_PHONE=${__TRUE}
  fi
fi

if [ ${DO_REBOOT_THE_PHONE} = ${__TRUE} ] ; then
  LogMsg "Rebooting the phone now ..."

  retrieve_phone_status

  reboot_phone 
  THISRC=$?
fi

die ${THISRC}



