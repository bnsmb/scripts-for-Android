#!/bin/bash
#
# Linux shell script to install TWRP in the boot partition of a phone running Android without user input
#
#H# Usage
#H#
#h#    install_twrp_via_twrp.sh [-h|help|-H] [boot_slot] [wait=n] [dd|fastboot] [--reboot|--noreboot]  [twrp_image]
#h#
#H# All parameter are optional
#H#
#H# Use the parameter "help" or "-H" to print the detailed usage help; use the parameter "-h" to print only the short usage help
#H#
#H# The parameter "boot_slot" can be a, b, active, inactive, next, current; default is the current boot slot of the phone
#H#
#H# Use the parameter "dd" to request repatching via dd in an adb session ; use the parameter "fastboot" to request repatching via "fastboot"
#H# Default is to use "dd" to flash the patched boot image
#H#
#H# The value for the parameter "wait" is the number of seconds to wait before starting the script "install_twrp_from_within_twrp.sh" on the phone
#H# This seems to be necessary to avoid errors while repacking the boot image. The default wait time is 10 seconds.
#H#
#H# The parameter "twrp_image" can be used to define another TWRP image to use. The parameter is optional - the
#H# default for "twrp_image" is hardcoded in the script (variable TWRP_IMAGE)
#H#
#H# The default TWRP image of the script is the TWRP for the ASUS Zenfone 8.
#H#
#H# The phone to patch must be attached via USB.
#H# The phone can be either in fastboot mode, in normal mode with enabled adb support, or already booted from the TWRP image
#H#
#H# The script uses the script "install_twrp_from_within_twrp.sh" to install TWRP. The script install_twrp_from_within_twrp.sh must
#H# be in the same directory as this script. The script will be copied to the phone and then executed on the phone.
#H# Set the variable TWRP_INSTALL_SCRIPT to the name of the script to use before starting this script if another script should be used .
#H#
#H# To change some of the values used by the script you can set environment variables before starting the script:
#H#
#H#   Set the environment variable REBOOT to "yes" before starting the script to automatically reboot the phone after patching the new image
#H#   Set the environment variable REBOOT to "no" before starting the script to disable the automatic reboot after patching the new image.
#H#
#H#   Set the environment variable SERIAL_NUMBER to the serial number of the phone to patch if there is more then one phone connected via USB
#H#
#H#   Set the environment variable ADB_OPTIONS to the options to be used with the adb command
#H#
#H#   Set the environment variable FASTBOOT_OPTIONS to the options to be used with the fastboot command
#H#
#H#   Set the environment variable TMP_DIR_ON_THE_PHONE to the temporary directory to use on the phone
#H#
#H#
#
# History
#   24.10.2022 v1.0.0.0 /bs #VERSION
#     initial release
#
#   05.11.2022 v1.1.0.0 /bs #VERSION
#     fixed some minor errors
#
#   05.11.2022 v1.1.0.1 /bs #VERSION
#     added an additional check for empty serial numbers
#     did some minor changes
#
#   26.11.2022 v1.1.0.2 /bs #VERSION
#     defining a TWRP image to use via parameter did not work -- fixed
#
#   29.11.2022 v1.2.0.0 /bs #VERSION
#     use the directory /tmp for temporary files if /data/local/tmp does not exist
#
#   25.01.2023 v1.3.0.0 /bs #VERSION
#      added the parametter --reboot and --noreboot
#
#   28.01.2023 v1.3.1.0 /bs #VERSION
#      copying files to the phone via adb failed if more then one phone was connected because of missing adb options -- fixed
#
#   24.11.2024 v1.3.2.0 /bs #VERSION
#      added initial support for the OrangeFox recovery
#
# Author
#   Bernd.Schemmer (at) gmx.de
#   Homepage: http://bnsmb.de/
#
#
# Prerequisites
#   a computer running Linux with working adb and fastboot binaries available via PATH variable
#   a phone with unlocked boot loader
#   a working TWRP recovery image that should be installed in the boot partition of the phone
#
# Test Environment
#   Tested on an ASUS Zenfone 8 and with
#     - OmniROM 12 (Android 12) and TWRP 3.7.0.12
#     - OmniROM 12 (Android 12) and TWRP 3.6.1.12
#
#
# Details
#
#   The patched boot images will be created in the directory "/data/local/tmp" on the phone (variable TMP_DIR_ON_THE_PHONE
#   If that directory does not exist the script will use the directory /tmp for the patched boot images. Be aware that /tmp
#   is on a ramdiks and the contents will be lost after the next reboot.
#
#   The code used to install TWRP in the script is based on the instructions used in the TWRP source code :
#     https://github.com/TeamWin/android_bootable_recovery/blob/android-12.1/twrpRepacker.cpp
#
#   You can execute the script as often as you like.
#
#   The script will boot the phone up to 4 times.
#
# Trouble Shooting
#
#   - Patching the boot partition via "dd" fails sometimes for unknown reason so you should only use it if you know how to fix a damaged boot partition!
#
#   - Downloading the patched boot image via "adb pull" ((neccessary for patching the boot partition using fastboot) sometimes fails for unknown reason:
#
#       So if you get an error message like this:
#
#       [ 77%] /sdcard/Download/patched_boot_a.391985.img
#       ERROR: Error downloading the file "/sdcard/Download/patched_boot_a.391985.img" from the phone!
#
#       just restart the script again (or download the file with the patched boot image and flash the boot partition manually)
#
#   - If the adb connection dies and there are error messages like this
#
#       adb: insufficient permissions for device
#
#     restart the adb server using
#
#       adb kill-server
#
#     if that does not work disconnect and reconnect the USB cable
#
#SCRIPT_VERSION="1.2.0.0"
SCRIPT_VERSION="$( grep "^#" $0 | grep "#VERSION" | grep "v[0-9]" | tail -1 | awk '{ print $3}' )"

