#!/bin/bash
#
# Linux shell script to patch the boot partition with Magisk on a rooted phone with installed Magisk using fastboot, adb, and TWRP
#
#H# Note: Since version 4.0.0.0 this script needs the helper script boot_phone_from_twrp.sh
#H#
#H# Usage
#H# 
#h#    install_magisk_via_twrp.sh [-h|help|-H] [boot_slot] [wait=n] [--reboot|--noreboot]  [dd|fastboot] [twrp_image] [cleanup] [delete_adb_dir]  [adb_only] [use_apk] [copy_apk] [magisk_apk_file=file] [oldmethod|newmethod]
#h#
#h# The script boot_phone_from_twrp.sh is required by this script -- see the source code of the script
#h#
#H# All parameter are optional. The parameter can be used in any order.
#H#
#H# Use the parameter "help" or "-H" to print the detailed usage help; use the parameter "-h" to print only the short usage help
#h#
#H# The parameter "boot_slot" can be a, b, active, inactive, next, current; default is the current boot slot of the phone
#H#
#H# The value for the parameter "wait" is the number of seconds to wait before starting the script to install Magisk on the phone
#H# This seems to be necessary to avoid errors while repacking the boot image. The default wait time is 10 seconds.
#H#
#H# Use the parameter "dd" to request repatching via dd in an adb session ; use the parameter "fastboot" to request repatching via "fastboot"
#H# Default is to use "dd" to flash the patched boot image.
#H#
#H# The parameter "twrp_image" can be used to define another TWRP image to use. The parameter is optional - the default for "twrp_image"
#H# is hardcoded in the script (variable TWRP_IMAGE).
#H# The default TWRP image of the script is the TWRP for the ASUS Zenfone 8.
#H#
#H# If the parameter "delete_adb_dir" is used the script will delete all files and directories created in the directory /data after Magisk
#H# was successfully installed into the boot partition
#H#
#H# If the parameter "adb_only" is used the script will only install the directories and binaries for Magisk in the directory /data/adb.
#H#
#H# The script will unpack the necesseray files for adding Magisk to the boot partition from the installed Magisk apk file to 
#H# the temporary directory /data/local/tmp/MagiskInst if the files in /data/adb/magisk are missing. 
#H#
#H# Use the parameter "use_apk" to force the script to use the files from the Magisk app even if the files in /data/adb/magisk exist.
#H#
#H# Use the parameter "cleanup" to delete the temporary directory with Magisk at script end
#H#
#H# If the parameter "copy_apk" is used the script will copy the Magisk apk file to the phone.
#H#
#H# Use the parameter "magisk_apk_file=file" to install Magisk from another apk file
#H#
#H# The script checks the contents of the Magisk apk file to detect if the Magisk version is v26.0 or newer.
#H# To overwrite the result of this check use the parameter "old_method" (= assume the Magisk version is v25.x or older)
#H# or "new_method" (= assume the Magisk version is v26.x or newer)
#H# Note that installing Magisk via the new method only works if adb is already enabled in the installed Android OS. Note further
#H# that this method is only possible if the parameter "copy_apk" and "use_apk" are also used. Therefor the parameter "new_method" will also enable
#H# the parameter "copy_apk" and "use_apk".
#H#
#H# The script now can also install Magisk into a boot partition without an installed Magisk app. To use this feature copy the Magisk apk file
#H# (Magisk*apk) to the directory /data or /sdcard/Download on the phone before starting the script or use the parameter "copy_apk".
#H#
#H# The phone to patch must be attached via USB. 
#H# The phone can be either in fastboot mode, in normal mode with enabled adb support, or already booted from the TWRP image 
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
#H#   Set the environment variable DOWNLOAD_DIR_ON_PHONE to the data directory to use on the phone (def.: /sdcard/Download)
#H#
#H#   Set the envionment variable MAGISK_APK_FILE to the Magisk apk file to use
#H#
#H#   Set the environment variable FASTBOOT_WAIT_TIME to change the time out value to wait for booting into the fastboot mode
#H#
#H#   Set the environment variable ADB_BOOT_WAIT_TIME to change the time out value to wait until adb access is working after a reboot
#H#
#H#   Set the environment variable DECRYPT_DATA_WAIT_TIME to change the time out value to wait until the partition /data is decrypted after a reboot
#H#
#H# The script uses the script 
#H#
#H#    boot_phone_from_twrp.sh 
#H#
#

# History
#   11.06.2022 v1.0.0.0 /bs #VERSION
#     inital release
#
#   03.07.2022 v1.1.0.0 /bs #VERSION
#     the script now uses /tmp for temporary files if /sdcard/Download is not available
#
#   26.10.2022 v2.0.0.0 /bs #VERSION
#     corrected minor errors and added some small enhancements
#     corrected the parameter handling; unknown parameter are now not allowed anymore
#     updated the infos about the supported TWRP versions
#     the parameter can now be used in any order
#     added the parameter "wait=n"
#     the script now extracts the necessary files to install Magisk into the boot partition from the Magisk apk file if 
#       the directory /data/adb/magisk is missing
#     the script now can also install Magisk into a boot partition without installed Magisk app (only the Magisk apk file is required)
#     disabled the "error" messages "error message \"can't create /proc/self/fd/:"
#
#   05.11.2022 v2.0.0.1 /bs #VERSION
#     added an additional check for empty serial numbers
#     did some minor changes
#
#   17.12.2022 v2.1.0.0 /bs #VERSION
#     the script now searches the Magisk apk file in /sdcard/Downlaod and /data
#     added the parameter "copy_apk"
#     added the environment variable MAGISK_APK_FILE
#
#   27.12.2022 v2.2.0.0 /bs #VERSION
#     added the parameter delete_adb_dir
#
#   29.12.2022 v2.3.0.0 /bs #VERSION
#     added the parameter adb_only
#
#   06.01.2023 v2.4.0.0 /bs #VERSION
#     added the parameter magisk_apk_file=file
#
#   06.01.2023 v2.4.0.1 /bs #VERSION
#      the error message for unkknown parameter was wrong --fixed
#
#   25.01.2023 v2.5.0.0 /bs #VERSION
#      added the parametter --reboot and --noreboot
#
#   13.04.2023 v2.5.1.0 /bs #VERSION
#     added the file stub.apk to the temporary directory with the Magisk files
#       This file is necessary for Magisk v26.1
#
#   14.04.2023 v2.5.1.1 /bs #VERSION
#     the file stub.apk is not part of Magisk in versions before v26.0 -- fixed the code
#
#   14.04.2023 v3.0.0.0 /bs #VERSION
#     added code to support the installation of Magisk v26.0 or newer
#     added the parameter oldmethod and newmethod
#     the directory for the temporary Magisk files is now /data/local/tmp/MagiskInst
#
#   18.04.2023 v3.1.0.0 /bs #VERSION
#     the directory for the temporary Magisk files is now /data/MagiskInst for installing Magisk v25 or older 
#       and /data/local/tmp/MagiskInst for installing Magisk v26
#     finished the support for installing Magisk v26 or newer via script
#
#   30.04.2023 v3.1.1.0 /bs #VERSION
#     installing Magisk v26 or newer failed if the phone was protected and no password was defined -- fixed
#
#   05.05.2023 v3.1.1.0 /bs #VERSION
#     added code to check if the installed apk file is the real apk file (and not the stub.apk)
#
#   10.05.2023 v3.1.2.0 /bs #VERSION
#     the parameter adb_only failed if there was alreay an existing directory called /data/adb/magisk on the phone -- fixed
#     
#   10.10.2023 v3.1.3.0 /bs #VERSION
#     the script ignored the parameter for rebooting if the parameter adb_only was used -- fixed
#
#   26.11.2023 v3.1.3.1 /bs #VERSION
#     the script now deletes all files and directories in the temporary dir before moving the magisk files
#
#   27.04.2024 v3.1.3.2 /bs #VERSION
#     increased the timeout for waiting until /data is mounted from 20 seconds to 240 seconds (see #20240427# below)
#     added enviroment variables for the timeout values
# 
#   01.05.2024 v3.1.3.3 /bs #VERSION
#     the script now executes "adb reconnect" if the phone is in adb offline mode
#

