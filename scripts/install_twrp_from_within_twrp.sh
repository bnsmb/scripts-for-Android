#!/sbin/sh
#
#H# install_twrp_from_within_twrp.sh - script to install TWRP into a boot partition or into a file
#H#
#H# Usage:
#H#
#H#    install_twrp_from_within_twrp.sh [-f] [boot_image_file] [new_boot_image_file]
#H#
#H#    boot_image can be either an image file from the boot partition or a boot partition block device
#H#    (e.g. /dev/block/by-name/boot_a)
#H#    new_boot_partition_file must be the absolute name of a file.
#H#
#H#    Both parameter are optional
#H#    If the script is called without a parameter TWRP will be installed in the current boot partition.
#H#    If boot_image_file is a block device and new_boot_image_file is missing TWRP will be installed in the block device.
#H#    If the parameter new_boot_image_file is used the script will only write a boot partition image with TWRP into that file.
#H#
#H#    Use the parameter -f to ignore missing or invalid checksums.
#H#
#H#    This script must run in a shell in TWRP
#H#
#H#    Environment variables used by the script if set:
#H#
#H#      BIN_DIR (Current value: \"${BIN_DIR}\")
#H#      TWRP_TMPDIR (Current value: \"${TWRP_TMPDIR}\")
#H#
#H#
#
# History
#   24.10.2022 1.0.0.0 /bs
#     inital release
#
#   05.11.2022 1.0.0.1 /bs
#     fixed some typos
#
#   29.11.2022 1.0.0.2 /bs
#     the script used return instead of exit -- fixed
#
#   06.01.2023 1.1.0.0 /bs
#     use the variable TWRP_TMPDIR instead of TMPDIR; the default directory for temporary files is on the ramdisk mounted on /tmp
#     
#   30.09.2023 v1.2.0.0 /bs
#     the script will now abort if the file /ramdisk-files.txt does not exist even if the parameter "-f" is used
#     the script will now abort if the file /ramdisk-files.sha256sum does not exist even if the parameter "-f" is used
#     the binary sha256sum is now optional if the parameter "-f" is used
#
# Author
#   Bernd.Schemmer (at) gmx.de
#   Homepage: http://bnsmb.de/
#
# Prerequisites
#   a phone with unlocked boot loader
#   a working TWRP recovery image that should be installed in the boot partition of the phone
#   the phone must be booted from the TWRP image - for example via fastboot command:
#       sudo fastboot boot /data/backup/ASUS_ZENFONE8/twrp/twrp-3.7.0_12-0-I006D.img
#   the file /ramdisk-files.txt must exist in the TWRP boot image used
#   the binary /system/bin/magiskboot must exist in tthe TWRP boot image used
#   
# Test Environment
#   Tested on an ASUS Zenfone 8 and with
#     - OmniROM 12 (Android 12) and TWRP 3.7.0.12
#     - OmniROM 12 (Android 12) and TWRP 3.6.1.12
#     - Original Android 12 from ASUS and TWRP 3.7.0.12
#
# Notes:
#
#    The script uses the commands from the TWRP source file https://github.com/TeamWin/android_bootable_recovery/blob/android-12.1/twrpRepacker.cpp
#    The script will not delete the temporary files created in TWRP_TMPDIR - the cleanup of that directory should/must be done manually
#    Be aware that the default for TWRP_TMPDIR is on a ramdisk and the contents of this directory will be lost after the next reboot
#

#
# define some constants
#
__TRUE=0
__FALSE=1

#
# get the parameter
#
if [ "$1"x = "-f"x ] ; then 
  IGNORE_CHECK_SUM_ERROR=${__TRUE} 
  shift
else  
  IGNORE_CHECK_SUM_ERROR=${__FALSE} 
fi

BOOT_IMAGE_FILE="$1"
NEW_BOOT_IMAGE_FILE="$2"

#
# define variables
#

# directory with the executables used by the script
#
BIN_DIR="${BIN_DIR:=/system/bin}"


# executables used by the script
#
# (Note: magiskboot is included in the TWRP boot image)
MAGISKBOOT="${BIN_DIR}/magiskboot"
CPIO="${BIN_DIR}/cpio"
SHA256SUM="${BIN_DIR}/sha256sum"
GETPROP="${BIN_DIR}/getprop"
DD="${BIN_DIR}/dd"

# list of executable used
#
# Note: dd is only necessary if the script should install TWRP in a boot partition
#
EXECUTABLES="${MAGISKBOOT} ${CPIO}  ${GETPROP}"  # ${SHA256SUM}

# data files used by the script
#
SH256SUM_FILE="/ramdisk-files.sha256sum"
RAMDISK_FILES_LIST="/ramdisk-files.txt"

