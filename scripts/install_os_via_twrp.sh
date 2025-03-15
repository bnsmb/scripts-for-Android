#!/bin/bash
# 
# install_os_via_twrp.sh - shell script to install an OS image via the TWRP cli command twrp
#
# History
#  17.12.2022 v1.0.0.0  /bs #VERSION
#    initial release
#
#  26.12.2022 v1.0.1.0 /bs #VERSION
#   added a workaround for a bug in the twrp command: the twrp command to install a zip returns 0 even if an error occured
#
#  06.01.2023 v1.1.0.0 /bs #VERSION
#   the script now formats the partition /data if the parameter factory_reset or format_data is used
#
#  01.05.2023 v1.2.0.0 /bs #VERSION
#   the script now umounts /data if it's mounted and factory_reset is requested
#
#  27.04.2024 v2.0.0.0 /bs #VERSION
#   added code to install an image via TWRP sideload function (-> the script can now also install LineageOS or the original ASUS Android images)
#   the script now checks the contents of the ZIP file
#
#  30.04.2024 v2.1.0.0 /bs #VERSION
#   added code to finish the sideload mode (adb reboot)
#
#  04.05.2024 v2.1.0.1 /bs #VERSION
#   fixed a syntax error in line 590  (if [ "${CUR_ADB_USER}"x != "root"x ] ; then)
#   minor correction to the code to select the installation method
#
#  05.05.2024 v2.1.1.0 /bs #VERSION
#   added the parameter restart_as_root to restart the adb as user root if necessary
#
#  22.06.2024 v2.1.2.0 /bs #VERSION
#   the script now ends with an RC not zero if sideloading the image needs less then 2 minutes (variable SIDELOAD_MIN_TIME)
#
#  10.08.2024 v2.1.3.0 /bs #VERSION
#   added the environment variables MINIMUM_INSTALLATION and INSTALLATION_WAIT_TIME; 
#     the script now starts a second attempt to install the operating system image if the first installation took less than MINIMUM_INSTALLATION seconds. 
#     The script waits INSTALLATION_WAIT_TIME seconds until it starts the second attempt to install the operating system.
#     This seems to be necessary to update the OS from an OS image with OmniROM 14 with patchset 08 / 2024.
#
#  10.02.2025 v2.1.4.0 /bs #VERSION
#   the script now deletes the OS image file is there is less then 1 GB free space (variable MINIMUM_FREESPACE) in the filesystem with the image file
#   use the parameter "keep_image_file" to disable the removal of the image file
#
#  26.02.2025 v2.1.5.0 /bs #VERSION
#   the script now formats the metadata partition before it formats the /data partition
#
# This script can be used to install an OS image via the command twrp from the TWRP recovery.
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
#H# Usage
#H# 
#h#    install_os_via_twrp.sh [-h|help|-H] [--reboot|--noreboot] [force] [wipe|wipeall] [wipe_cache] [wipe_data] [wipe_dalvik] [wipe_all] [format_data] 
#h#                          [format_metadata] [factory_reset] [sideload] [nosideload|install] [auto] [restart_as_root] [keep_image_file] [os_image_file] 
#h#
#H# All parameter are optional, except the parameter for the OS image to install "os_image_file".
#H# The parameter can be used in any order.
#H#
#H# Use the parameter "help" or "-H" to print the detailed usage help; use the parameter "-h" to print only the short usage help
#H#
#H# If the parameter "--reboot" is used the script will reboot the phone after successfully installing the OS image; to disable the automatic reboot use the parameter "--noreboot".
#H# Default is to ask the user for confirmation to reboot the phone.
#H#
#H# Use the parameter "wipe" or "wipeall" to wipe /data, /cache, and Dalvik before installing the OS image.
#H# Use one or more of the parameter "wipe_cache", "wipe_data", or "wipe_dalvik" to only wipe some of the partitions used.
#H#
#H# Use the parameter "format_metadata" to format the meta data partition; this is NOT included in "wipe_all"
#H# Use the parameter "format_data" to format the data partition; this is NOT included in "wipe_all"
#H#
#H# Use the parameter "factory_reset" to do a factory reset before installing the OS image; a factory reset is done by formatting the data and the metadata partitions.
#H#
#H# Use the parameter "force" to ignore errors while wiping or formatting the data; without this parameter the script will abort if one of the wipe or format commands fails
#H#
#H# Use the parameter "sideload" to install the image via TWRP sideload feature (this is necessary to install the Original ASUS ROM or the LineageOS)
#H#
#H# Use the parameter "nosideload" or "install" to force the usage of "twrp install" for installing the image
#H#
#H# Use the parameter "auto" to automatically select the installation method (install or sideload) depending on the name of the OS image file 
#H#   Using this parameter the script uses "install" for OmniROM images, "sideload" for LineageOS and ASUS Android images, and "sideload" for all unknown OS images
#H#
#H# Without the parameter "auto" and "sideload" the script uses the TRWP install functionality to install the OS
#H#
#H# Use the parameter "restart_as_root" to restart the adb daemon via sudo if it's not started by the user root and an installation via sideload is requested
#H#
#H# To change some of the values used by the script these environment variables can be set before starting the script:
#H#
#H#   Set the environment variable REBOOT to "yes" before starting the script to automatically reboot the phone after enabling the root access 
#H#   Set the environment variable REBOOT to "no" before starting the script to disable the automatic reboot after enabling the root access 
#H#
#H#   Set the environment variable UPLOAD_DIR_ON_THE_PHONE to set the upload directory for the OS image file on the phone (default dir is /tmp; /tmp is mounted on a ramdiks)
#H#
#H#   Set the environment variable MINIMUM_INSTALLATION time to the minimum number of seconds that the installation must run (default value is 60 seconds)
#H#
#H# See also the source code of the script
#H#
#H#   boot_phone_from_twrp.sh 
#H#
#H# for environment variables supported by this script
#H#
#H# Prerequisites
#H#
#H# - the phone must be connected via USB
#H# - there must be a working connection to the phone using fastboot or adb
#H# - a working TWRP image for the phone must exist
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

