#!/bin/bash
# 
# enable_access_via_adb.sh - shell script to enable adb access via an Init .rc file configured by Magisk 
#
# History
#  28.12.2022 v1.0.0.0  /bs #VERSION
#    initial release
#
#  06.01.2023 v1.1.0.0 /bs #VERSION
#    added the parameter "wait" and "nowait"
#
#  01.04.2023 v1.2.0.0 /bs #VERSION
#    added code to check which user started the adb daemon and print an error message if the daemon was not started by the user running this script
#
#  30.04.2024 v1.3.0.0 /bs #VERSION
#    added the parameter _a and _b to select the slot that should be patched
#
# This script can be used to enable access via adb in an new installed Android OS without enabled adb.
# The script will do nothing if adb is already enabled in the OS ruunning on the attached phone. 
#
# The phone must be either booted from a recovery partition or a recovery image with enabled adb access (like for example TWRP)
# Or the phone must be booted into the bootloader or fastbootd
# Magisk must be already installed in the boot partition of the phone.
#
#
# This script uses the script
#
#    boot_phone_from_twrp.sh 
#
# to check the status of the attached phone and also to reboot the phone from a recovery image if necessary.
#
# The script "boot_phone_from_twrp.sh" must be available via PATH or in the directory with this script.
# The script can be downloaded from here: 
#
#     http://bnsmb.de/files/public/Android/boot_phone_from_twrp.sh
#
#
# To enable the access via adb the script copies the script
# 
#    enable_adb_using_magisk.sh
#
# to the directory /tmp on the phone and executes the script then on the phone.
#
# enable_adb_using_magisk.sh creates the temporary script /data/recovery/enable_adb_via_service.sh on the phone.
# enable_adb_using_magisk.sh also creates an additional init .rc file using Magisk to start the script /data/recovery/enable_adb_via_service.sh after the next reboot of the phone.
# /data/recovery/enable_adb_via_service.sh then enables the developer options and the adb connections in the Android OS. The script also configures the public ssl key for accessing the
# phone via adb.
#
# The script/data/recovery/enable_adb_via_service.sh uses the semaphor file /data/recovery/adb_initialized to only start once 
#   (-> the script does nothing if the file /data/recovery/enable_adb_via_service.sh exists on the phone)
#
# The script "enable_adb_using_magisk.sh" can be downloaded from here: 
#
#     http://bnsmb.de/files/public/Android/enable_adb_using_magisk.sh
#
#H# Usage
#H# 
#h#    enable_access_via_adb.sh [-h|help|-H] [--reboot|--noreboot]  [-a|-b] [wait|nowait] [--nopubkey|--pubkey]
#h#
#H# All parameter are optional. The parameter can be used in any order.
#H#
#H# Use the parameter "help" or "-H" to print the detailed usage help; use the parameter "-h" to print only the short usage help
#H#
#H# If the parameter "--reboot" is used the script will reboot the phone after installing Init .rc file; to disable the automatic reboot use the parameter "--noreboot".
#H# Default is to ask the user for confirmation to reboot the phone.
#H#
#H# Use the parameter "wait" to wait until the reboot of the phone at script end is successfully done; use the parameter "nowait" to not wait for the reboot to finish.
#H# Default is "nowait".
#H#
#H# Use the parameter "--nopubkey" to disable configuring the public key of the current user on the PC for the access via adb; use the parameter "--pubkey" to configure
#H# the public key; default is to configure the public key.
#H# The default public ssl key used is the key in the file "${HOME}/.android/adbkey.pub".
#H#
#H# Use the parameter "_a" or "_b" to select the boot slot that should be patched; the default boot slot to patch is the inactive boot slot
#H#
#H# To change some of the values used by the script these environment variables can be set before starting the script:
#H#
#H#   Set the environment variable PUBLIC_KEY_ON_PC to the file with the public ssl key to use for the access via adb if another public key should be used.
#H#   [Update 02.04.2024]
#H#    PUBLIC_KEY_ON_PC can contain multiple public ssh keys in a separate lines; lines starting with a hash "#" are ignored.
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
#H# Prerequisites
#H#
#H# - the phone must be connected via USB
#H# - Magisk must be already installed in the boot partition of the phone
#H# - the phone must be either booted into the fastbootd or bootloader with a working fastboot connection
#H#   or already booted into a recovery image with working adb connnection
#H#
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

# helper script to boot the phone from the TWRP image if necessary
#
TWRP_REBOOT_HELPER_SCRIPT="boot_phone_from_twrp.sh"


# Helper Script to configure the init .rc file using Magisk
#
MAGISK_HELPER_SCRIPT="enable_adb_using_magisk.sh"

# Magisk helper script on the phone
#
MAGISK_HELPER_SCRIPT_ON_THE_PHONE="/tmp/${MAGISK_HELPER_SCRIPT}"