# list of data files used
#
DATA_FILES="${SH256SUM_FILE} ${RAMDISK_FILES_LIST} ${BOOT_IMAGE_FILE}"


# directories for the temporary files
#
# Note: The files in /cache are also available if the phone is booted from the installed OS
#
TWRP_TMPDIR="${TWRP_TMPDIR:=/tmp/install_twrp.$$}"

# directory for the images of the boot partition
#
TMP_IMG_DIR="${TWRP_TMPDIR}/img.$$"

# directory for the files extracted from the boot image
#
TMP_FILE_DIR="${TWRP_TMPDIR}/img_files.$$"


#
# size of the image file to use (if any)
#
SOURCE_BOOT_IMAGE_FILE_SIZE=""

#
# new image with installed TWRP for the boot partition
#
DEFAULT_NEW_BOOT_IMAGE="${NEW_BOOT_IMAGE:=${TMP_IMG_DIR}/new-boot.img}"


# default target partition to use for the TWRP installation (only used
# if the script is called without a parameter)
#
CURRENT_BOOT_SLOT="$( ${GETPROP} ro.boot.slot_suffix 2>/dev/null )"
CURRENT_BOOT_PARTITION="/dev/block/by-name/boot${CURRENT_BOOT_SLOT}"

#
# variables for the script control flow and the script return code
#
THISRC=${__TRUE}
CONT=${__TRUE}

# ----------------------------------------------------------------------
#
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
      echo "ERROR: ${THISMSG} (RC=${THISRC})" >&2
    else
      echo "${THISMSG}"
    fi
  fi

  exit ${THISRC}
}

# ----------------------------------------------------------------------
# main function
#