#
#   19.05.2024 v4.0.0.0 /bs #VERSION
#     the script now uses the general routines from the helper script boot_phone_from_twrp.sh
#
# Author
#   Bernd.Schemmer (at) gmx.de
#   Homepage: http://bnsmb.de/
#
#
# Prerequisites
#   a computer running Linux with working adb and fastboot binaries available via PATH variable
#   a phone with installed Magisk and unlocked boot loader
#     Magisk must be used one time to patch a boot partition image file to create the necessary scripts and binaries used by this script on the phone
#   a working recovery image (e.g. TWRP) for the attached phone that automatically mounts /data and has enabled adb support 
#
# Test Environment
#
#   Note: For installing Magisk v26 or newer a working adb connection to the installed Android OS is required
#
#   Tested on an ASUS Zenfone 8 and with 
#
#     - OmniROM 12 (Android 12) and Magisk v24.3
#     - OmniROM 12 (Android 12) and Magisk v25.0
#     - OmniROM 12 (Android 12) and Magisk v26.1
#
#     - OmniROM 13 (Android 13) and Magisk v25.2
#     - OmniROM 13 (Android 13) and Magisk v26.1
#
#     - OmniROM 14 (Android 14) and Magisk v26.x
#     - OmniROM 14 (Android 14) and Magisk v27.x
# 
#     - AospExtended 9.x w/o GAPPS (Android 12) and Magisk v24.3
#     - AospExtended 9.x w/o GAPPS (Android 12) and Magisk v25.0
#
#     - ASUS Original Android 11 and Magisk v24.3
#
#     - ASUS Original Android 12 and Magisk v24.3
#     - ASUS Original Android 12 and Magisk v26.1
#
#     - ASUS Original Android 13 Beta 1 and Magisk v25.0
#     - ASUS Original Android 13 and Magisk v26.1
# 
#
#
# Details
#
#   The patched boot images will be created in the directory "/sdcard/Downloads" on the phone (variable DOWNLOAD_DIR_ON_PHONE)
#
#   The script will use the directory /tmp for the boot images if the directory /sdcard/Downloads is not available
#     Note that /tmp is mounted on a ramdisk and the files in that directory will not survive a reboot; /tmp is only available if booted from TWRP
#
#   The script uses the original script called "boot_patch.sh" from Magisk to patch the boot image.
#
#   You can execute the script as often as you like.
#
#   The script will not delete the created files in the directory "/sdcard/Download" on the phone so you might do a cleanup of that directory manually
#
#   If the checksum of the boot image before patching is equal to the checksum after successful patching, then Magisk has already been installed on the boot partition
#
#   The script will boot the phone multiple times for the installation 
#
# Notes [as of 06.06.2022]
#
#   For the ROMs based on Android 12 for the Asus Zenfone 8 the TWRP version 3.6.1_12 or newer is required .
#   Enter "/get working_twrp_for_a12" in the Telegram group  "OminiROM-zenfone8" to get the download link for that version.
#
# Update 23.10.2022 /bs
#
#   The official TWRP for the ASUS Zenfone 8 is now 3.7.0.12 and can be downloaded from here: https://twrp.me/asus/zenfone8.html 
#
# Update 15.04.2023 /bs
#
#   For installing Magisk v26.0 or newer the script version 3.1.0.0 or newer and a working adb connection to the installed Android OS is required
#
# Udpate 01.05.2024 /bs
#
#   For installing Magisk on an Android 14 based OS the TWRP version 3.7.1.0 or newer is required
#   For installing Magisk on LineageOS or a LineageOS based OS a special TWRP version created for that OS version is required 
#   -- see here for details : https://xdaforums.com/t/how-to-use-twrp-if-lineageos-20-x-is-installed.4599721/
#
#
# Trouble Shooting
#
#   - If the script ends with error messages like this
#
#       Repack to boot image: [new-boot.img]
#       Checking the result ...
#       adb: device 'M6AIB760D0939LX' not found
#       ERROR: Something went wrong creating the patched image file "/data/adb/magisk/new-boot.img"  (RC=31)
#
#     restart the script while the phone is still booted from the TWRP image.
#     To avoid these kind of errors increase the value for the parameter "wait=n"
#
#   - Error message like this
#
#       /data/adb/magisk/boot_patch.sh[211]: can't create /proc/self/fd/: Is a directory
#
#     can be ignored (these are only error messages from the function to print some additional messages)
#     Update 26.10.2022/bs : These error messages should not occur anymore
#
#   - Patching the boot partition via "dd" fails sometimes for unknown reason so you should only use it if you know how to fix a damaged boot partition!
#
#   - Downloading the patched boot image via "adb pull" (necessary for patching the boot partition using fastboot) sometimes fails for unknown reason:
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
#     Note:
#
#     In my enviroment it's sometimes necessary to restart the adb daemon on the phone as user root to get a connection to the phone
#     (but might be a personal problem of my environment ...)
# 

#SCRIPT_VERSION="2.0.0.1"
SCRIPT_VERSION="$( grep "^#" $0 | grep "#VERSION" | grep "v[0-9]" | tail -1 | awk '{ print $3}' )"

SCRIPT_NAME="${0##*/}"

SCRIPT_PATH="${0%/*}"

#
# for testing only (see source code)
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

# use "grep -E" instead of "egrep" if supported (this is OS independent)
#
echo test | grep -E test 2>/dev/null >/dev/null && EGREP="grep -E " || EGREP="egrep"


# ---------------------------------------------------------------------
# init some global variables
#

# default TWRP image to use
#
#DEFAULT_TWRP_IMAGE="/data/backup/ASUS_ZENFONE8/twrp/twrp-3.6.1_12-1-I006D.img"
DEFAULT_TWRP_IMAGE="/data/backup/ASUS_ZENFONE8/twrp/current_twrp.img"

# default Magisk apk file on the PC
#
DEFAULT_MAGISK_APK_FILE="/data/backup/Android/EssentialApps_Backup/Magisk-v26.4.apk"

# Magisk apk file to use
#
MAGISK_APK_FILE="${MAGISK_APK_FILE:=${DEFAULT_MAGISK_APK_FILE}}"

# helper script to boot the phone from the TWRP image if necessary
#
TWRP_REBOOT_HELPER_SCRIPT="boot_phone_from_twrp.sh"

# delete the files and dirs in /data/adb if created by this script at script end (parameter cleanup)
#
CLEANUP_TEMPORARY_FILES=${__FALSE}

# delete all sub directdories in the directory /data/adb (except /data/recovery) after Magisk 
# was successfully installed into the boot partition (parameter delete_adb_dir)
#
CLEANUP_DATA_DIR=${__FALSE}

# install only the directories and files in /data/adb (Parameter adb_only)
#
CONFIGURE_ADB_DIR_ONLY=${__FALSE}

# use the files from the apk file even if the necessary files /data/adb/magisk exist (parameter use_apk)
#
USE_APK=${__FALSE}

# copy the Magisk apk file to the phone 
#
COPY_APK=${__FALSE}

#
# default directory used to extract the data from the Magisk apk file if the files in /data/adb/magisk are missing 
# or if the use of the files from the Magisk apk is requested via parameter use_apk.
# Note that the directory used for installing Magisk v26 or newer is /data/local/tmp/MagiskInst
#
MAGISK_INST_DIR="/data/MagiskInst"

#
# data directory used by Magisk for executables, modules, and data
#
MAGISK_DATA_DIR="/data/adb"

#
# the Magisk database file
#
MAGISK_DATABASE_FILE="${MAGISK_DATA_DIR}/magisk.db"

# directory used by Magisk for binaries and scripts
#
DEFAULT_MAGISK_BIN_DIR="/data/adb/magisk"
MAGISK_BIN_DIR="${DEFAULT_MAGISK_BIN_DIR}"

# name of the patch script from Magisk
#
MAGISK_BOOT_PATCH_SCRIPT_NAME="boot_patch.sh"

# fully qualified name of the patch script from Magisk on the Phone
# (for details see the code to check if the script exists below)
#
MAGISK_BOOT_PATCH_SCRIPT="${MAGISK_BIN_DIR}/${MAGISK_BOOT_PATCH_SCRIPT_NAME}"

# default wait time in seconds before executing the script on the phone
#
DEFAULT_WAIT_TIME_IN_SECONDS=10

# default wait time to wait until the phone is booted and the partition /data is encrypted
#
DECRYPT_DATA_WAIT_TIME=${DECRYPT_DATA_WAIT_TIME:=240}

# the directory used for creating the image files on the phone
#
DOWNLOAD_DIR_ON_PHONE="${DOWNLOAD_DIR_ON_PHONE:=/sdcard/Download}"

#
# The fallback download directory is used if the directory /sdcard/Download is not usable. 
# 
FALLBACK_DOWNLOAD_DIR_ON_PHONE="${FALLBACK_DOWNLOAD_DIR_ON_PHONE:=/tmp}"

# general options for the adb command (-d : only use devices connected via USB)
#
ADB_OPTIONS="${ADB_OPTIONS:=-d}"

# general options for the fastboot command
#
FASTBOOT_OPTIONS="${FASTBOOT_OPTIONS:=}"

# The default for the boot slot that should be patched
#
CURRENT_BOOT_SLOT="active"

#
# new image created by the patch script from Magisk (the patch script from Magisk will create
# the new image in the directory with the patch script)
#
NEW_BOOT_IMG="${MAGISK_BIN_DIR}/new-boot.img"

NEW_BOOT_IMG_BACKUP="${NEW_BOOT_IMG}.$$"

# if this variable is ${__TRUE} the script uses fastboot to flash the boot partition with the patched boot image
# if this variable is ${__FALSE} the script uses dd in an adb session to write the patched boot image to the boot partition
#
USE_FASTBOOT_TO_FLASH_THE_BOOT_PARTITION=${__FALSE}