SCRIPT_NAME="${0##*/}"

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

# ---------------------------------------------------------------------
# init some global variables
#

# default TWRP image to use
#
#TWRP_IMAGE="/data/backup/ASUS_ZENFONE8/twrp/twrp-3.6.1_12-1-I006D.img"
DEFAULT_TWRP_IMAGE="/data/backup/ASUS_ZENFONE8/twrp/current_twrp.img"
TWRP_IMAGE=""

#
# script to install TWRP (will be copied to the phone and executed on the phone
#
DEFAULT_TWRP_INSTALL_SCRIPT_NAME="install_twrp_from_within_twrp.sh"
DEFAULT_TWRP_INSTALL_SCRIPT="${0%/*}/${DEFAULT_TWRP_INSTALL_SCRIPT_NAME}"

# default wait time in seconds before executing the script on the phone
#
DEFAULT_WAIT_TIME_IN_SECONDS=10

# the directory used for creating the image files on the phone
#
TMP_DIR_ON_THE_PHONE="${TMP_DIR_ON_THE_PHONE:=/data/local/tmp}"

# general options for the adb command (-d : only use devices connected via USB)
#
ADB_OPTIONS="${ADB_OPTIONS:=-d}"

# general options for the fastboot command
#
FASTBOOT_OPTIONS="${FASTBOOT_OPTIONS:=}"

# The default for the boot slot that should be patched
#
BOOT_SLOT_TO_USE="active"

#
# if this variable is ${__TRUE} the script uses fastboot to flash the boot partition with the patched boot image
# if this variable is ${__FALSE} the script uses dd in an adb session to write the patched boot image to the boot partition
#
USE_FASTBOOT_TO_FLASH_THE_BOOT_PARTITION=${__FALSE}

# ---------------------------------------------------------------------
# functions
#

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
      echo "ERROR: ${THISMSG} (RC=${THISRC})" >&2
    else
      echo "${THISMSG}"
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
  typeset __FUNCTION="isNumber"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
	
  typeset THISRC=${__FALSE}

  [[ $1 == +([0-9]) ]] && THISRC=${__TRUE} || THISRC=${__FALSE}

  return ${THISRC}
}


# ----------------------------------------------------------------------
# wait_for_phone_to_be_in_fastboot_mode
#
# function: wait up to n seconds for a phone with in fastboot mode
#
# usage: wait_for_phone_to_be_in_fastboot_mode [timeout_value_in_seconds]
#
# returns: ${__TRUE}  - found a phone in fastboot mode
#          ${__FALSE} - no phone in fastboot mode found
#
function wait_for_phone_to_be_in_fastboot_mode {
#
# the values below are seconds
#
  typeset MAX_WAIT_TIME=${FASTBOOT_WAIT_TIME:=60}

  typeset THISRC=${__TRUE}

  if [ "$1"x != ""x ] ;then
    isNumber $1 && MAX_WAIT_TIME=$1
  fi

  echo "Waiting up to ${MAX_WAIT_TIME} seconds for the boot into the fastboot mode ..."

#  echo "[$( date "+%Y.%m.%d %H:%M:%S")] "

  CUR_FASTBOOT_VARIABLES="$( ${SUDO_PREFIX} timeout ${MAX_WAIT_TIME} fastboot ${FASTBOOT_OPTIONS} getvar all 2>&1 )"
  [ $? -eq 0 ] && THISRC=${__TRUE} || THISRC=${__FALSE}

#  echo "[$( date "+%Y.%m.%d %H:%M:%S")] "

  return ${THISRC}
}