if [ "$1"x = "-h"x -o "$1"x = "--help"x -o $# -gt 2 ] ; then
#
# extract the usage help from the script source
#
  eval HELPTEXT=\""$( grep "^#H#" $0 | cut -c4- )"\"
  echo "
${HELPTEXT}
"
  exit 1
fi

LogMsg ""
LogMsg "Installing TWRP into a boot image or boot partition via script "
LogMsg ""

#
# check if the script is running in shell in TWRP
#
TWRP_STATUS="$( getprop ro.twrp.boot 2>/dev/null)"


if [ "${TWRP_STATUS}"x != "1"x ] ; then
# no TWRP --check for OrangeFox 
  TWRP_STATUS="$( getprop ro.orangefox.boot 2>/dev/null)"
  if [ "${TWRP_STATUS}"x = "1"x ] ; then
    LogMsg "OK; the running OS is OrangeFox"
  fi
fi
 
 
if [ "${TWRP_STATUS}"x = "1"x ] ; then
  LogMsg "Checking the running OS ..."
  TWRP_BOOT_IMAGE="$( getprop ro.product.bootimage.name 2>/dev/null )"
  TWRP_BOOT_IMAGE_VERSION="$( getprop ro.twrp.version 2>/dev/null )"

  LogMsg "OK, running a shell in TWRP: \"${TWRP_BOOT_IMAGE}\" version \"${TWRP_BOOT_IMAGE_VERSION}\" "
  
  TWRP_BOOT_MODE="$( getprop ro.bootmode 2>/dev/null )"
  if [ "${TWRP_BOOT_MODE}"x = "recovery"x ] ; then
    die 99 "The TWRP was booted from the recovery -- this script will not work in this environment"
  fi
else
  die 100 "This script must run in a shell in TRWP"
fi

#
# check the prerequisites
#
ERRORS_FOUND=${__FALSE}

LogMsg "Checking the prerequisites for installing TWRP ..."

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then

  if [ "${BOOT_IMAGE_FILE}"x != ""x ] ; then
    if [ -b "${BOOT_IMAGE_FILE}" ] ; then
      LogMsg "Using the partition \"${BOOT_IMAGE_FILE}\" as source for the installation of TWRP"
      BOOT_IMAGE_TO_USE="${BOOT_IMAGE_FILE}"
    elif [ -f "${BOOT_IMAGE_FILE}" ] ; then
      LogMsg "Using the file \"${BOOT_IMAGE_FILE}\" as source for the installation of TWRP"
      BOOT_IMAGE_TO_USE="${BOOT_IMAGE_FILE}"
      SOURCE_BOOT_IMAGE_FILE_SIZE="$( ls -l "${BOOT_IMAGE_FILE}" | awk '{ print $5}' )"
    else
      LogError "\"${BOOT_IMAGE_FILE}\" is neither a file nor a device"
      ERRORS_FOUND=${__TRUE}
    fi
  else
    if [ -b  "${CURRENT_BOOT_PARTITION}" ] ; then
      LogMsg "Installing TWRP into the partition \"${CURRENT_BOOT_PARTITION}\" "
      BOOT_IMAGE_TO_USE="${CURRENT_BOOT_PARTITION}"
    else
      LogError "The boot partition \"${CURRENT_BOOT_PARTITION}\" does not exist"
      ERRORS_FOUND=${__TRUE}
    fi
  fi

  if [ "${NEW_BOOT_IMAGE_FILE}"x = ""x ] ; then
    LogMsg "Creating the new boot image with TWRP in the file \"${DEFAULT_NEW_BOOT_IMAGE}\" "

    CUR_NEW_BOOT_IMAGE_TO_USE="${DEFAULT_NEW_BOOT_IMAGE}"
  else

    LogMsg "Creating the boot image with TWRP in the file \"${NEW_BOOT_IMAGE_FILE}\" "
    CUR_NEW_BOOT_IMAGE_TO_USE="${NEW_BOOT_IMAGE_FILE}"

    if [[ ${NEW_BOOT_IMAGE_FILE} != /* && ${NEW_BOOT_IMAGE_FILE} != "" ]] ; then
      LogError "The parameter for the new boot image must be a fully qualified filename - \"${NEW_BOOT_IMAGE_FILE}\" is not a fully qualified filename"
      ERRORS_FOUND=${__TRUE}
    fi

    if [ -b "${NEW_BOOT_IMAGE_FILE}" ] ; then
      LogError "The parameter for the new boot image can not be a device - \"${NEW_BOOT_IMAGE_FILE}\" is a block device"
      ERRORS_FOUND=${__TRUE}
    fi

    if [ -r "${NEW_BOOT_IMAGE_FILE}" ] ; then
      LogError "The new boot image file \"${NEW_BOOT_IMAGE_FILE}\" already exists:"
      LogMsg ""
      ls -l "${NEW_BOOT_IMAGE_FILE}"
      LogMsg ""
      ERRORS_FOUND=${__TRUE}
    fi

  fi

#
# the executable dd is used to rewrite the new image to the boot partition
#
  if [ -b "${BOOT_IMAGE_FILE}" ] ; then
    EXECUTABLES="${EXECUTABLES} ${DD}"
  fi

  LogMsg "Checking if the required executables exist ..."
  for CUR_FILE in ${EXECUTABLES} ; do
    if [ ! -x "${CUR_FILE}" ] ; then
      LogError "The executable \"${CUR_FILE}\" does not exist or is not executable"
      ERRORS_FOUND=${__TRUE}
    else
      LogMsg "OK, the file \"${CUR_FILE}\" exists and is executable"
    fi
  done

  LogMsg "Checking if the required data files exist ..."
  for CUR_FILE in ${DATA_FILES} ; do
    if [ ! -r "${CUR_FILE}" ] ; then
      LogError "The file \"${CUR_FILE}\" does not exist"
      ERRORS_FOUND=${__TRUE}
    else
      LogMsg "OK, the file \"${CUR_FILE}\" exists"
    fi
  done

  if [ ${ERRORS_FOUND} = ${__TRUE} ]; then
    LogError "One or more errors found -- will exit now"
    THISRC=${__FALSE}
  fi

fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  LogMsg "Checking the check sums of the files for the new ramdisk ..."
    
  if [ ! -r "${SH256SUM_FILE}" ] ; then
    LogError "The check sum file \"${SH256SUM_FILE}\" does not exist"
    THISRC=${__FALSE}
  elif [ ! -x "${SHA256SUM}" ] ; then
    Log "The executable \"${SHA256SUM}\" does not exist or is not executable"
  else    
    cd / && "${SHA256SUM}" --status -c "${SH256SUM_FILE}"
    if [ $? -ne 0 ] ; then
      LogError "Error checking the check sums of the files for the new ramdisk"
      LogMsg ""
      "${SHA256SUM}" -c "${SH256SUM_FILE}" | grep -v OK
      LogMsg ""
      if [ ${IGNORE_CHECK_SUM_ERROR} = ${__TRUE} ] ; then
        LogMsg "Ignoring the error because the parameter \"-f\" was used"
      else
        THISRC=${__FALSE}
      fi
    else
      LogMsg "OK, the check sums of the files for the new ramdisk are okay"
    fi
  fi
fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  for CUR_DIR in "${TWRP_TMPDIR}" "${TMP_IMG_DIR}" "${TMP_FILE_DIR}" ; do
    mkdir -p "${CUR_DIR}"
    if [ $? -ne 0 ] ; then
      LogError "Can not create the temporary directory \"${CUR_DIR}\" "
      THISRC=${__FALSE}
    else
      LogMsg "Directory \"${CUR_DIR}\" successfully created"
    fi
  done
fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  LogMsg "The temporary directory to unpack the boot image is \"${TMP_FILE_DIR}\" "
  cd "${TMP_FILE_DIR}"
  if [ $? -ne 0 ] ; then
    LogError "Can not change the working directory to the temporary directory \"${TMP_FILE_DIR}\" "
    THISRC=${__FALSE}
  fi
fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  LogMsg "Unpacking the boot image from \"${BOOT_IMAGE_TO_USE}\" ..."
  "${MAGISKBOOT}" unpack -h -n "${BOOT_IMAGE_TO_USE}"
  if [ $? != 0 ] ; then
    LogError "Error unpacking the boot image from \"${BOOT_IMAGE_TO_USE}\" "
    THISRC=${__FALSE}
  else
    LogMsg "OK, \"${BOOT_IMAGE_TO_USE}\" successfully unpacked to \"${PWD}\" :"

    LogMsg "Creating a backup of the original ramdisk ..."
    mv ramdisk.cpio ramdisk.cpio.org
    if [ $? != 0 ] ; then
      LogError "Error creating a backup of the original ramdisk ..."
      THISRC=${__FALSE}
    fi
    ls -l

  fi
fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  LogMsg "Creating the new ramdisk with TWRP ..."
  cd / && ${CPIO} -H newc -o < "${RAMDISK_FILES_LIST}" > "${TMP_FILE_DIR}/ramdisk.cpio"
  if [ $? != 0 ] ; then
    LogError "Error creating the new ramdisk with TWRP \"${TMP_FILE_DIR}/ramdisk.cpio\" "
    THISRC=${__FALSE}
  else
    LogMsg "New ramdisk with TWRP \"${TMP_FILE_DIR}/ramdisk.cpio\" successfully created."
    LogMsg ""
    ls -l "${TMP_FILE_DIR}/ramdisk.cpio"*
    LogMsg ""
    LogMsg "Repacking the boot image into the file \"${CUR_NEW_BOOT_IMAGE_TO_USE}\" ..."

    CUR_PWD="${PWD}"
    set -x
    cd "${TMP_FILE_DIR}"
    "${MAGISKBOOT}" repack "${BOOT_IMAGE_TO_USE}" "${CUR_NEW_BOOT_IMAGE_TO_USE}"
    TEMPRC=$?
    set +x
    cd "${CUR_PWD}"

    if [ ${TEMPRC} != 0 ] ; then
      LogError "Error repacking the boot image into the file \"${CUR_NEW_BOOT_IMAGE_TO_USE}\" "
      THISRC=${__FALSE}
    elif [ -r "${CUR_NEW_BOOT_IMAGE_TO_USE}" ] ; then

      LogMsg "OK, the new boot image \"${CUR_NEW_BOOT_IMAGE_TO_USE}\" successfully created"
      ls -l "${CUR_NEW_BOOT_IMAGE_TO_USE}"

      if [ "${SOURCE_BOOT_IMAGE_FILE_SIZE}"x != ""x ] ; then
        TARGET_BOOT_IMAGE_FILE_SIZE="$( ls -l "${CUR_NEW_BOOT_IMAGE_TO_USE}" | awk '{ print $5}' )"

        if [  "${SOURCE_BOOT_IMAGE_FILE_SIZE}"x != "${TARGET_BOOT_IMAGE_FILE_SIZE}"x ] ; then
          LogError "The size of the new image file \"${TARGET_BOOT_IMAGE_FILE_SIZE}\" does not match the size of the source image file \"${SOURCE_BOOT_IMAGE_FILE_SIZE}\" "
          THISRC=${__FALSE}
        fi
      fi

    else
      LogError "Something wwnt wrong creating the new boot image file \"${CUR_NEW_BOOT_IMAGE_TO_USE}\" "
      THISRC=${__FALSE}
    fi
  fi
fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  if [ -b "${BOOT_IMAGE_TO_USE}" -a -z ${NEW_BOOT_IMAGE_FILE} ] ; then
    LogMsg "Now rewriting \"${BOOT_IMAGE_TO_USE}\" using \"${CUR_NEW_BOOT_IMAGE_TO_USE}\" ..."
    ${DD} if="${CUR_NEW_BOOT_IMAGE_TO_USE}" of="${BOOT_IMAGE_TO_USE}"
    if [ $? -ne 0 ] ; then
      LogError "Something went wrong rewriting \"${BOOT_IMAGE_TO_USE}\" "
      THISRC=${__FALSE}
    else
      LogMsg "TWRP successfully installed in \"${BOOT_IMAGE_TO_USE}\" "
    fi
  else
    LogMsg "Note: Flashing the new image to the boot partition was not requested"
  fi
fi

if [ ${THISRC} != ${__TRUE} ] ; then
  LogError "Installing TWRP failed"
fi

exit  ${__THISRC}