#
# this variable is ${__TRUE} if the script created the directories and files in ${MAGISK_INST_DIR}
#
DIRS_IN_DATA_ADB_CREATED=${__FALSE}

# package name of the installed Magisk application
#
MAGISK_PACKAGE="com.topjohnwu.magisk"


# uid and gid for the user "shell" in the running OS
#
SHELL_UID=2000
SHELL_GID=2000


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
      echo "Waiting now ${WAIT_TIME_IN_SECONDS} second(s) ..."
      sleep ${WAIT_TIME_IN_SECONDS}
      THISRC=${__TRUE}
    fi
  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# create_temporary_magisk_dir
#
# function: create a temporary directory with the magisk binaries
#
# usage: create_temporary_magisk_dir [temp_magisk_inst_dir] [apk_file]
#
# Default for temp_magisk_inst_dir is "${MAGISK_INST_DIR}"
#
# The magisk binaries will be in the directory "<temp_magisk_inst_dir>/bin" 
#
# returns: ${__TRUE}  - ok
#          ${__FALSE} - error, 
#
function create_temporary_magisk_dir {
  typeset THISRC=${__TRUE}

#
# process the parameter
#
  typeset CUR_MAGISK_INST_DIR="$1"
  
# CUR_MAGISK_INST_DIR = temporary installation directory for Magisk on the phone
#
  [ "${CUR_MAGISK_INST_DIR}"x = ""x ] && CUR_MAGISK_INST_DIR="${MAGISK_INST_DIR}"

  CUR_MAGISK_APK_FILE=$2
  
#
# script file on the phone
#  
  typeset SCRIPT_ON_THE_PHONE="${CUR_MAGISK_INST_DIR}/create_temporary_magisk_dir.sh"

# local file on the PC 
#
  typeset TMPFILE="/tmp/init_magisk_dirs.sh"

  typeset TEMPRC=""
  
  typeset ADD_PARM=""
  
#
# script contents
#  
  typeset SCRIPT_CODE='#!/system/bin/sh
#
# script to create a directory with the Magisk binaries and scripts
# required to install Magisk into the boot partition
#
# The script uses either the files from the installed Magisk App or
# the files from an Magisk apk file specified in the parameter.
# The script must be executed in the shell on the phone
#
# Usage:
#
#   create_temporary_magisk_dir.sh [magisk_inst_dir] [magisk_apk_file]
#
# magisk_inst_dir is the directory used for the Magisk files
#
# The binaries are then in the directory "<magisk_inst_dir>/bin"
#
# magisk_apk_file is the fully qualified name of an Magisk apk file to use
# This parameter is optional#
#
#
# History
#
#   26.10.2022 /bs
#     initial release
#
#   13.04.2023 /bs
#     added the file stub.apk  to the temporary directory with the Magisk files
#       This file is necessary for Magisk v26.1
#   14.04.2023 /bs
#     the file stub.apk is not part of Magisk in versions before v26.0 -- fixed the code
#   15.04.2023 /bs
#     the files from the sub directory chromeos are now copied to the correct directory
#     for arm 64 bit CPUs the magisk binary for arm 32 bit CPUs is now also copied
#     the use of a specific magisk apk file is now supported via parameter
#   05.05.2023 /bs
#     added code to check if the installed apk file is the real apk file (and not the stub.apk)
#
__TRUE=0
__FALSE=1

# ----------------------------------------------------------------------
# create_temporary_magisk_dir
#
# function: create a directory with the Magisk Binaries required to install Magisk into the boot partition
#           using the files from an apk file specified in the parameter or, if the parameter is missing,
#           from the installed Magisk apk file or an Magisk apk file in /sdcard/Download
#
# usage: create_temporary_magisk_dir [magisk_inst_dir] [magisk_apk_file]
#
# returns: ${__TRUE}  - ok
#          ${__FALSE} - error, 
#
#
# magisk_inst_dir is the directory in which the Magisk files should be copied.
# The default for the parameter magisk_inst_dir is "/data/MagiskInst"
#
# If there is a Magisk apk file specified in the parameter the script will use that file.
# If no parameter for the Magisk apk file is used the script uses the files from the installed Magisk app.
# If Magisk is not already installed and there is no Magisk apk file specified in the parameter
# the script searches for a Magisk apk file in the directory /sdcard/Download and, if not found in that directory, in /data.
#
function create_temporary_magisk_dir {
  typeset THISRC=${__TRUE}

  typeset MAGISK_INST_DIR="$1"
  [ "${MAGISK_INST_DIR}"x = ""x ] && MAGISK_INST_DIR="/data/MagiskInst"
  
  typeset MAGISK_APK_FILE="$2"
  
# directory to unpack the apk file
#
  typeset MAGISK_TEMP_DIR="${MAGISK_INST_DIR}/magisk_apk_contents.$$"

# directory for the Magisk binaries
#  
  typeset MAGISK_BIN_DIR="${MAGISK_INST_DIR}/bin"
  
  typeset ABI="$( getprop ro.product.cpu.abi )"

  typeset CUR_DIR=""
  
  typeset ERRORS_FOUND=${__FALSE}
  typeset file=""

  if [ "$( which pm )"x != ""x ] ; then
    if [ "${MAGISK_APK_FILE}"x = ""x ] ; then
      MAGISK_APK_FILE="$( pm path com.topjohnwu.magisk | cut -f2- -d":" )"
    fi
  fi
  
  if [ "${MAGISK_APK_FILE}"x = ""x ] ; then
     echo "Searching for an installed Magisk app ...."
     MAGISK_APK_FILE="$( ls /data/app/*/com.topjohnwu.magisk*/base.apk )"
  else
    echo "Magisk is not yet installed" 
  fi

#
# check if the installed apk is the "real" apk file
#
  if [ "${MAGISK_APK_FILE}"x != ""x ] ; then
    unzip -t "${MAGISK_APK_FILE}" | grep "META-INF/com/google/android/updater-script" >/dev/null
    if [ $? -ne 0 ] ;then
      echo "Found \"${MAGISK_APK_FILE}\" -- but that is only the stub.apk from Magisk"
      MAGISK_APK_FILE=""
    fi
  fi

  if [ "${MAGISK_APK_FILE}"x = ""x ] ; then
    echo "Searching for a Magisk apk file in the directory /sdcard/Download ..."
    MAGISK_APK_FILE="$( ls -1tr /sdcard/Download/Magisk*apk | tail -1 )"

    if [ "${MAGISK_APK_FILE}"x = ""x ] ; then
      echo "Searching for a Magisk apk file in the directdory /data ..."
      MAGISK_APK_FILE="$( ls -1tr /data/Magisk*apk | tail -1 )"
    fi
      
    if [ "${MAGISK_APK_FILE}"x = ""x ] ; then
      echo "ERROR: No Magisk apk file found neither in /sdcard/Download nor in /data"
      ERRORS_FOUND=${__TRUE}
    else
      echo "Found the apk file \"${MAGISK_APK_FILE}\" "
    fi
  fi

  echo "Using the directory \"${MAGISK_BIN_DIR}\" for the Magisk Binaries "

  if [ "${MAGISK_APK_FILE}"x = ""x ] ; then
   :
  elif [ ! -r "${MAGISK_APK_FILE}" ] ; then
    echo "ERROR: No Magisk .apk file found - most probably the Magisk App is not yet installed"
    ERRORS_FOUND=${__TRUE}
  elif [ "${ABI}"x = ""x ] ; then
    echo "ERROR: Can not detect the type of the CPU"
    ERRORS_FOUND=${__TRUE}
  elif ! unzip -t "${MAGISK_APK_FILE}" | grep "lib/${ABI}" >/dev/null ; then
    echo "ERROR: The CPU \"${ABI}\" is NOT supported by the .apk file \"${MAGISK_APK_FILE}\" "
    ERRORS_FOUND=${__TRUE}
  elif ! mkdir -p "${MAGISK_TEMP_DIR}" ; then
    echo "ERROR: Can not create the temporary directory \"${MAGISK_TEMP_DIR}\" "
    ERRORS_FOUND=${__TRUE}
  elif ! mkdir -p "${MAGISK_BIN_DIR}"  ; then
    echo "ERROR: Can not create the temporary directory \"${MAGISK_BIN_DIR}\" "
    ERRORS_FOUND=${__TRUE}
  else
    echo "Creating the files in the directory \"${MAGISK_BIN_DIR}\" using the files for the CPU \"${ABI}\" from the apk file \"${MAGISK_APK_FILE}\" ..."
      
    if [ ${ERRORS_FOUND} = ${__FALSE} ] ; then
      echo "Unpacking the apk file \"${MAGISK_APK_FILE}\" into the directory \"${MAGISK_TEMP_DIR}\" ..."
      cd "${MAGISK_TEMP_DIR}" && unzip -o "${MAGISK_APK_FILE}" >/dev/null
      if [ $? -ne 0 ] ; then
        echo "ERROR: Error unpacking the file \"${MAGISK_APK_FILE}\" "
        ERRORS_FOUND=${__TRUE}
      fi
    fi

    if [ ${ERRORS_FOUND} = ${__FALSE} ] ; then

#
# Update 26.11.2023 /bs
# 
      echo "Delete all existing files in the directory \"${MAGISK_BIN_DIR}\" ..."
      set -x
      ls -l "${MAGISK_BIN_DIR}"
      rm -rf "${MAGISK_BIN_DIR}/"*
      ls -l "${MAGISK_BIN_DIR}"
      set +x
      echo ""
      
      echo "Copying the files to \"${MAGISK_BIN_DIR}\" ..."
      set -x

      mv ./assets/util_functions.sh  "${MAGISK_BIN_DIR}"   || ERRORS_FOUND=${__TRUE}
      mv ./assets/chromeos "${MAGISK_BIN_DIR}/"            || ERRORS_FOUND=${__TRUE} 
      mv ./assets/boot_patch.sh "${MAGISK_BIN_DIR}"        || ERRORS_FOUND=${__TRUE} 
      mv ./assets/addon.d.sh "${MAGISK_BIN_DIR}"           || ERRORS_FOUND=${__TRUE}

# the file ./assets/stub.apk only exists in Magisk v26.0 or newer
#
      if [ -r ./assets/stub.apk ] ; then
        mv ./assets/stub.apk "${MAGISK_BIN_DIR}"           || ERRORS_FOUND=${__TRUE}
      fi
#
# Note: the next code is copied from a Magisk script      
#
      cd "./lib/${ABI}" && \
        for file in lib*.so; do 
          mv "$file" "${MAGISK_BIN_DIR}/${file:3:${#file}-6}" || ERRORS_FOUND=${__TRUE}
        done

      cd ../..
      file="libmagisk32.so"
      if [ "${ABI}"x = "arm64-v8a"x -a -r ./lib/armeabi-v7a/$file ] ; then
        mv ./lib/armeabi-v7a/$file "${MAGISK_BIN_DIR}/${file:3:${#file}-6}" || ERRORS_FOUND=${__TRUE}
      fi
      
      set +x
    fi        
  fi

  if [ ${ERRORS_FOUND} = ${__FALSE} ] ; then
    chmod -R 755 ${MAGISK_BIN_DIR}/* || ERRORS_FOUND=${__TRUE}
  fi
  
  if [ ${ERRORS_FOUND} = ${__FALSE} ] ; then
    TIHSRC=${__FALSE}
  else
    echo "Deleting the temporary files in \"${MAGISK_TEMP_DIR}\" ..."
    rm -rf "${MAGISK_TEMP_DIR}"
    
    TIHSRC=${__TRUE}
  fi

  if [ ${ERRORS_FOUND} = ${__TRUE} ] ; then
    THISRC=${__FALSE}
  fi
  
  return ${THISRC}
}

  create_temporary_magisk_dir $1 $2
'


  echo "Creating the temporary directory \"${MAGISK_INST_DIR}\" with the Magisk files necessarry to install Magisk into the boot partition ..."
  echo ""

  echo "Creating the script file \"${TMPFILE}\" to create the directory \"${MAGISK_INST_DIR}\" on the phone ..."
  echo "${SCRIPT_CODE}" >"${TMPFILE}"
  if [ $? -ne 0 ] ; then
    echo "ERROR: Error creating the temporary script file \"${TMPFILE}\" "
    THISRC=${__FALSE}
  else

    echo "Creating the directory \"${CUR_MAGISK_INST_DIR}\" on the phone ..."
    adb ${ADB_OPTIONS} shell mkdir -p "${CUR_MAGISK_INST_DIR}"
    if [ $? -ne 0 ] ; then
      echo "ERROR: Error creating the directory \"${CUR_MAGISK_INST_DIR}\" on the phone"
      THISRC=${__FALSE}
    else
      echo "Copying the temporary script file \"${TMPFILE}\" to the file \"${SCRIPT_ON_THE_PHONE}\" on the phone ..."
      adb ${ADB_OPTIONS} push "${TMPFILE}" "${SCRIPT_ON_THE_PHONE}" && adb ${ADB_OPTIONS} shell chmod 755 "${SCRIPT_ON_THE_PHONE}"
      if [ $? -ne 0 ] ; then
        echo "ERROR: Error copying the temporary script file \"${TMPFILE}\" to the file \"${SCRIPT_ON_THE_PHONE}\" on the phone "
        THISRC=${__FALSE}
      else
        echo "Executing the script \"${SCRIPT_ON_THE_PHONE}\" on the phone ..."

        [ ${USE_APK} = ${__TRUE} ] && ADD_PARM="${CUR_MAGISK_APK_FILE}" 

        echo " ------------------------------------------------------------------------------ "
        set -x
        adb ${ADB_OPTIONS} shell "${SCRIPT_ON_THE_PHONE}" "${MAGISK_INST_DIR}" "${ADD_PARM}"
        TEMPRC=$?
        set +x
        echo " ------------------------------------------------------------------------------ "
        
        if [ ${TEMPRC} -ne 0 ] ; then
          echo "ERROR: Error executing the script \"${SCRIPT_ON_THE_PHONE}\" on the phone "
          THISRC=${__FALSE}
        else 
          echo "... \"${SCRIPT_ON_THE_PHONE}\" successfully executed"
        fi   
      fi
    fi
  fi
   
  return ${THISRC}
}


# ----------------------------------------------------------------------
# cleanup_temporary_files
#
# function: cleanup /data directory or delete the files and directories in ${MAGISK_INST_DIR} if requested and necessary
#
# usage: cleanup_temporary_files
#
# returns: ${__TRUE}  - ok, files deleted
#          ${__FALSE} - files not deleted
#
function cleanup_temporary_files {
  typeset THISRC=${__FALSE}

  if [ ${CLEANUP_DATA_DIR} = ${__TRUE} ] ; then
    
    echo "Deleting all used files and directories in the directory /data  ..." 
    
    adb  ${ADB_OPTIONS}  shell rm -rf "${MAGISK_DATA_DIR}/"* "${MAGISK_INST_DIR}" "/data/${MAGISK_APK_FILE##*/}"

  elif [ ${DIRS_IN_DATA_ADB_CREATED} = ${__TRUE} ] ; then

#
# copy the Magisk binaries to the default Magisk bin directory if necessary
#
    if ! adb shell test -x "${DEFAULT_MAGISK_BIN_DIR}/magiskboot"  ; then
      if [ "${DEFAULT_MAGISK_BIN_DIR}"x != "${MAGISK_BIN_DIR}"x ] ; then
        echo "Copying the Magisk binaries from \"${MAGISK_BIN_DIR}\" to \"${DEFAULT_MAGISK_BIN_DIR}\" ..."

        adb  ${ADB_OPTIONS}  shell "mkdir -p ${DEFAULT_MAGISK_BIN_DIR} && 
        chmod 755 ${DEFAULT_MAGISK_BIN_DIR} && 
        cp -arf ${MAGISK_BIN_DIR}/* ${DEFAULT_MAGISK_BIN_DIR}  &&
# ???        chcon -v r:magisk_file:s0 ${DEFAULT_MAGISK_BIN_DIR} &&
        chcon -v u:object_r:system_file:s0 ${DEFAULT_MAGISK_BIN_DIR} &&

# ???        chcon -v u:object_r:magisk_file:s0 ${DEFAULT_MAGISK_BIN_DIR}/*
        chcon -v u:object_r:system_file:s0 ${DEFAULT_MAGISK_BIN_DIR}/*
        "

        if [ $? -ne 0 ] ; then
          echo "WARNING: Copying the Magisk binaries to \"${DEFAULT_MAGISK_BIN_DIR}\" failed"
        else
          echo "Magisk binaries successfully copied to \"${DEFAULT_MAGISK_BIN_DIR}\" "
        fi
      fi
    else
      echo "INFO: The Magisk binaries in \"${DEFAULT_MAGISK_BIN_DIR}\" already exist"
    fi
  fi

  if [ "${CLEANUP_TEMPORARY_FILES}"x = "${__TRUE}"x ] ; then
    if [ "${MAGISK_INST_DIR}"x != ""x ] ; then
      echo "Deleting the directories and files in \"${MAGISK_INST_DIR}\" ..."
      adb  ${ADB_OPTIONS}  shell rm -rf "${MAGISK_INST_DIR}" 
      THISRC=${__TRUE}
    fi
  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# patch_a_boot_image_file
#
# function: patch the boot image file ${CURRENT_BOOT_IMAGE_FILE} using the 
#           patch script from Magisk ${MAGISK_BOOT_PATCH_SCRIPT}; 
#           the patched image is then ${CURRENT_PATCHED_BOOT_IMAGE_FILE}
#
# usage: patch_a_boot_image_file 
#
# returns: ${__TRUE}  - ok, patching was sucessfull
#          ${__FALSE} - an error occured
#
function patch_a_boot_image_file {
  typeset THISRC=${__TRUE}
  
  adb ${ADB_OPTIONS} shell "export BOOTMODE=true ;  ${MAGISK_BOOT_PATCH_SCRIPT} ${CURRENT_BOOT_IMAGE_FILE}" || die 29 "Error patching the boot image file \"${CURRENT_BOOT_IMAGE_FILE}\" "

  echo "Checking the result ..."

  adb ${ADB_OPTIONS} shell ls -l "${NEW_BOOT_IMG}" || die 31 "Something went wrong creating the patched image file \"${NEW_BOOT_IMG}\" "

  adb ${ADB_OPTIONS} shell mv "${NEW_BOOT_IMG}" "${CURRENT_PATCHED_BOOT_IMAGE_FILE}" || die 33 "Error creating the boot image file \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" "

  echo "The patched boot image is \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" "

  return ${THISRC}
}
 
# ----------------------------------------------------------------------
# install_magisk_using_the_old_method
#
# function: install Magisk into the boot partition using the old method that is valid for Magisk version before v26.0
#           (= install Magisk into the boot partition while booted from a recovery image)
#
# usage: cleanup_temporary_files
#
# returns: ${__TRUE}  - ok, the patching was sucessfull
#          ${__FALSE} - error patching the boot image file
#
function install_magisk_using_the_old_method {
  typeset THISRC=${__TRUE}

  echo "Installing Magisk into the boot partition using the old method ..."
  
  echo "Patching the boot image file \"${CURRENT_BOOT_IMAGE_FILE}\"  ..."

# for unknown reasons repacking the image file will fail without a short break here most of the times ...
#
  if [ "${WAIT_TIME_IN_SECONDS}"x != ""x -a  "${WAIT_TIME_IN_SECONDS}"x != "0"x ] ; then
    wait_some_seconds ${WAIT_TIME_IN_SECONDS}
  fi

  patch_a_boot_image_file
  THISRC=$?
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# install_magisk_using_the_new_method
#
# function: install Magisk into the boot partition using the new method that is required for Magisk version v26.0 and newer
#           (= patch the boot image file while booted into the Android OS)
#
# usage: install_magisk_using_the_new_method
#
# returns: ${__TRUE}  - ok, the patching was sucessfull
#          ${__FALSE} - error patching the boot image file
#
function install_magisk_using_the_new_method {
  typeset THISRC=${__TRUE}
 
  echo "Installing Magisk into the boot partition using the new method ..."

  echo "Patching the boot image file \"${CURRENT_BOOT_IMAGE_FILE}\" ..."

  echo "Preparing the directory with the temporary Magisk installation files for usage by the user with the UID 2000 (this is the user \"shell\") ..."

  set -x
  adb ${ADB_OPTIONS} shell chown -R ${SHELL_UID}:${SHELL_GID} "${MAGISK_INST_DIR}"
  adb ${ADB_OPTIONS} shell chmod -R 755 "${MAGISK_INST_DIR}"
  
  adb ${ADB_OPTIONS} shell chown -R ${SHELL_UID}:${SHELL_GID} "${CURRENT_BOOT_IMAGE_FILE}"
  adb ${ADB_OPTIONS} shell chmod o+r "${CURRENT_BOOT_IMAGE_FILE}"
  set +x

# for debugging only !
#
# echo "Press return to continue ..."
# read USER_INPUT

# 
# 01.04.2024 /bs
#   the image of the boot partition sometimes is gone after booting the phone (don't know why ...)
#   therefor we copy it to the PC and restore it after rebooting the phone into the Android OS now
#

# -------
#  ugly workaround -- part 1
#
  cd /tmp
  LOCAL_TMP_FILE="${PWD}/${CURRENT_BOOT_IMAGE_FILE##*/}"

  echo "Copying the file \"${CURRENT_BOOT_IMAGE_FILE}\" to the local PC now \"${LOCAL_TMP_FILE}\" ..."
  
  adb ${ADB_OPTIONS} pull "${CURRENT_BOOT_IMAGE_FILE}" || \
    \rm -f "${LOCAL_TMP_FILE}"