# ----------------------------------------------------------------------
# wait_for_phone_with_a_working_adb_connection
#
# function: wait up to n seconds for a phone with a working adb connection
#
# usage: wait_for_phone_with_a_working_adb_connection [timeout_value_in_seconds]
#
# returns: ${__TRUE}  - found a phone with a working adb connection
#          ${__FALSE} - no phone with working adb connection found
#
function wait_for_phone_with_a_working_adb_connection {
#
# the values below are seconds
#	
  typeset MAX_WAIT_TIME=60
  typeset SECONDS=0
  typeset INTERVALL=5

  typeset THISRC=${__FALSE}

  if [ "$1"x != ""x ] ;then
    isNumber $1 && MAX_WAIT_TIME=$1
  fi

#  echo "[$( date "+%Y.%m.%d %H:%M:%S")] "

  printf "Waiting up to ${MAX_WAIT_TIME} seconds for the boot of the phone "

  while [ ${SECONDS} -lt ${MAX_WAIT_TIME} ] ; do
    CUR_PHONE_PROPERTIES="$( adb ${ADB_OPTIONS} shell getprop  all 2>&1 )"
    if [ $? -eq 0 ] ; then
      THISRC=${__TRUE}
      break
    fi
    printf "."
    sleep ${INTERVALL}
    (( SECONDS = SECONDS + INTERVALL ))
  done
  printf "\n"

#  echo "[$( date "+%Y.%m.%d %H:%M:%S")] "

  return ${THISRC}
}

# ----------------------------------------------------------------------
# wait_some_seconds
#
# function: wait n seconds
#
# usage: wait_some_seconds [number_of_seconds]
#
# returns: ${__TRUE}  - waited n seconds
#          ${__FALSE} - no parameter found, to many parameter found,
#                       or the parameter is not a number
#
function wait_some_seconds {
  typeset THISRC=${__FALSE}

  typeset WAIT_TIME_IN_SECONDS="$1"

  if [ $# -eq 1 ] ; then
    if isNumber ${WAIT_TIME_IN_SECONDS} ; then
      echo "[$( date "+%Y.%m.%d %H:%M:%S")] Waiting now ${WAIT_TIME_IN_SECONDS} seconds ..."
      sleep ${WAIT_TIME_IN_SECONDS}
      THISRC=${__TRUE}
    fi
  fi

  return ${THISRC}
}

# ---------------------------------------------------------------------
# main function
#

echo "${SCRIPT_NAME} version - ${SCRIPT_VERSION} - install TWRP to the boot partition of a phone running Android using TWRP"
echo ""

if [ "$1"x = "-h"x ] ; then
  grep "^#h#" $0 | cut -c4-
  die 10

elif [ "$1"x = "-H"x -o "$1"x = "--help"x -o "$1"x = "help"x ] ; then
#
# extract the usage help from the script source
#
  grep -i "^#H#" $0 | cut -c4-
 
  echo ""
  echo " The default TWRP image to use is \"${TWRP_IMAGE}\" "
  echo " The default script executed on the phone to install TWRP is \"${DEFAULT_TWRP_INSTALL_SCRIPT}\" "
  echo ""
  exit 1
fi

#
# process the parameter for the slot to use (if any)
#
while [ $# -ge 1 ] ; do

  case $1 in
    a | slot_a | _a )
      BOOT_SLOT_TO_USE="_a"
      shift
    ;;

    b | slot_b  | _b )
      BOOT_SLOT_TO_USE="_b"
      shift
    ;;

    active | current )
      BOOT_SLOT_TO_USE="active"
      shift
    ;;

    inactive | next )
      BOOT_SLOT_TO_USE="inactive"
      shift
    ;;

    wait=* )
      WAIT_TIME_IN_SECONDS="${1#*=}"
      shift
      ;;

    dd )
      USE_FASTBOOT_TO_FLASH_THE_BOOT_PARTITION=${__FALSE}
      shift
      ;;

    fastboot )
      USE_FASTBOOT_TO_FLASH_THE_BOOT_PARTITION=${__TRUE}
      shift
      ;;

    reboot | --reboot | -reboot )
      REBOOT=yes
      shift
      ;;

    noreboot | --noreboot | -noreboot )
      REBOOT=no
      shift
      ;;

    * )
      if [ "${TWRP_IMAGE}"x != ""x ] ; then
        die 6 "ERROR: Unknown parameter found: \"${TWRP_IMAGE}\" "
      fi
      TWRP_IMAGE="$1"
      shift
  esac