# configure the public key of the current user for adb access? (default is yes)
#
CONFIGURE_PUBLIC_KEY_FOR_ADB=${__TRUE}


# default public ssl key for the access via adb
#
DEFAULT_PUBLIC_KEY_ON_PC="${HOME}/.android/adbkey.pub"

# public ssl key for the access via adb 
#
PUBLIC_KEY_ON_PC="${PUBLIC_KEY_ON_PC:=${DEFAULT_PUBLIC_KEY_ON_PC}}"

# temporary file with the public key on the phone
#
PUBLIC_KEY_ON_THE_PHONE="/tmp/adbkey.pub"


# wait for the reboot at script to finish
#
WAIT_FOR_REBOOT="no"



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
  typeset THISMSG="$*"

  echo "${THISMSG}"
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


# ---------------------------------------------------------------------
# main function
#

LogMsg "${SCRIPT_NAME} version - ${SCRIPT_VERSION} - shell script to enable adb access via an init .rc file configured via Magisk"
LogMsg ""

if [ "$1"x = "-h"x ] ; then
  grep "^#h#" $0 | cut -c4-
  die 10

elif [ "$1"x = "-H"x -o "$1"x = "--help"x -o "$1"x = "help"x -o "$1"x = "-help"x ] ; then
#
# extract the usage help from the script source
#
  grep -E "^#H#|^#h#" $0 | cut -c4-
 
  echo " The scripts boot_phone_from_twrp.sh and enable_adb_using_magisk.sh are required by this script -- see the source code of the script"
  echo ""
  exit 1
fi

# ---------------------------------------------------------------------
#
# process the parameter 
#


SLOT_TO_PATCH=""

while [ $# -ge 1 ] ; do

  case $1 in
      
    reboot | --reboot | -reboot )
      REBOOT=yes
      ;;

    noreboot | --noreboot | -noreboot )
      REBOOT=no
      ;;

    nopubkey | --nopubkey |  -nopubkey )
      CONFIGURE_PUBLIC_KEY_FOR_ADB=${__FALSE}
      ;;

    pubkey |--pubkey | -pubkey )
      CONFIGURE_PUBLIC_KEY_FOR_ADB=${__TRUE}
      ;;

    wait | --wait )
      WAIT_FOR_REBOOT="yes"
      ;;

    nowait | --nowait )
      WAIT_FOR_REBOOT="no"
      ;;

    _a | _b )
      SLOT_TO_PATCH=$1
      ;;

    * )
      die 6 "ERROR: Unknown parameter found: \"$1\" "
      ;;

  esac
  shift

done  

if [ "${WAIT_FOR_REBOOT}"x = "no"x ]  ;then
  REBOOT_PHONE_PARAMETER="--nowait"
else
  REBOOT_PHONE_PARAMETER="--wait"
fi


ERRORS_FOUND=${__FALSE}

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

if [ -r "${SCRIPT_PATH}/${MAGISK_HELPER_SCRIPT}" ] ; then
  CUR_MAGISK_HELPER_SCRIPT="${SCRIPT_PATH}/${MAGISK_HELPER_SCRIPT}"
else
  CUR_MAGISK_HELPER_SCRIPT="$( which "${MAGISK_HELPER_SCRIPT}" )"
fi

if [ "${CUR_MAGISK_HELPER_SCRIPT}"x = ""x ] ; then
  LogError "Magisk Helper script \"${MAGISK_HELPER_SCRIPT}\" not found"
  ERRORS_FOUND=${__TRUE}
else
  LogMsg "Using the Magisk helper script \"${CUR_MAGISK_HELPER_SCRIPT}\" "
fi

if [ ${ERRORS_FOUND} = ${__TRUE} ] ; then
  die 100 "One or more errors found. Exiting"
fi

# ---------------------------------------------------------------------

LogMsg "Reading the helper script \"${TWRP_REBOOT_HELPER_SCRIPT}\" ..."

. ${CUR_TWRP_REBOOT_HELPER_SCRIPT}

# ---------------------------------------------------------------------


if [ ${CONFIGURE_PUBLIC_KEY_FOR_ADB} = ${__TRUE} ] ; then

#
# check which user started the adb daemon
#
  LogMsg "Checking which user startd the adb daemon ..."
  CUR_USER="$( id -un )"

  ADBD_DAEMON_PIDS="$( ps  --ppid 1 | grep adb | awk '{ print $1 }' )"
  
  for CUR_PID in ${ADBD_DAEMON_PIDS} ; do
    ADBD_DAEMON_PID=${CUR_PID}
    ps -f -p ${CUR_PID} | grep "tcp:[0-9]" >/dev/null && break
    ADBD_DAEMON_PID=""
  done
  
  if [ "${ADBD_DAEMON_PID}"x = ""x ] ; then