# -------
  
  echo "Rebooting the phone into the Android OS now ..."

  adb ${ADB_OPTIONS} reboot

  wait_for_phone_with_a_working_adb_connection || die 246 "Something went wrong booting the phone into the Android OS or the adb connection is not working anymore"
  PROP_RO_BOOTMODE="$( adb ${ADB_OPTIONS} shell getprop ro.bootmode )"
  if [ "${PROP_RO_BOOTMODE}"x = "recovery"x ] ; then
    die 245 "Something went wrong: The phone is still booted in the recovery"
  fi
  
  echo "The phone is now booted into the Android OS."

# -------
  
  MAGISK_BOOT_PATCH_SCRIPT="${MAGISK_INST_DIR}/bin/${MAGISK_BOOT_PATCH_SCRIPT_NAME}"
  echo "Using the patch script \"${MAGISK_BOOT_PATCH_SCRIPT}\" ..."

#20240427# 27.04.2024 : Time Limit increased from 20 to 240 seconds
#  
  
  printf "Waiting up to ${DECRYPT_DATA_WAIT_TIME} seconds for /data to get mounted and decrypted ...."
  i=0
  while [ $i -lt ${DECRYPT_DATA_WAIT_TIME} ] ; do 
    (( i = i + 1 ))
    printf "."