# options for the adb shell command
#
SHELL_OPTIONS=" -tt "

# directory for the OS image file on the phone
#
UPLOAD_DIR_ON_THE_PHONE="${UPLOAD_DIR_ON_THE_PHONE:=/tmp}"

# minimum time the installation needs
#
MINIMUM_INSTALLATION=${MINIMUM_INSTALLATION:=60}

# number of seconds to wait until re-installing the OS image
#
INSTALLATION_WAIT_TIME=${INSTALLATION_WAIT_TIME:=10}


# defaults for the parameter
#

# FORCE=${__FALSE}: abort the script if one of the wipe commands fails 
#
FORCE=${__FALSE}

# install the image using sideload
#
USE_SIDELOAD=${__FALSE}


# the script ends with an error if sideloading an image is faster than 120 seconds
#
SIDELOAD_MIN_TIME=120

WIPE_DATA=${__FALSE}
WIPE_CACHE=${__FALSE}
WIPE_DALVIK=${__FALSE}

FORMAT_DATA=${__FALSE}
FORMAT_METADATA=${__FALSE}

OS_IMAGE_TO_INSTALL=""

# select the installation method used (install or sideload) depeneding on the name of the OS image file
#
AUTO_SELECT_INSTALLATION_METHOD=${__FALSE}

RESTART_ADB_DAEMON_AS_ROOT=${__FALSE}

# delete the image file after the successfull installation
#
KEEP_IMAGE_FILE=${__FALSE}

# required free space in KB in the filesystem with the image file
#
MINIMUM_FREESPACE=1048576

INSTALLATION_SUCCESSFULL=${__FALSE}


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

LogMsg "${SCRIPT_NAME} version - ${SCRIPT_VERSION} - install an OS image via the TWRP command twrp"
LogMsg ""

if [ "$1"x = "-h"x ] ; then
  grep "^#h#" $0 | cut -c4-
  die 10