#
# ok, the adb daemon is not yet running
#
    LogMsg "OK, the adb daemon is not yet running and will be started by the user \"${CUR_USER}\" "
  else
    ADBD_DAEMON_USER="$( ps -f -p ${ADBD_DAEMON_PID}  | tail -1 | awk '{ print $1 }' )"
    if [ "${ADBD_DAEMON_USER}"x != "${CUR_USER}"x ] ; then
      LogWarning "The adb daemon (PID=${ADBD_DAEMON_PID}) was started by the user \"${ADBD_DAEMON_USER}\" but the user running this script is \"${CUR_USER}\" - most probably the pubkeys for these user are different and enabling access via adb using the script will NOT work"
    else
      LogMsg "OK, the adb daemon (PID=${ADBD_DAEMON_PID}) was started by the user \"${ADBD_DAEMON_USER}\" "  
    fi
  fi

fi

LogMsg "Retrieving the current status of the phone ..."

retrieve_phone_status

print_phone_status

#     0 - the phone was successfully booted from the TWRP image
#
#     1 - the phone is already booted from the TWRP image
#     2 - the phone is booted from TWRP installed in the boot or recovery partition
#     3 - the phone is booted into the Android OS
#     4 - the phone is booted into bootloader 
#     5 - the phone is booted into the fastbootd
#     6 - the phone is booted into the safe mode of the Android OS
#     7 - the phone is booted into the LineageOS recovery installed in the boot or recovery partition
#     8 - the phone is booted into sideload mode
#     9 - the phone is booted into a recovery without working adb shell
#
#    10 - error retrieving the status of the attached phone (or no phone connected)
#    11 - the phone is attached but without permissions to access via fastboot or adb

case ${PHONE_STATUS} in
  
   3 ) 
     LogMsg "The phone is currently booted into the Android OS with working adb access -- nothing to do"
     die 0     
     ;;
     
   6 ) 
     LogMsg "The phone is currently booted into the safe-mode of the Android OS with working adb access -- nothing to do"
     die 0
     ;;

   11 | 10 | 9 | 8 )
     LogMsg "The phone is attached but without access via fastboot or adb."
     die 10
     ;;

   4 | 5 )
    boot_phone_from_the_TWRP_image || die 110 "Can not boot the phone from the TWRP image"
    ;;
esac

# ---------------------------------------------------------------------

if [ ${CONFIGURE_PUBLIC_KEY_FOR_ADB} = ${__TRUE} ] ; then

  LogMsg "Copying the public ssl key for access via adb \"${PUBLIC_KEY_ON_PC}\" to \"${PUBLIC_KEY_ON_THE_PHONE}\" on the phone ..."
  
  if [ ! -r "${PUBLIC_KEY_ON_PC}" ] ; then
    LogMsg "WARNING: The local file with the public ssl key for the access via adb \"${PUBLIC_KEY_ON_PC}\" does not exist  -- will not configure the public ssl keys for the access via adb on the phone"
  else
    LogMsg "Copying the file \"${PUBLIC_KEY_ON_PC}\" to \"${PUBLIC_KEY_ON_THE_PHONE}\" the phone ..."
    CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} push "${PUBLIC_KEY_ON_PC}"  "${PUBLIC_KEY_ON_THE_PHONE}" 2>&1 )" 
    TEMPRC=$?
    LogMsg "${CUR_OUTPUT}" 
    [ ${TEMPRC} != 0 ] && LogMsg "WARNING: Error copying the file \"${PUBLIC_KEY_ON_PC}\" to \"${PUBLIC_KEY_ON_THE_PHONE}\" on the  phone -- will not configure the public ssl keys for the access via adb on the phone"
  fi
fi

LogMsg "Copying the Magisk helper script \"${CUR_MAGISK_HELPER_SCRIPT}\" to \"${MAGISK_HELPER_SCRIPT_ON_THE_PHONE}\" on the phone ..."

CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} push "${CUR_MAGISK_HELPER_SCRIPT}"  "${MAGISK_HELPER_SCRIPT_ON_THE_PHONE}" 2>&1 )" 
TEMPRC=$?
LogMsg "${CUR_OUTPUT}"
[ ${TEMPRC} != 0 ] && die 112 "Error Copying the Magisk helper script \"${CUR_MAGISK_HELPER_SCRIPT}\" to \"${MAGISK_HELPER_SCRIPT_ON_THE_PHONE}\" on the phone"
 
LogMsg "Executing the temporary script \"${MAGISK_HELPER_SCRIPT_ON_THE_PHONE} ${SLOT_TO_PATCH}\" on the phone ..."
sleep 2
${ADB} ${ADB_OPTIONS} shell sh "${MAGISK_HELPER_SCRIPT_ON_THE_PHONE}" "${SLOT_TO_PATCH}" || \
  die 113  "Error executing \"${MAGISK_HELPER_SCRIPT_ON_THE_PHONE}\" on the phone"

LogMsg "adb access will now be enabled by Magisk while doing the next reboot"

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


  reboot_phone "${REBOOT_PHONE_PARAMETER}"
fi


die 0