#    adb shell test -e "${CURRENT_BOOT_IMAGE_FILE}" && break

    adb ${ADB_OPTIONS}  shell test -d "${CURRENT_BOOT_IMAGE_FILE%/*}" && break
    sleep 1
  done
  printf "\n"
  echo " .. /data is mounted and decrypted after ${i} second(s)"

# -------
#  ugly workaround -- part 2
#
  echo "Checking if the file \"${CURRENT_BOOT_IMAGE_FILE}\" exists on the phone ..."
  CUR_OUTPUT="$( adb ${ADB_OPTIONS}  shell test -r ${CURRENT_BOOT_IMAGE_FILE} 2>&1 )"
  TEMPRC=$?
  echo "-" "${CUR_OUTPUT}"
  
  if [ ${TEMPRC} != 0 -a -r "${LOCAL_TMP_FILE}" ] ; then
    echo "Copying the file \"${LOCAL_TMP_FILE}\" to the phone \"${CURRENT_BOOT_IMAGE_FILE}\" ..."
    wait_some_seconds 5
    adb push "${LOCAL_TMP_FILE}" "${CURRENT_BOOT_IMAGE_FILE}" && \
      \rm -f "${LOCAL_TMP_FILE}"
  fi
  
  patch_a_boot_image_file 

#
# install the new Magisk app
#     
  if [ "${MAGISK_APK_FILE}"x = ""x ] ; then
    echo "WARNING: No Magisk apk file found - can not install the Magisk app"
  else
    
    adb ${ADB_OPTIONS} shell pm list packages | grep "${MAGISK_PACKAGE}" >/dev/null
    if [ $? -ne 100 ] ; then
      echo "The Magisk app is not yet installed"
      echo "Now installing the Magisk App using the apk file \"${MAGISK_APK_FILE}\" ..."
    else
      echo "The Magisk app is already installed"
      echo "Now updating the Magisk App using the apk file \"${MAGISK_APK_FILE}\" ..."
    fi

    CUR_APK_SIZE=$( ls -l "${MAGISK_APK_FILE}" | awk '{ print $5}' )
    set -x
    cat "${MAGISK_APK_FILE}" | adb ${ADB_OPTIONS} shell pm install -S ${CUR_APK_SIZE}
    TEMPRC=$?
    set +x
    LogMsg "The RC of the installation of the Magisk App is ${TEMPRC}"
    
    adb ${ADB_OPTIONS} shell dumpsys package ${MAGISK_PACKAGE} | grep android.permission.POST_NOTIFICATIONS:   >/dev/null
    if [ $? -eq 0 ] ; then
      echo  "Will now grant the permission \"android.permission.POST_NOTIFICATIONS\" for the Magisk App ..."
      set -x
      adb ${ADB_OPTIONS} shell pm grant ${MAGISK_PACKAGE}  android.permission.POST_NOTIFICATIONS 
      set +x

      echo "The status of the permission \"android.permission.POST_NOTIFICATIONS\" for the Magisk App is now:"
      adb ${ADB_OPTIONS} shell dumpsys package ${MAGISK_PACKAGE} | grep android.permission.POST_NOTIFICATIONS:     
    else
      echo "The current running Android version does not know the permission \"android.permission.POST_NOTIFICATIONS\" "
    fi

    echo "Waiting now 10 seconds ..."
    sleep 10
  fi
   
  echo "Now rebooting the phone into the bootloader  ..."
  
  adb ${ADB_OPTIONS} reboot bootloader

  wait_for_phone_to_be_in_the_bootloader || die 13 "Booting the phone into the bootloader failed - Giving up..."

  echo "Booting the phone from the TWRP image \"${TWRP_IMAGE}\" now  ..."

  ${SUDO_PREFIX} fastboot ${FASTBOOT_OPTIONS} boot "${TWRP_IMAGE}"

  wait_for_phone_with_a_working_adb_connection || die 15 "Booting the phone from the TWRP image failed - Giving up..."
  