done  


if [ "${TWRP_IMAGE}"x = ""x ] ; then
  TWRP_IMAGE="${DEFAULT_TWRP_IMAGE}"
  echo "Using the TWRP image defined via parameter"
fi

echo "Using the TWRP image \"${TWRP_IMAGE}\" "

[ ! -r "${TWRP_IMAGE}" ] && die 5 "TWRP image \"${TWRP_IMAGE}\" not found"

[ $# -ne 0 ] && die 6 "Unknown parammeter found: \"$*\" "


ERRORS_FOUND=${__FALSE}

echo "Checking the script prerequisites ..."

if [ ${USE_FASTBOOT_TO_FLASH_THE_BOOT_PARTITION} = ${__TRUE} ] ; then
#
# if using fastboot to flash the boot image we must download the new boot image
# file from the phone. This will be done in the current directory of the PC
#
# check if we can write to the current directory
#
  echo "Checking if we have write access for the current working directory \"${PWD}\"  ..."

  touch $PWD/xxx.$$
  if [ $? -eq 0 ] ; then
    \rm ${PWD}/xxx.$$ 2>/dev/null
  else
    echo "ERROR: Can not write to the current working directory \"${PWD}\" "
    ERRORS_FOUND=${__TRUE}
  fi
fi

for CUR_PROG in adb fastboot timeout cksum ; do
  EXECUTABLE="$( which "${CUR_PROG}" )"
  if [ "${EXECUTABLE}"x = ""x ] ; then
    echo "ERROR: The executable \"${CUR_PROG}\" is not available via the PATH"
    ERRORS_FOUND=${__TRUE}
  fi
done

if [ "${WAIT_TIME_IN_SECONDS}"x = ""x ] ; then
  WAIT_TIME_IN_SECONDS="${DEFAULT_WAIT_TIME_IN_SECONDS}"
fi

if ! isNumber "${WAIT_TIME_IN_SECONDS}"  ; then
  echo "ERROR: The value for the wait time, \"${WAIT_TIME_IN_SECONDS}\", is not a number"
  ERRORS_FOUND=${__TRUE}
else
  echo "Will wait ${WAIT_TIME_IN_SECONDS} second(s) before starting the script on the phone"
fi

if [ "${TWRP_INSTALL_SCRIPT}"x = ""x ] ; then
  TWRP_INSTALL_SCRIPT="${DEFAULT_TWRP_INSTALL_SCRIPT}"
fi

if [ ! -r "${TWRP_INSTALL_SCRIPT}" ] ; then
  echo "The script to install TWRP on the phone \"${TWRP_INSTALL_SCRIPT}\" does not exist"
  ERRORS_FOUND=${__TRUE}
fi

if [ ${ERRORS_FOUND} = ${__TRUE} ] ; then
  die 7 "One or more errors found in the prerequisite checks"
fi

#
# fastboot must be executed by the user root -> use sudo if the script is executed by a non-root user
#
CUR_USER="$( whoami )"
if [ "${CUR_USER}"x != "root"x ] ; then
  SUDO_PREFIX="sudo"
  echo "The script is running as user \"${CUR_USER}\" -- will use \"${SUDO_PREFIX}\" for the fastboot commands ..."
else
  SUDO_PREFIX=""
fi

#
# check if the variable SERIAL_NUMBER is used
#
if [ "${SERIAL_NUMBER}"x != ""x ] ; then
  echo "Will patch the boot partition on the phone with the serial number found in the environment variable SERIAL_NUMBER: \"${SERIAL_NUMBER}\""
  ADB_OPTIONS="${ADB_OPTIONS} -s ${SERIAL_NUMBER} "
  FASTBOOT_OPTIONS="${FASTBOOT_OPTIONS} -s ${SERIAL_NUMBER} "
else
#
# check if there is more then one phone connected via USB
#
  ADB_DEVICES="$( adb ${ADB_OPTIONS} devices | tail -n +2 | grep -v ":" )"
  NO_OF_ADB_DEVICES=$( echo "${ADB_DEVICES}" | wc -l )

  if [ ${NO_OF_ADB_DEVICES} -gt 1 ] ; then
    echo "Found multiple phones connected via USB:"
    echo ""
    echo "${ADB_DEVICES}"
    echo  ""
    echo "ERROR: There are more than one phones connected via USB"
    echo "       Please select a phone to update by setting the variable SERIAL_NUMBER to the serial number of the phone that should be patched before executing this script"
    die 9 "To many phones connected"
  else
    SERIAL_NUMBER="$( echo "${ADB_DEVICES}" | awk '{ print $1 }' )"

    if [ "${SERIAL_NUMBER}"x != ""x ] ; then

      echo "Will patch the boot partition on the attached phone with the serial number \"${SERIAL_NUMBER}\""
  
      ADB_OPTIONS="${ADB_OPTIONS} -s ${SERIAL_NUMBER} "
      FASTBOOT_OPTIONS="${FASTBOOT_OPTIONS} -s ${SERIAL_NUMBER} "
    fi
  fi
fi

echo "Using the options \"${ADB_OPTIONS}\" for the adb commands "
echo "Using the options \"${FASTBOOT_OPTIONS}\" for the fastboot commands "

# Check if the phone is already booted in fastboot mode
#
echo "Checking for a connected phone booted into fastboot mode ..."

CUR_FASTBOOT_VARIABLES="$( ${SUDO_PREFIX} timeout 3 fastboot ${FASTBOOT_OPTIONS} getvar all 2>&1 )"
if [ $? -eq 0 ] ; then
  echo "The attached phone is booted into fastboot mode or bootloader"
else
  echo "No attached phone in fastboot mode found"

  echo "Checking for an attached phone with working access via adb (USB) ..."

  adb ${ADB_OPTIONS} shell uname -a || die 11 "Can not access the phone - neither via fastboot nor via adb"

  echo "... found a phone connected via USB with working adb access"

#
# check if the phone is already booted from the TWRP image 
#
  TWRP_STATUS="$( adb ${ADB_OPTIONS} shell getprop ro.twrp.boot )"
  if [ "${TWRP_STATUS}"x != "1"x ] ; then
#
# no TWRP image found - check for OrangeFox recovery
#
    TWRP_STATUS="$( adb ${ADB_OPTIONS} shell getprop ro.orangefox.boot )"
    if [ "${TWRP_STATUS}"x = "1"x ] ; then
      echo "The phone is booted from the OrangeFox recovery"
    fi
  fi
  
  if [ "${TWRP_STATUS}"x = "1"x ] ; then
    TWRP_BOOT_IMAGE="$( adb ${ADB_OPTIONS} shell getprop ro.product.bootimage.name )"
    TWRP_BOOT_IMAGE_VERSION="$( adb ${ADB_OPTIONS} shell getprop ro.twrp.version )"

    echo "The phone is already booted from a TWRP image: \"${TWRP_BOOT_IMAGE}\" version \"${TWRP_BOOT_IMAGE_VERSION}\" "
  else
#
# the phone is booted in normal mode
#
    echo "The phone is booted in normal mode"
    OS_SOFTWARE_VERSION="$( adb ${ADB_OPTIONS} shell getprop  ro.build.software.version )"
    [ "${OS_SOFTWARE_VERSION}"x = ""x ] && OS_SOFTWARE_VERSION="$( adb ${ADB_OPTIONS} shell getprop  ro.build.date )"

    OS_VERSION="$( adb ${ADB_OPTIONS} shell getprop  ro.build.version.release )"
    OS_DESC="$( adb ${ADB_OPTIONS} shell getprop  ro.build.description )"

    echo "Booting the phone into the bootloader now ..."

    adb ${ADB_OPTIONS} reboot bootloader

    wait_for_phone_to_be_in_fastboot_mode || die 13 "Booting the phone into the bootloader failed - Giving up..."
  fi
fi

if [ "${TWRP_STATUS}"x != "1"x ] ; then

  echo "Booting the phone from the TWRP image \"${TWRP_IMAGE}\" now  ..."

  ${SUDO_PREFIX} fastboot ${FASTBOOT_OPTIONS} boot "${TWRP_IMAGE}"

  wait_for_phone_with_a_working_adb_connection || die 15 "Booting the phone from the TWRP image failed - Giving up..."
fi


echo "Retrieving the current boot slot from the phone ..."

ACTIVE_BOOT_SLOT="$( adb ${ADB_OPTIONS} shell getprop ro.boot.slot_suffix )"

if [ "${ACTIVE_BOOT_SLOT}"x = ""x ] ; then
  echo "No slot property found - seems the phone does not support the A/B partition scheme"
  BOOT_SLOT_TO_USE=""
else
  echo "The current boot slot is \"${ACTIVE_BOOT_SLOT}\" "
fi

if [ "${BOOT_SLOT_TO_USE}"x = "_a"x -o "${BOOT_SLOT_TO_USE}"x = "_b"x ] ; then
  echo "Using the boot partition for the slot found in the parameter: ${BOOT_SLOT_TO_USE}"
else
  if [ "${ACTIVE_BOOT_SLOT}"x != ""x ] ; then
    if [ "${BOOT_SLOT_TO_USE}"x = "active"x ] ; then
      BOOT_SLOT_TO_USE="${ACTIVE_BOOT_SLOT}"
    elif [ "${BOOT_SLOT_TO_USE}"x = "inactive"x ] ; then
      if [ "${ACTIVE_BOOT_SLOT}"x = "_a"x ] ; then
        BOOT_SLOT_TO_USE="_b"
      else
        BOOT_SLOT_TO_USE="_a"
      fi
    fi
  fi

  if [ "${BOOT_SLOT_TO_USE}"x != ""x ] ; then
    echo "The boot slot to patch is \"${BOOT_SLOT_TO_USE}\" "
  fi
fi

CURRENT_BOOT_PARTITION_NAME="boot${BOOT_SLOT_TO_USE}"
CURRENT_BOOT_PARTITION="/dev/block/by-name/${CURRENT_BOOT_PARTITION_NAME}"

echo "The boot partition to patch is \"${CURRENT_BOOT_PARTITION_NAME}\" "

echo "Checking if the directory \"${TMP_DIR_ON_THE_PHONE}\" exists on the phone ...."

adb ${ADB_OPTIONS} shell ls -d "${TMP_DIR_ON_THE_PHONE}"

if [ $? -ne 0 ] ; then
  echo "WARNING: Directory \"${TMP_DIR_ON_THE_PHONE}\" not found on the phone, will try /tmp now ..."

  TMP_DIR_ON_THE_PHONE="/tmp"
  adb ${ADB_OPTIONS} shell ls -d "${TMP_DIR_ON_THE_PHONE}"
  if [ $? -ne 0 ] ; then
    die 9 "ERROR: Directory \"${TMP_DIR_ON_THE_PHONE}\" not found on the phone ."
  fi
fi

TWRP_INSTALL_SCRIPT_ON_THE_PHONE="${TMP_DIR_ON_THE_PHONE}/${TWRP_INSTALL_SCRIPT##*/}"

echo "Copying the script \"${TWRP_INSTALL_SCRIPT}\" to the phone ..."
adb ${ADB_OPTIONS} push "${TWRP_INSTALL_SCRIPT}" "${TWRP_INSTALL_SCRIPT_ON_THE_PHONE}" && \
  adb ${ADB_OPTIONS} shell chmod 755 "${TWRP_INSTALL_SCRIPT_ON_THE_PHONE}"
if [ $? -ne 0 ] ; then
  die 10 "Error copying \"${TWRP_INSTALL_SCRIPT}\" to the directory \"${TMP_DIR_ON_THE_PHONE}\" on the phone"
fi

CURRENT_BOOT_IMAGE_FILE="${TMP_DIR_ON_THE_PHONE}/${CURRENT_BOOT_PARTITION_NAME}.$$.img"

CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME="${CURRENT_BOOT_PARTITION_NAME}_witn_twrp.$$.img"
CURRENT_PATCHED_BOOT_IMAGE_FILE="${TMP_DIR_ON_THE_PHONE}/${CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME}"

echo "Creating the boot image file \"${CURRENT_BOOT_IMAGE_FILE}\" from the partition \"${CURRENT_BOOT_PARTITION}\" ..."

adb ${ADB_OPTIONS} shell dd if="${CURRENT_BOOT_PARTITION}" of="${CURRENT_BOOT_IMAGE_FILE}" || die 23 "Error creating the image file \"${CURRENT_BOOT_IMAGE_FILE}\" "

SRC_BOOT_IMAGE_FILE_SIZE="$( adb ${ADB_OPTIONS}  shell ls -l "${CURRENT_BOOT_IMAGE_FILE}" | awk '{ print $5}' )"

echo ""
echo "Checking the result ..."
sleep 1
adb ${ADB_OPTIONS} shell ls -l "${CURRENT_BOOT_IMAGE_FILE}" || die 25 "Something went wrong creating the image file \"${CURRENT_BOOT_IMAGE_FILE}\" "

BOOT_PARTITION_CHKSUM="$( adb ${ADB_OPTIONS} shell cksum "${CURRENT_BOOT_PARTITION}" | cut -f1 -d " " )"
BOOT_PARTITION_IMG_CHKSUM="$( adb ${ADB_OPTIONS} shell cksum "${CURRENT_BOOT_IMAGE_FILE}" | cut -f1 -d " " )"

# adb ${ADB_OPTIONS} shell cksum "${CURRENT_BOOT_PARTITION}" "${CURRENT_BOOT_IMAGE_FILE}"

echo "The check sums are:"
echo "The check sum of the boot partition \"${CURRENT_BOOT_PARTITION}\" on the phohe is  \"${BOOT_PARTITION_CHKSUM}\" "
echo "The check sum of the boot image file on the phone is \"${CURRENT_BOOT_IMAGE_FILE}\" is \"${BOOT_PARTITION_IMG_CHKSUM}\"   "

if [ "${BOOT_PARTITION_CHKSUM}"x != "${BOOT_PARTITION_IMG_CHKSUM}"x ] ; then
  die 248 "Error creating the image file \"${CURRENT_BOOT_IMAGE_FILE}\" from the boot partition \"${CURRENT_BOOT_PARTITION}\" on the phone (the check sums do not match)"
fi

echo "Installing TWRP using the boot image file \"${CURRENT_BOOT_IMAGE_FILE}\"  ..."
echo ""


# for unknown reasons repacking the image file will fail without a short break here most of the times ...
#
if [ "${WAIT_TIME_IN_SECONDS}"x != ""x -a  "${WAIT_TIME_IN_SECONDS}"x != "0"x ] ; then
  wait_some_seconds ${WAIT_TIME_IN_SECONDS}
fi

echo "Now executing \"${TWRP_INSTALL_SCRIPT_ON_THE_PHONE}\" on the phone ..."

echo " ---------------------------------------------------------------------- "
set -x
adb ${ADB_OPTIONS} shell "${TWRP_INSTALL_SCRIPT_ON_THE_PHONE}" "${CURRENT_BOOT_IMAGE_FILE}" "${CURRENT_PATCHED_BOOT_IMAGE_FILE}" 
TEMPRC=$?
set +x

[ ${TEMPRC} != 0 ] &&  die 29 "Error patching the boot image file \"${CURRENT_BOOT_IMAGE_FILE}\" "

echo " ---------------------------------------------------------------------- "

echo "Checking the result ..."

echo "The patched boot image is \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" "

adb ${ADB_OPTIONS} shell ls -l "${CURRENT_PATCHED_BOOT_IMAGE_FILE}"
if [ $? -ne 0 ] ; then
  echo "adb failed ... will try again in 2 seconds ..."
  sleep 2
  adb ${ADB_OPTIONS} shell ls -l "${CURRENT_PATCHED_BOOT_IMAGE_FILE}"  || die 31 "Something went wrong creating the patched image file \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" "
fi

NEW_BOOT_IMAGE_FILE_SIZE="$( adb ${ADB_OPTIONS}  shell ls -l "${CURRENT_PATCHED_BOOT_IMAGE_FILE}" | awk '{ print $5}' )"
if [ "${NEW_BOOT_IMAGE_FILE_SIZE}"x != "${SRC_BOOT_IMAGE_FILE_SIZE}"x ] ; then
  die 33 "The size of the new boot image file is ${NEW_BOOT_IMAGE_FILE_SIZE} but the size of the original image file is ${SRC_BOOT_IMAGE_FILE_SIZE} --that does not match"
fi

if [ ${USE_FASTBOOT_TO_FLASH_THE_BOOT_PARTITION} = ${__FALSE} ] ; then

  # Note: The dd command does not work without this little pause (don't ask me why ...)
  wait_some_seconds 5

  echo "Patching the partition \"${CURRENT_BOOT_PARTITION}\" from the patched boot image file \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" via dd ..."

  adb ${ADB_OPTIONS} shell dd  if="${CURRENT_PATCHED_BOOT_IMAGE_FILE}" of="${CURRENT_BOOT_PARTITION}" || die 35 "Error patching the patched image file \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" to \"${CURRENT_BOOT_PARTITION}\" "
  if [ $? -ne 0 ] ; then
    echo "WARNING: It looks like patching the \"${CURRENT_BOOT_PARTITION}\" via dd failed"
  fi

  echo "Checking the result ...."

  DEV_CHKSUM="$( adb ${ADB_OPTIONS} shell cksum "${CURRENT_BOOT_PARTITION}" | cut -f1 -d " " )"
  ORIGINAL_IMG_CHKSUM="$( adb ${ADB_OPTIONS} shell cksum "${CURRENT_BOOT_IMAGE_FILE}" | cut -f1 -d " " )"
  PATCHED_IMG_CHKSUM="$( adb ${ADB_OPTIONS} shell cksum "${CURRENT_PATCHED_BOOT_IMAGE_FILE}" | cut -f1 -d " " )"


  echo "The check sums for the images and devices on the phone are:"
  echo ""
  echo "Checksum   Size      File/Device name"
  echo "-------------------------------------"
  adb ${ADB_OPTIONS} shell cksum "${CURRENT_BOOT_IMAGE_FILE}" "${CURRENT_PATCHED_BOOT_IMAGE_FILE}" "${CURRENT_BOOT_PARTITION}"
  echo ""

  if [ "${DEV_CHKSUM}"x = ""x -o "${PATCHED_IMG_CHKSUM}"x = ""x -o "${ORIGINAL_IMG_CHKSUM}"x = ""x ] ; then
    echo "ERROR : Something went terrible wrong -- please connect via \"adb shell\" and check and correct the error"
    die 249
  elif [ "${DEV_CHKSUM}"x = "${PATCHED_IMG_CHKSUM}"x ] ; then
    echo "OK, patching the boot partition \"${CURRENT_BOOT_PARTITION}\" was successfull"
  elif [ "${DEV_CHKSUM}"x = "${ORIGINAL_IMG_CHKSUM}"x ] ; then
    echo "ERROR: The patching was NOT successfull -- the boot partition \"${CURRENT_BOOT_PARTITION}\" did not change"
  else
    echo "ERROR: The patching of the boot partition \"${CURRENT_BOOT_PARTITION}\" failed (the checksums do not match)!"
    echo "
Most probably the phone will NOT boot now

To fix it connect via adb to the phone

  abb shell

and do

# either restore the original boot partition

  dd if=\"${CURRENT_BOOT_IMAGE_FILE}\" of=\"${CURRENT_BOOT_PARTITION}\"

# or install the patched boot partition manual

  dd if=\"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" of=\"${CURRENT_BOOT_PARTITION}\"

"
    REBOOT_COMMAND="adb"
    die 251 "The patching of the boot partition \"${CURRENT_BOOT_PARTITION}\" was NOT successfull"
  fi
else

  wait_some_seconds 5

  echo "Patching the partition \"${CURRENT_BOOT_PARTITION}\" from the patched boot image file \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" via fastboot ..."

  echo "Downloading the patched boot image \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" from the phone ..."
  cd /tmp && adb ${ADB_OPTIONS} pull "${CURRENT_PATCHED_BOOT_IMAGE_FILE}" || die 37 "Error downloading the file \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" from the phone"

  PATCHED_IMG_CHKSUM="$( adb ${ADB_OPTIONS} shell cksum "${CURRENT_PATCHED_BOOT_IMAGE_FILE}" | cut -f1 -d " " )"

  LOCAL_PATCHED_IMG_CHKSUM="$( cksum "${CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME}" | cut -f1 -d " " )"

  echo "The check sum of the patched boot image \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" on the phohe is \"${PATCHED_IMG_CHKSUM}\" "
  echo "The check sum of the downloaded patched boot image \"${CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME}\" is                    \"${LOCAL_PATCHED_IMG_CHKSUM}\"   "

  if [ "${PATCHED_IMG_CHKSUM}"x != "${LOCAL_PATCHED_IMG_CHKSUM}"x ] ; then
    echo "ERROR downloading the file \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" from the phone (the check sums do not match)"
    die 250
  fi

  echo "Booting the phone into the fastboot mode now ..."

  adb ${ADB_OPTIONS} reboot bootloader

  wait_for_phone_to_be_in_fastboot_mode || die 39 "Booting the phone into the bootloader failed - Giving up..."

  echo "Flashing the partition \"${CURRENT_BOOT_PARTITION_NAME}\" with the patched image \"${CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME}\" ..."

  ${SUDO_PREFIX} fastboot ${FASTBOOT_OPTIONS} flash "${CURRENT_BOOT_PARTITION_NAME}" "${CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME}"
  if [ $? -ne 0 ] ; then
    die 41 "Error flashing \"${CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME}\" to the partition \"${CURRENT_BOOT_PARTITION_NAME}\" "
  fi

  REBOOT_COMMAND="fastboot"
fi

if [ "${REBOOT}"x = "yes"x -o "${REBOOT}"x = "YES"x ] ; then
  DO_REBOOT_THE_PHONE=${__TRUE}
elif [ "${REBOOT}"x = "no"x -o "${REBOOT}"x = "NO"x ] ; then
  echo "Automatically rebooting the phone is disabled"
  DO_REBOOT_THE_PHONE=${__FALSE}
else
  echo ""
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
  echo "Rebooting the phone now ..."

  if [ "${REBOOT_COMMAND}"x = "fastboot"x ] ; then
    ${SUDO_PREFIX} fastboot ${FASTBOOT_OPTIONS} reboot
  else
    adb ${ADB_OPTIONS} reboot
  fi
fi

die ${THISRC}