elif [ "$1"x = "-H"x -o "$1"x = "--help"x -o "$1"x = "help"x -o "$1"x = "-help"x ] ; then
#
# extract the usage help from the script source
#
  grep -E "^#H#|^#h#" $0 | cut -c4-
 
  echo " The script boot_phone_from_twrp.sh is required by this script -- see the source code of the script"
  echo ""
  exit 1
fi

#
# process the parameter 
#
#     install_os_via_twrp.sh [-h|help|-H] [--reboot|--noreboot]  [keep_image_file|--keep_image_file] [wipe|wipeall] [wipe_cache] [wipe_data] [wipe_dalvik] [sideload] [os_image_file]


while [ $# -ge 1 ] ; do

  case $1 in
     
    auto )
      AUTO_SELECT_INSTALLATION_METHOD=${__TRUE}
      ;;

    reboot | --reboot | -reboot )
      REBOOT=yes
      ;;

    keep_image_file | --keep_image_file )
      KEEP_IMAGE_FILE=${__TRUE}
      ;;

    noreboot | --noreboot | -noreboot )
      REBOOT=no
      ;;

    wipe_all | wipe | --wipe | --wipe_all )
      WIPE_DATA=${__TRUE}
      WIPE_CACHE=${__TRUE}
      WIPE_DALVIK=${__TRUE}
      ;;
      
    wipe_data | --wipe_data )
      WIPE_DATA=${__TRUE}      
      ;;

    wipe_cache | --wipe_cache )
      WIPE_CACHE=${__TRUE}      
      ;;

    wipe_dalvik | --wipe_dalvik )
      WIPE_DALVIK=${__TRUE}      
      ;;
    

    format_metadata | --format_metadata )
      FORMAT_METADATA=${__TRUE}
      ;;

    format_data | --format_data )
      FORMAT_DATA=${__TRUE}
      ;;

    factory_reset | --factory_reset )
      FORMAT_METADATA=${__TRUE}
      FORMAT_DATA=${__TRUE}
      ;;

    force | --force )
      FORCE=${__TRUE}
      ;;
   
    sideload | --sideload )
      USE_SIDELOAD=${__TRUE}
      ;;

    nosideload | install )
      USE_SIDELOAD=${__TFALSE}
      ;;

    restart_as_root )
      RESTART_ADB_DAEMON_AS_ROOT=${__TRUE}
      ;;

    * )
      if [ "${OS_IMAGE_TO_INSTALL}"x = ""x ] ; then
        OS_IMAGE_TO_INSTALL="$1"
      else
        die 6 "ERROR: Unknown parameter found: \"$1\" "
      fi
      ;;

  esac
  shift

done  

ERRORS_FOUND=${__FALSE}

if [ "${OS_IMAGE_TO_INSTALL}"x = ""x ] ; then
  die 0 "No image file to install found in the parameter. Use \"-h\" or \"--help\" to view the script usage"
  
elif [ ! -r "${OS_IMAGE_TO_INSTALL}" ] ; then
  LogError "The file \"${OS_IMAGE_TO_INSTALL}\" does not exist"
  ERRORS_FOUND=${__TRUE}
else
  LogMsg "Checking the contents of the file  \"${OS_IMAGE_TO_INSTALL}\" ..."
  ZIP_FILE_CONTENTS="$( unzip -l "${OS_IMAGE_TO_INSTALL}" 2>&1 )"
  if [ $? -ne 0 ] ; then
    LogMsg "-" "${ZIP_FILE_CONTENTS}"
    LogError "Can not read the contents of the zip file \"${OS_IMAGE_TO_INSTALL}\" "
    ERRORS_FOUND=${__TRUE}
  else
    echo "${ZIP_FILE_CONTENTS}" | grep payload.bin >/dev/null
    if [ $? -ne 0 ] ; then
      LogMsg "-" "${ZIP_FILE_CONTENTS}"
      LogError "The file \"${OS_IMAGE_TO_INSTALL}\" is not an OS image file for an Android phone "
      ERRORS_FOUND=${__TRUE}
    fi
  fi
fi


if [ ${AUTO_SELECT_INSTALLATION_METHOD} = ${__TRUE} ] ; then


  LogMsg "Selecting the installation method depending of the name of the image file \"${OS_IMAGE_TO_INSTALL}\" ..."
      