#  echo "*** "
#  echo "The files in the directory \"${DEFAULT_MAGISK_BIN_DIR}\" are now:"
#  adb ${ADB_OPTIONS} shell ls -l ${DEFAULT_MAGISK_BIN_DIR}
#  echo "*** "

  adb ${ADB_OPTIONS} shell rm -rf ${DEFAULT_MAGISK_BIN_DIR}/*
  
  cleanup_temporary_files

#  echo "*** "
#  echo "The files in the directory \"${DEFAULT_MAGISK_BIN_DIR}\" are now:"
#  adb ${ADB_OPTIONS} shell ls -l ${DEFAULT_MAGISK_BIN_DIR}
#  echo "*** "

  return ${THISRC}
}


# ---------------------------------------------------------------------
# main function
#

echo "${SCRIPT_NAME} version - ${SCRIPT_VERSION} - add Magisk to the boot partition of a phone running Android using TWRP"
echo ""

if [ "$1"x = "-h"x ] ; then
  grep "^#h#" $0 | cut -c4-
  die 10

elif [ "$1"x = "-H"x -o "$1"x = "--help"x -o "$1"x = "help"x ] ; then

#
# extract the usage help from the script source
#
  echo
  grep -i "^#H#" $0 | cut -c4-
    
  echo ""
  echo " The default TWRP image to use is \"${DEFAULT_TWRP_IMAGE}\" "
  echo ""
  exit 1
fi

#
# process the parameter
#

while [ $# -ge 1 ] ; do

  case $1 in
    a | slot_a | _a )
      CURRENT_BOOT_SLOT="_a"
      shift
    ;;

    b | slot_b  | _b )
      CURRENT_BOOT_SLOT="_b"
      shift
    ;;

    active | current )
      CURRENT_BOOT_SLOT="active"
      shift
    ;;

    inactive | next )
      CURRENT_BOOT_SLOT="inactive"
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

    cleanup )
      echo "Parameter \"cleanup\" found: Temporary Magisk files and directories in \"${MAGISK_DATA_DIR}\" will be deleted at script end."
      CLEANUP_TEMPORARY_FILES=${__TRUE}
      shift
      ;;

    delete_adb_dir | del_adb | del_adb_dir )
      echo "Parameter \"delete_adb_dir\" found: All files and directories created by this script in the directory  \"/data/adb\" will be deleted at script end."
      CLEANUP_DATA_DIR=${__TRUE}
      CONFIGURE_ADB_DIR_ONLY=${__FALSE}
      shift
      ;;

    adb_only  )
      echo "Parameter \"adb_only\" found: Will only install the directories and files in the directory \"/data/adb\" "
      CONFIGURE_ADB_DIR_ONLY=${__TRUE}
      CLEANUP_DATA_DIR=${__FALSE}
      shift
      ;;
    
    use_apk )
      echo "Parameter \"use_apk\" found: Will use the files from the apk file even if the files in /data/adb/magisk exist"
      USE_APK=${__TRUE}
      shift
      ;; 

    copy_apk )
      echo "Parameter \"copy_apk\" found: Will copy the Magisk apk file to the phone if necessary"
      COPY_APK=${__TRUE}
      shift
      ;;

    magisk_apk_file=* )
      MAGISK_APK_FILE="${1#*=}"
      echo "Parameter \"magisk_apk_file=file\" found : Will use the Magisk apk file \"${MAGISK_APK_FILE}\" "
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

   oldmethod | old_method )
      USE_NEW_METHOD=${__FALSE}
      echo "Parameter \"oldmethod\" found : Will use old method to install Magisk"
      shift
      ;;

   newmethod | new_method )
      USE_NEW_METHOD=${__TRUE}
      COPY_APK=${__TRUE}
      USE_APK=${__TRUE}
      echo "Parameter \"newmethod\" found : Will use old method to install Magisk; the parameter \"copy_apk\" and \"use_apk\" are now also enabled"
      shift
      ;;

    * )
      if [ "${TWRP_IMAGE}"x != ""x ] ; then
        die 6 "ERROR: Unknown parameter found: \"$1\" "
      fi
      TWRP_IMAGE="$1"
      shift
  esac
done

# [ $# -ne 0 ] && die 6 "Unknown parammeter found: \"$*\" "



# ---------------------------------------------------------------------

if [ "${TWRP_IMAGE}"x = ""x ] ; then
  TWRP_IMAGE="${DEFAULT_TWRP_IMAGE}"
  echo "Using the TWRP image hardcoded in the script: \"${TWRP_IMAGE}\" "
else
  echo "Using the TWRP image found in the parameter: \"${TWRP_IMAGE}\" "
fi
  
[ ! -r "${TWRP_IMAGE}" ] && die 5 "TWRP image \"${TWRP_IMAGE}\" not found"


ERRORS_FOUND=${__FALSE}

echo "Checking the script prerequisites ..."

if [ -r "${SCRIPT_PATH}/${TWRP_REBOOT_HELPER_SCRIPT}" ] ; then
  CUR_TWRP_REBOOT_HELPER_SCRIPT="${SCRIPT_PATH}/${TWRP_REBOOT_HELPER_SCRIPT}"
else
  CUR_TWRP_REBOOT_HELPER_SCRIPT="$( which "${TWRP_REBOOT_HELPER_SCRIPT}" )"
fi

if [ "${CUR_TWRP_REBOOT_HELPER_SCRIPT}"x = ""x ] ; then
  echo "ERROR: TWRP helper script \"${TWRP_REBOOT_HELPER_SCRIPT}\" not found"
  ERRORS_FOUND=${__TRUE}
else
  echo "Using the TWRP helper script \"${CUR_TWRP_REBOOT_HELPER_SCRIPT}\" "
fi


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
   echo "OK, write access for the current working directory is okay"
    \rm ${PWD}/xxx.$$ 2>/dev/null
  else
    echo "ERROR: Can not write to the current working directory \"${PWD}\" "
    ERRORS_FOUND=${__TRUE}
  fi
fi

if [ ${COPY_APK} = ${__TRUE} ] ; then
  if [ "${MAGISK_APK_FILE}"x = ""x ] ; then
    echo "ERROR: The parameter \"copy_apk\" was used but there is on apk file defind"
    ERRORS_FOUND=${__TRUE}
  elif [ ! -r "${MAGISK_APK_FILE}" ] ; then
    echo "ERROR: The parameter \"copy_apk\" was used but the file \"${MAGISK_APK_FILE}\" does not exist"
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


if [ ${ERRORS_FOUND} = ${__TRUE} ] ; then
  die 7 "One or more errors found in the prerequisite checks"
fi

# ---------------------------------------------------------------------

echo "Reading the helper script \"${TWRP_REBOOT_HELPER_SCRIPT}\" ..."

. ${CUR_TWRP_REBOOT_HELPER_SCRIPT}

# check if the Magisk apk file used is for version v26.0 or newer
#
if [ "${MAGISK_APK_FILE}"x != ""x ] ; then
  unzip -c "${MAGISK_APK_FILE}"  assets/boot_patch.sh 2>/dev/null | grep stub.apk  >/dev/null
  if [ $? -eq 0 ] ; then
    echo "The Magisk version used is v26.0 or newer"
    DEFAULT_USE_NEW_METHOD=${__TRUE}
  else
    echo "The Magisk version used is v25.x or older"
    DEFAULT_USE_NEW_METHOD=${__FALSE}
  fi
else
  DEFAULT_USE_NEW_METHOD=${__FALSE}
fi

if [ "${USE_NEW_METHOD}"x = ""x ] ; then
  USE_NEW_METHOD=${DEFAULT_USE_NEW_METHOD}  
else
  if [ "${USE_NEW_METHOD}" = "${__TRUE}" ] ; then
    echo "Using the installation method for Magisk v26.0 or newer is requested via parameter"
  else    
    echo "Using the installation method for Magisk v25.0 or older is requested via parameter"
  fi
fi

if [ ${USE_NEW_METHOD} = ${__TRUE} ] ; then
  MAGISK_INST_DIR="/data/local/tmp/MagiskInst"
  FALLBACK_DOWNLOAD_DIR_ON_PHONE="/data/local/tmp/" 
fi

echo "Using the temporary directory \"${MAGISK_INST_DIR}\" on the phone"
 
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
    SERIAL_NUMBER="$( echo "${ADB_DEVICES}" | awk '{ print $1}' )" 
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
  echo "The attached phone is already booted into the fastboot mode"
else
  echo "No attached phone in fastboot mode found"

  echo "Checking for an attached phone with working access via adb (USB) ..."

  adb ${ADB_OPTIONS} shell uname -a || die 11 "Can not access the phone - neither via fastboot nor via adb"

  echo "... found a phone connected via USB with working adb access"

#
# check if the phone is already booted from the TWRP image
#  
  TWRP_STATUS="$( adb ${ADB_OPTIONS} shell getprop  ro.twrp.boot )"

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
    TWRP_BOOT_IMAGE="$( adb ${ADB_OPTIONS} shell getprop  ro.product.bootimage.name )"
    TWRP_BOOT_IMAGE_VERSION="$( adb ${ADB_OPTIONS} shell getprop  ro.twrp.version )"
  
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
    
    INSTALLED_MAGISK_VERSION="$(  adb ${ADB_OPTIONS} shell pm  list  packages --show-versioncode ${MAGISK_PACKAGE}  2>/dev/null  | cut -f2- -d":" | tr ":" " " )"
    
    echo "The installed OS is based on Android ${OS_VERSION} (${OS_SOFTWARE_VERSION}); the description for the distribution is \"${OS_DESC}\" "
    if [ "${INSTALLED_MAGISK_VERSION}"x = ""x ] ; then
      echo "WARNING: Can not detect the version of the installed Magisk"
    else
      echo "The installed version of Magisk is ${INSTALLED_MAGISK_VERSION} "
    fi

    echo "Booting the phone into the fastboot mode now ..."

    adb ${ADB_OPTIONS} reboot bootloader

    wait_for_phone_to_be_in_the_bootloader || die 13 "Booting the phone into the bootloader failed - Giving up..."
    
  fi
fi

if [ "${TWRP_STATUS}"x != "1"x ] ; then
 
  echo "Booting the phone from the TWRP image \"${TWRP_IMAGE}\" now  ..."

  ${SUDO_PREFIX} fastboot ${FASTBOOT_OPTIONS} boot "${TWRP_IMAGE}"

  wait_for_phone_with_a_working_adb_connection || die 15 "Booting the phone from the TWRP image failed - Giving up..."
  
  wait_until_data_is_mounted

fi

echo "Retrieving the current boot slot from the phone ..."

ACTIVE_BOOT_SLOT="$( adb ${ADB_OPTIONS} shell getprop ro.boot.slot_suffix )"

if [ "${ACTIVE_BOOT_SLOT}"x = ""x ] ; then
  echo "No slot property found - seems the phone does not support the A/B partition scheme"
  CURRENT_BOOT_SLOT=""
else
  echo "The current boot slot is \"${ACTIVE_BOOT_SLOT}\" "  
fi

if [ "${CURRENT_BOOT_SLOT}"x = "_a"x -o "${CURRENT_BOOT_SLOT}"x = "_b"x ] ; then
  echo "Using the boot partition for the slot found in the parameter: ${CURRENT_BOOT_SLOT}"
else  

  if [ "${ACTIVE_BOOT_SLOT}"x != ""x ] ; then
    if [ "${CURRENT_BOOT_SLOT}"x = "active"x ] ; then
      CURRENT_BOOT_SLOT="${ACTIVE_BOOT_SLOT}"
    elif [ "${CURRENT_BOOT_SLOT}"x = "inactive"x ] ; then
      if [ "${ACTIVE_BOOT_SLOT}"x = "_a"x ] ; then
        CURRENT_BOOT_SLOT="_b"
      else
        CURRENT_BOOT_SLOT="_a"
      fi
    fi
  fi

  if [ "${CURRENT_BOOT_SLOT}"x != ""x ] ; then
    echo "The boot slot to patch is \"${CURRENT_BOOT_SLOT}\" "  
  fi

fi

CURRENT_BOOT_PARTITION_NAME="boot${CURRENT_BOOT_SLOT}"
CURRENT_BOOT_PARTITION="/dev/block/by-name/${CURRENT_BOOT_PARTITION_NAME}"


echo "The boot partition to patch is \"${CURRENT_BOOT_PARTITION_NAME}\" "

if [ ${COPY_APK} = ${__TRUE} ] ; then
  DIR_FOR_THE_APKFILE="/data"
  adb ${ADB_OPTIONS} shell test -d /data/downlaod && DIR_FOR_THE_APKFILE="/sdcard/download"

  echo "Copying the Magisk apk file \"${MAGISK_APK_FILE}\" to the phone into the directory \"${DIR_FOR_THE_APKFILE}\" ..."

  adb ${ADB_OPTIONS} push "${MAGISK_APK_FILE}" "${DIR_FOR_THE_APKFILE}" 
  TEMPRC=$?
  if [ ${TEMPRC} -ne 0 ] ; then
#
#  the adb connections get offline sometimes for unknown reason
#
    echo  "Copying the Magisk apk file failed; checking the connection and trying it again now ..."

    online_adb_connection
    if [ $? -eq ${__TRUE} ] ; then
#
# try again after onlining the adb connection
#
      adb ${ADB_OPTIONS} push "${MAGISK_APK_FILE}" "${DIR_FOR_THE_APKFILE}" ||  die 22 "Error copying the Magisk apk file \"${MAGISK_APK_FILE}\" to the phone into the directory \"${DIR_FOR_THE_APKFILE}\" "
      TEMPRC=$?
    fi
  fi
  
  if [ ${TEMPRC} -ne 0 ] ; then
    die 22 "Error copying the Magisk apk file \"${MAGISK_APK_FILE}\" to the phone into the directory \"${DIR_FOR_THE_APKFILE}\" "
  fi
  
  CUR_MAGISK_APKFILE_ON_THE_PHONE="${DIR_FOR_THE_APKFILE}/${MAGISK_APK_FILE##*/}"