# convert the image name to lowerer case
#  
  OS_IMAGE_TO_INSTALL_IN_LOWERCASE="$( echo "${OS_IMAGE_TO_INSTALL}" | tr "[A-Z]" "[a-z]" )"

# remove the path 
#
  OS_IMAGE_TO_INSTALL_FILE_NAME="${OS_IMAGE_TO_INSTALL_IN_LOWERCASE##*/}"
  
  case "${OS_IMAGE_TO_INSTALL_FILE_NAME}" in

    *lineage* )
       LogMsg "This seems to be a LineageOS installation image -- using sideload for the installation"
       USE_SIDELOAD=${__TRUE}
       ;;

    *statix* )
       LogMsg "This seems to be a Statix installation image -- using sideload for the installation"
       USE_SIDELOAD=${__TRUE}
       ;;

    *omni* )
       LogMsg "This seems to be a OmniROM installation image -- using install for the installation"
       USE_SIDELOAD=${__FALSE}
       ;;
    
    ul-asus_* )
       LogMsg "This seems to be an original ASUS Android installation image -- using sideload for the installation"
       USE_SIDELOAD=${__TRUE}
       ;;
            
     * )
       LogMsg "This seems is an unknown ASUS Android installation image -- using sideload for the installation"
       USE_SIDELOAD=${__TRUE}
       ;;

  esac
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

  
if [ ${ERRORS_FOUND} = ${__TRUE} ] ; then
  die 100 "One or more errors found. Exiting"
fi

# define the filename for the OS image file on the phone
#
IMAGE_FILE_ON_THE_PHONE="${UPLOAD_DIR_ON_THE_PHONE}/${OS_IMAGE_TO_INSTALL##*/}"


LogMsg "The OS image to install is: \"${OS_IMAGE_TO_INSTALL}\" "

LogMsg "Reading the helper script \"${TWRP_REBOOT_HELPER_SCRIPT}\" ..."

. ${CUR_TWRP_REBOOT_HELPER_SCRIPT}

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
#

boot_phone_from_the_TWRP_image || die 10 "Can not boot the phone from the TWRP image"

wait_for_the_adb_daemon

ERRORS_FOUND=${__FALSE}

if [ ${WIPE_CACHE}  = ${__TRUE} ] ; then
  LogMsg ""
  LogMsg "Wiping the cache ..."
  CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell ${SHELL_OPTIONS} twrp wipe /cache 2>&1 )"
  TEMPRC=$?
  LogMsg "${CUR_OUTPUT}"
  if [ ${TEMPRC} != 0 ] ; then
    LogError "Error wiping the cache"
    ERRORS_FOUND=${__TRUE}
  fi
fi

if [ ${WIPE_DALVIK} = ${__TRUE} ] ; then
  wipe_dalvik
  TEMPRC=$?
  if [ ${TEMPRC} != 0 ] ; then
    LogError "Error wiping the dalvik"
    ERRORS_FOUND=${__TRUE}
  fi
fi


  if [ ${FORMAT_METADATA} = ${__TRUE} ] ; then
    format_metadata
    TEMPRC=$?
    LogMsg "${CUR_OUTPUT}"
    if [ ${TEMPRC} != 0 ] ; then
      LogError "Error formating the metadata partition"
      ERRORS_FOUND=${__TRUE}
    fi
  fi

  if [ ${FORMAT_DATA} = ${__TRUE} ] ; then
    format_data
    TEMPRC=$?
    if [ ${TEMPRC} != 0 ] ; then
      LogError "Error formating the /data partition"
      ERRORS_FOUND=${__TRUE}
    fi  
  else
    if [ ${WIPE_DATA} = ${__TRUE} ] ; then
      wipe_data
      TEMPRC=$?
      if [ ${TEMPRC} != 0 ] ; then
        LogError "Error wiping the /data partition"
        ERRORS_FOUND=${__TRUE}
      fi
    fi
  fi
    