fi


# check if the Magisk directories in /data/adb already exist
#
adb ${ADB_OPTIONS} shell ls -l "${MAGISK_BOOT_PATCH_SCRIPT}" 2>/dev/null >/dev/null
if [ $? -ne 0 -o ${USE_APK} = ${__TRUE} ] ; then

  create_temporary_magisk_dir "${MAGISK_INST_DIR}"  "${CUR_MAGISK_APKFILE_ON_THE_PHONE}" || die 28 "Error creating the directories and files on the phone" 
  echo ""


  MAGISK_BIN_DIR="${MAGISK_INST_DIR}/bin"

  NEW_BOOT_IMG="${MAGISK_BIN_DIR}/new-boot.img"

  NEW_BOOT_IMG_BACKUP="${NEW_BOOT_IMG}.$$"  

  MAGISK_BOOT_PATCH_SCRIPT="${MAGISK_BIN_DIR}/${MAGISK_BOOT_PATCH_SCRIPT_NAME}"

  DIRS_IN_DATA_ADB_CREATED=${__TRUE}  
fi


if [ ${CONFIGURE_ADB_DIR_ONLY} = ${__TRUE} ] ; then
#
# only the the Magisk directories and files /data/adb 
#
  echo "
  set -e
  
  if [ ! -d /data/adb ] ; then
    mkdir -p /data/adb
    chmod 0700 /data/adb
    chcon -v 'u:object_r:adb_data_file:s0' /data/adb
  fi
  
  if [ ! -d /data/adb/magisk ] ; then
    mv ${MAGISK_INST_DIR}/bin /data/adb/magisk
    chmod 755 /data/adb/magisk