if [ ${ERRORS_FOUND} = ${__TRUE} ] ; then
  if [ ${FORCE} = ${__TRUE} ] ; then
    LogMsg "Error wiping or formating the data but the parameter force was used so we will continue"
  else
    die 10 "Error wiping or formating the data ; will exit now (use the parameter \"force\" to ignore this error) "
  fi
fi

wait_for_phone_with_a_working_adb_connection 10
if [ $? -ne ${__TRUE} ] ; then
  kill_adb_daemon
  
  start_adb_daemon
fi

# get the active slot
#
CUR_SLOT="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.boot.slot_suffix )"
if [ "${CUR_SLOT}"x  = "_b"x ] ; then
   NEXT_SLOT=0
   NEXT_SLOT_NAME="_a"
else
  NEXT_SLOT=1
  NEXT_SLOT_NAME="_b"
fi


if [ ${USE_SIDELOAD} = ${__FALSE} ] ; then
  LogMsg "Installing the OS image file \"${OS_IMAGE_TO_INSTALL}\" via install option from within TWRP on the phone ..."

  START_DATE=$( date +%s )

  LogMsg ""
  LogMsg "Coyping the OS image file \"${OS_IMAGE_TO_INSTALL}\" to \"${IMAGE_FILE_ON_THE_PHONE}\" on the phone ..."
  ( set -x ; ${ADB} ${ADB_OPTIONS}  push "${OS_IMAGE_TO_INSTALL}" "${IMAGE_FILE_ON_THE_PHONE}"  )
  TEMPRC=$?
  if [ ${TEMPRC} != 0 ] ; then
    LogMsg ""
    CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell ls -l "${IMAGE_FILE_ON_THE_PHONE}" 2>&1 )"
    LogMsg "${CUR_OUTPUT}"
    LogMsg ""
    LogMsg "Copying the image failed -- we will do another try in 5 seconds ..."
    sleep 5

    LogMsg "Coyping the OS image file \"${OS_IMAGE_TO_INSTALL}\" to \"${IMAGE_FILE_ON_THE_PHONE}\" on the phone (2nd try) ..."  
    ( set -x ; ${ADB} ${ADB_OPTIONS}  push "${OS_IMAGE_TO_INSTALL}" "${IMAGE_FILE_ON_THE_PHONE}"  )
    TEMPRC=$?
    if [ ${TEMPRC} != 0 ] ; then
      die 20 "Error copying the file \"${OS_IMAGE_TO_INSTALL}\" to \"${IMAGE_FILE_ON_THE_PHONE}\" on the phone"  
    fi
  fi
  
  LogMsg ""
  LogMsg "Installing the OS image \"${IMAGE_FILE_ON_THE_PHONE}\" via the \"install\" functionality from TWRP into the slot \"${NEXT_SLOT_NAME}\"  ..."
  ( set -x ; ${ADB} ${ADB_OPTIONS}  shell ${SHELL_OPTIONS} twrp install  "${IMAGE_FILE_ON_THE_PHONE}" 2>&1 )
  TEMPRC=$?
  
  END_DATE=$( date +%s )

  RUNTIME=$(( END_DATE - START_DATE ))
  
  LogMsg "Installing the image via \"twrp install\" took ${RUNTIME} seconds(s)"

  if [ ${TEMPRC} != 0 ] ; then
    die 25 "Error installing the OS image \"${IMAGE_FILE_ON_THE_PHONE}\" into the slot \"${NEXT_SLOT_NAME}\" "
  elif [[ ${CUR_OUTPUT} == *Error\ installing\ zip\ file* ]] ; then
    die 26 "Error installing the OS image \"${IMAGE_FILE_ON_THE_PHONE}\" into the slot \"${NEXT_SLOT_NAME}\" "
  else
  
    if [ ${RUNTIME} -lt ${MINIMUM_INSTALLATION} ] ; then
      LogMsg "*** The installation uses less then ${MINIMUM_INSTALLATION} seconds -- most probably something went wrong"
      LogMsg "Waiting for ${INSTALLATION_WAIT_TIME} seconds before trying to install the OS again ..."
      sleep  ${INSTALLATION_WAIT_TIME}
 
      LogMsg "Re-installing the OS image \"${IMAGE_FILE_ON_THE_PHONE}\" via the \"install\" functionality from TWRP into the slot \"${NEXT_SLOT_NAME}\"  ..."
     
      START_DATE=$( date +%s )
      ( set -x ; ${ADB} ${ADB_OPTIONS}  shell ${SHELL_OPTIONS} twrp install  "${IMAGE_FILE_ON_THE_PHONE}" 2>&1 )
      TEMPRC=$?

      END_DATE=$( date +%s )

      RUNTIME=$(( END_DATE - START_DATE ))
      LogMsg "Re-installing the image via \"twrp install\" took ${RUNTIME} seconds(s)"
      if [ ${RUNTIME} -lt ${MINIMUM_INSTALLATION} ] ; then
        LogWarning "The installation was probably not successfull"
      else
        INSTALLATION_SUCCESSFULL=${__TRUE}
      
        LogMsg "OS image file \"${IMAGE_FILE_ON_THE_PHONE}\" successfully installed."
      fi
    else
      INSTALLATION_SUCCESSFULL=${__TRUE}
      
      LogMsg "OS image file \"${IMAGE_FILE_ON_THE_PHONE}\" successfully installed."
    fi
  fi  

  if [ ${INSTALLATION_SUCCESSFULL} = ${__TRUE} ] ; then
    IMAGE_DIR="${IMAGE_FILE_ON_THE_PHONE%/*}"
    FREE_SPACE="$(  ${ADB} ${ADB_OPTIONS} shell df -k "${IMAGE_DIR}" | tail -1 | awk '{ print $4 }' )"
    if isNumber  "${FREE_SPACE}" ; then
      if [ ${FREE_SPACE} -lt ${MINIMUM_FREESPACE} ] ; then
        LogMsg "The free space in the directory \"${IMAGE_DIR}\", ${FREE_SPACE} kb, is less then ${MINIMUM_FREESPACE} kb:"
        ${ADB} ${ADB_OPTIONS} shell df -h "${IMAGE_DIR}"

        LogMsg "Now deleting the image file \"${IMAGE_FILE_ON_THE_PHONE}\" ... "
         ${ADB} ${ADB_OPTIONS} shell rm  -f "${IMAGE_FILE_ON_THE_PHONE}"
        if [ $? -ne 0 ] ; then
          LogError "Error deleting the file \"${IMAGE_FILE_ON_THE_PHONE}\" "
        elif [ ! -r "${IMAGE_FILE_ON_THE_PHONE}" ] ; then
          LogMsg "Image file \"${IMAGE_FILE_ON_THE_PHONE}\" successfully deleted"
        else
          LogError "Error deleting the file \"${IMAGE_FILE_ON_THE_PHONE}\", the contents of the directory \"${IMAGE_DIR}\" are:"
          ${ADB} ${ADB_OPTIONS} shell ls -l "${IMAGE_DIR}"
        fi
        FREE_SPACE="$(  ${ADB} ${ADB_OPTIONS} shell df -k "${IMAGE_DIR}" | tail -1 | awk '{ print $4}' )"
        LogMsg "The free space in the directory \"${IMAGE_DIR}\" is now ${FREE_SPACE} kb"
        ${ADB} ${ADB_OPTIONS} shell df -h "${IMAGE_DIR}"
      else
        LogMsg "The free space in the directory \"${IMAGE_DIR}\", ${FREE_SPACE} kb, is more then ${MINIMUM_FREESPACE} kb -- will NOT delete the image file \"${IMAGE_FILE_ON_THE_PHONE}\"  "
      fi
    else
      LogError "Error retrieving the free space in the directory \"${IMAGE_DIR}\"  "
    fi
  fi