# ???   chcon -R -v 'u:object_r:magisk_file:s0' /data/adb/magisk
    chcon -R -v 'u:object_r:system_file:s0' /data/adb/magisk

  elif [ ! -r /data/adb/magisk/magsik64 ] ; then
    mv ${MAGISK_INST_DIR}/bin/* /data/adb/magisk/
    chmod -R 755 /data/adb/magisk

# ???    chcon -R -v 'u:object_r:magisk_file:s0' /data/adb/magisk
    chcon -R -v 'u:object_r:system_file:s0' /data/adb/magisk

  fi


  if [ ! -d /data/adb/modules ] ; then
    mkdir -p /data/adb/modules
    chmod 755 /data/adb/modules
    chcon -v 'u:object_r:system_file:s0' /data/adb/modules
  fi
  
  if [ ! -d /data/adb/post-fs-data.d ] ; then
    mkdir -p  /data/adb/post-fs-data.d
    chmod 755 /data/adb/post-fs-data.d
    chcon -v 'u:object_r:adb_data_file:s0' /data/adb/post-fs-data.d
  fi

  if [ ! -d /data/adb/service.d ] ; then
    mkdir -p /data/adb/service.d
    chmod 755 /data/adb/service.d
    chcon -v 'u:object_r:adb_data_file:s0' /data/adb/service.d
  fi
  

  if [ ! -d /data/adb/magisk/chromeos ] ; then
    mkdir -p /data/adb/magisk/chromeos
    chmod 755 /data/adb/magisk/chromeos
    chcon -v 'u:object_r:system_file:s0' /data/adb/magisk/chromeos
  fi
  
" | adb ${ADB_OPTIONS} shell
  [ $? -ne 0 ] && die 16 "Error ccreating the directory structure for Magisk in \"/data/adb\" "
  
  
  adb ${ADB_OPTIONS} shell rm -rf "${MAGISK_INST_DIR}"

else
  echo "Checking if the Magisk patch script \"${MAGISK_BOOT_PATCH_SCRIPT_NAME}\" exists on the phone ...."

  adb ${ADB_OPTIONS} shell ls -l "${MAGISK_BOOT_PATCH_SCRIPT}" || die 17 "Patch boot script not found on the attached phone"  

  echo "Checking if the download directory \"${DOWNLOAD_DIR_ON_PHONE}\" exists on the phone ...."

  adb ${ADB_OPTIONS} shell ls -d "${DOWNLOAD_DIR_ON_PHONE}" 
  if [ $? -ne 0 ] ; then
    echo "WARNING: Directory \"${DOWNLOAD_DIR_ON_PHONE}\" not found on the phone ."
    echo "Checking if the download directory \"${FALLBACK_DOWNLOAD_DIR_ON_PHONE}\" exists on the phone ...."
    adb ${ADB_OPTIONS} shell ls -d "${FALLBACK_DOWNLOAD_DIR_ON_PHONE}" || die 21 "Directory \"${FALLBACK_DOWNLOAD_DIR_ON_PHONE}\" not found on the attached phone"
    DOWNLOAD_DIR_ON_PHONE="${FALLBACK_DOWNLOAD_DIR_ON_PHONE}"
  fi

  CURRENT_BOOT_IMAGE_FILE="${DOWNLOAD_DIR_ON_PHONE}/${CURRENT_BOOT_PARTITION_NAME}.$$.img"
  CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME="patched_${CURRENT_BOOT_PARTITION_NAME}.$$.img"
  CURRENT_PATCHED_BOOT_IMAGE_FILE="${DOWNLOAD_DIR_ON_PHONE}/${CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME}"

  echo "Creating the boot image file \"${CURRENT_BOOT_IMAGE_FILE}\" from the partition \"${CURRENT_BOOT_PARTITION}\" ..."

  adb ${ADB_OPTIONS} shell dd if="${CURRENT_BOOT_PARTITION}" of="${CURRENT_BOOT_IMAGE_FILE}" || die 23 "Error creating the image file \"${CURRENT_BOOT_IMAGE_FILE}\" "

  echo ""
  echo "Checking the result ..."
  sleep 5
  adb ${ADB_OPTIONS} shell ls -l "${CURRENT_BOOT_IMAGE_FILE}" || die 25 "Something went wrong creating the image file \"${CURRENT_BOOT_IMAGE_FILE}\" "

  BOOT_PARTITION_CHKSUM="$( adb ${ADB_OPTIONS} shell cksum "${CURRENT_BOOT_PARTITION}" | cut -f1 -d " " )"
  BOOT_PARTITION_IMG_CHKSUM="$( adb ${ADB_OPTIONS} shell cksum "${CURRENT_BOOT_IMAGE_FILE}" | cut -f1 -d " " )"
  
# adb ${ADB_OPTIONS} shell cksum "${CURRENT_BOOT_PARTITION}" "${CURRENT_BOOT_IMAGE_FILE}"

  echo "The check sums are:"
  echo "The check sum of the boot partition \"${CURRENT_BOOT_PARTITION}\" on the phone is \"${BOOT_PARTITION_CHKSUM}\" "
  echo "The check sum of th boot image file on the phone is \"${CURRENT_BOOT_IMAGE_FILE}\" is \"${BOOT_PARTITION_IMG_CHKSUM}\"   "
   
  if [ "${BOOT_PARTITION_CHKSUM}"x != "${BOOT_PARTITION_IMG_CHKSUM}"x ] ; then
    die 248 "Error creating the image file \"${CURRENT_BOOT_IMAGE_FILE}\" from the boot partition \"${CURRENT_BOOT_PARTITION}\" on the phone (the check sums do not match)"
  fi
 
#
# rename an existing patched image created by Magisk
#
  adb ${ADB_OPTIONS} shell ls  "${NEW_BOOT_IMG}" 2>/dev/null >/dev/null 
  if [ $? -eq 0 ] ; then
    echo "Renaming the file \"${NEW_BOOT_IMG}\" to \"${NEW_BOOT_IMG_BACKUP}\" ..."
    adb ${ADB_OPTIONS} shell mv "${NEW_BOOT_IMG}" "${NEW_BOOT_IMG_BACKUP}" || die 27 "Error renaming the file \"${NEW_BOOT_IMG}\" to \"${NEW_BOOT_IMG_BACKUP}\" "
  fi


# -----------------

  if [ ${DEFAULT_USE_NEW_METHOD} = ${__TRUE} ] ; then
    install_magisk_using_the_new_method
    TEMPRC=$?
  else
    install_magisk_using_the_old_method
    TEMPRC=$?
  fi

  if [ ${TEMPRC} != ${__TRUE} ] ; then
    die 247 "Something went wrong patching the boot partition"
  fi

  if [ ${USE_FASTBOOT_TO_FLASH_THE_BOOT_PARTITION} = ${__FALSE} ] ; then

# Note: The dd command does not work without this little pause (don't ask me why ...)
    wait_some_seconds 10

    echo "Patching the partition \"${CURRENT_BOOT_PARTITION}\" from the patched boot image file \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" via dd ..."

    CUR_OUTPUT="$( exec 2>&1 ; ${PREFIX}  adb ${ADB_OPTIONS} shell dd  if="${CURRENT_PATCHED_BOOT_IMAGE_FILE}" of="${CURRENT_BOOT_PARTITION}" || die 35 "Error patching the patched image file \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" to \"${CURRENT_BOOT_PARTITION}\" " )"
    echo "${CUR_OUTPUT}"

    if [ "${CUR_OUTPUT}"x = ""x ] ; then
      echo "WARNING: It looks like patching the \"${CURRENT_BOOT_PARTITION}\" via dd failed"
    fi
  
    echo "Checking the result ...."
  
    DEV_CHKSUM="$( adb ${ADB_OPTIONS} shell cksum "${CURRENT_BOOT_PARTITION}" | cut -f1 -d " " )"
    ORIGINAL_IMG_CHKSUM="$( adb ${ADB_OPTIONS} shell cksum "${CURRENT_BOOT_IMAGE_FILE}" | cut -f1 -d " " )"
    PATCHED_IMG_CHKSUM="$( adb ${ADB_OPTIONS} shell cksum "${CURRENT_PATCHED_BOOT_IMAGE_FILE}" | cut -f1 -d " " )"
  
    echo ""
    echo "The check sums for the images and devices on the phone are:"
    echo ""
    adb ${ADB_OPTIONS} shell cksum "${CURRENT_BOOT_IMAGE_FILE}" "${CURRENT_PATCHED_BOOT_IMAGE_FILE}" "${CURRENT_BOOT_PARTITION}"
    echo ""

    if [ "${DEV_CHKSUM}"x = ""x -o "${PATCHED_IMG_CHKSUM}"x = ""x -o "${ORIGINAL_IMG_CHKSUM}"x = ""x ] ; then
      echo "ERROR : Something went terrible wrong -- please connect via \"adb shell\" and check and correct the error"
      die 249
    elif [ "${DEV_CHKSUM}"x = "${PATCHED_IMG_CHKSUM}"x ] ; then
      echo "OK, patching the boot partition \"${CURRENT_BOOT_PARTITION}\" was successfull"
    
      cleanup_temporary_files

    elif [ "${DEV_CHKSUM}"x = "${ORIGINAL_IMG_CHKSUM}"x ] ; then
      echo "ERROR: The patching was NOT successfull -- the boot partition \"${CURRENT_BOOT_PARTITION}\" did not change"
    else
      echo "ERROR: The patching of the boot partition \"${CURRENT_BOOT_PARTITION}\" failed !"
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
  
    echo "The check sum of the patched boot image \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" on the phone is \"${PATCHED_IMG_CHKSUM}\" "
    echo "The check sum of the downloaded patched boot image \"${CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME}\" is                    \"${LOCAL_PATCHED_IMG_CHKSUM}\"   "
   
    if [ "${PATCHED_IMG_CHKSUM}"x != "${LOCAL_PATCHED_IMG_CHKSUM}"x ] ; then
      echo "ERROR downloading the file \"${CURRENT_PATCHED_BOOT_IMAGE_FILE}\" from the phone (the check sums do not match)"
      die 250
    fi

    cleanup_temporary_files

    echo "Booting the phone into the fastboot mode now ..."

    adb ${ADB_OPTIONS} reboot bootloader

    wait_for_phone_to_be_in_the_bootloader || die 39 "Booting the phone into the bootloader failed - Giving up..."

    echo "Flashing the partition \"${CURRENT_BOOT_PARTITION_NAME}\" with the patched image \"${CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME}\" ..."
  
    ${PREFIX}  ${SUDO_PREFIX} fastboot ${FASTBOOT_OPTIONS} flash "${CURRENT_BOOT_PARTITION_NAME}" "${CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME}"
    if [ $? -ne 0 ] ; then
      die 41 "Error flashing \"${CURRENT_PATCHED_BOOT_IMAGE_FILE_NAME}\" to the partition \"${CURRENT_BOOT_PARTITION_NAME}\" "

    fi
      
    REBOOT_COMMAND="fastboot"
  
  fi

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
      ${PREFIX} adb ${ADB_OPTIONS} reboot
    fi
  fi

die ${THISRC}