else
  LogMsg "Installing the OS image file \"${OS_IMAGE_TO_INSTALL}\" via the \"sideload\" functionality from TWRP into the slot \"${NEXT_SLOT_NAME}\" ..."

# rebooting the phone again from the TWRP image did not fix the problem with no root access for a adb started by a non-root user
#
#  LogMsg "Booting the phone from the TWRP image again ..."
#  FORCE_REBOOT_INTO_TWRP_IMAGE=${__TRUE}
#  boot_phone_from_the_TWRP_image
#  unset FORCE_REBOOT_INTO_TWRP_IMAGE

  LogMsg "Starting sideload on the phone .."
  LogMsg ""
  ( set -x ; ${ADB} ${ADB_OPTIONS} shell twrp sideload  )
  TEMPRC=$?
  LogMsg "The RC is ${TEMPRC}"

  if [ ${TEMPRC} = 0 ] ; then
    INSTALLATION_SUCCESSFULL=${__TRUE}
  fi
  
  wait_some_seconds 5
   
  retrieve_phone_status

  print_phone_status  

#
# adb sideload only works if executed with the adb daemon is running as user root
#  
  CUR_OUTPUT="$( ps -ef | grep -v grep | grep " adb " )"
  CUR_ADB_USER="$( echo "${CUR_OUTPUT}" | awk '{ print $1 }' )"
  if [ "${CUR_ADB_USER}"x != "root"x ] ; then
    if [ ${RESTART_ADB_DAEMON_AS_ROOT} = ${__TRUE} ] ; then
      LogMsg "The adb daemon is running as user \"${CUR_ADB_USER}\" - now restarting the adb as user root ..."
      restart_adb_daemon root

      retrieve_phone_status

      print_phone_status  

    else
      LogMsg "-" "*****************************************************************************************"
      LogMsg "-"
      LogWarning "The adb daemon is running as user \"${CUR_ADB_USER}\"  - sideloading will most probably NOT work "
      LogMsg "-" "(the adb daemon should run as user \"root\")"
      LogMsg "-"
      LogMsg "-" "${CUR_OUTPUT}"
      LogMsg "-"
      LogMsg "-" "Use the script parameter \"restart_as_root\" to force the script to restart the adb "
      LogMsg "-" "as user \"root\" using the command \"sudo\" "
      LogMsg "-"
      LogMsg "-" "*****************************************************************************************"
    fi
  fi    

  if [ ${PHONE_STATUS} != 8 ] ; then
    die 27 "The phone status is now ${PHONE_STATUS} but it should be 8 for sideload mode"
  fi

    LogMsg "Now sideloading the image file \"${OS_IMAGE_TO_INSTALL}\" ..."
    START_DATE=$( date +%s )

    ( set -x ;  ${ADB} ${ADB_OPTIONS} sideload "${OS_IMAGE_TO_INSTALL}"  )
    TEMPRC=$?
    
    END_DATE=$( date +%s )
    LogMsg "The RC is ${TEMPRC}"  
    RUNTIME=$(( END_DATE - START_DATE ))
    LogMsg "Installing the image via \"twrp sideload\" took ${RUNTIME} seconds(s)"
    if [ ${RUNTIME} -lt ${SIDELOAD_MIN_TIME} ]  ; then
      LogError "The installation of the image via sideload was very fast and may have failed (less then ${SIDELOAD_MIN_TIME} seconds) - please check the phone"
      THISRC=${__FALSE}
    fi
#
# end the sideload mode
#
    LogMsg "Finishing the sideload mode now ..."

    ( set -x  ;  ${ADB} ${ADB_OPTIONS} reboot )

    wait_for_phone_with_a_working_adb_connection 60
    
    retrieve_phone_status

    print_phone_status
 
fi


if [ ${THISRC} = ${__TRUE} ] ; then

  LogMsg "Now changing the next active slot to ${NEXT_SLOT_NAME} ..."
  ( set -x ; ${ADB} ${ADB_OPTIONS}  shell bootctl set-active-boot-slot ${NEXT_SLOT}  )
  TEMPRC=$?
  LogMsg "The RC is ${TEMPRC}"  

  if [ ${TEMPRC} != 0 ] ; then
    die 30 "Error changing the next active slot to ${NEXT_SLOT_NAME}"
  else
    LogMsg "... successfully changed the active slot for the next reboot"
  fi
fi

if [ ${THISRC} = ${__TRUE} ] ; then
 
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
  
    reboot_phone "--nowait"
  fi
fi


die 0


