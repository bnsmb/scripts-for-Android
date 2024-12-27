#h#
#h# enable_adb_in_recovery_ramdisk.sh - enable the automatic start of the adbd in the ramdisk for a recovery boot
#h#
#h# Usage:  enable_adb_in_recovery_ramdisk.sh
#h#
#
# History
#  25.06.2024 v1.0.0 /bs
#   initial release
#
#  26.06.2024 v1.0.1 /bs
#   added error checking code 
#   the script now uses "better" names for the temporary files
#   enhanced the check after unpacking the cpio archive
#

#h# Environment variables used if set
#h#
#h#  MAGISKBOOT - magiskboot binary; default /data/adb/magisk/magiskboot
#h#
#h#  VENDOR_BOOT_PARTITION - partition with the ramdisk for the recovery, default /dev/block/by-name/vendor_boot_<cur_slot>
#h#

if [ "$1"x = "-h"x -o "$1"x = "--help"x ] ; then
  grep "^#h#" $0 | cut -c4-
  exit 5
elif [ $# -ne 0 ] ; then
  echo "ERROR: unknown parameter found"
  exit 7  
fi

# define some constants
#
typeset __TRUE=0
typeset __FALSE=1

# set the path to magiskboot in the variable MAGISKBOOT according to your environment if it's neither
# in /data/adb/magisk nor in /data/local/tmp
#
[ "${MAGISKBOOT}"x = ""x -a -x /data/adb/magisk/magiskboot ] && MAGISKBOOT="/data/adb/magisk/magiskboot"
[ "${MAGISKBOOT}"x = ""x -a -x /data/local/tmp/magiskboot ] && MAGISKBOOT="/data/local/tmp/magiskboot"


# set the variable KEEP_WORK_DIR to 0 to disable the cleanup at script end
#

# KEEP_WORK_DIR=${__TRUE}

# ---------------------------------------------------------------------

function die {
  typeset THISRC=$1
  
  [ $# -ne 0 ] && shift

  typeset THISMSG="$*"
  
  [ ${THISRC} -gt 1 ] && THISMSG="ERROR: ${THISMSG}"
  echo "${THISMSG}"

  if [ "${WORKDIR}"x != ""x ] ; then
    if [ -d "${WORKDIR}" ] ; then
      if [ ${THISRC} -le 1 -a "${KEEP_WORK_DIR}x" != "${__TRUE}"x ] ; then
        echo "Removing the temporary work directory \"${WORKDIR}\" ..."
        \rm -rf "${WORKDIR}"
      else
        echo "Working directory \"${WORKDIR}\" not deleted"
      fi
    else
      echo "The working directory \"${WORKDIR}\" does not exist"
    fi
  fi

  echo "RC=${THISRC}"
  exit ${THISRC}  
}

# ---------------------------------------------------------------------

echo "Initializing the variables ..."

GETPROP="$( which getprop 2>/dev/null )"
if [ "${GETPROP}"x = ""x ] ; then
  die 3 "This script must run in a shell on the phone"
fi

# get the current boot slot
#
CUR_SLOT="$( ${GETPROP} ro.boot.slot_suffix )"        

DEFAULT_VENDOR_BOOT_PARTITION="/dev/block/by-name/vendor_boot${CUR_SLOT}"

CUR_VENDOR_BOOT_PARTITION="${VENDOR_BOOT_PARTITION:=${DEFAULT_VENDOR_BOOT_PARTITION}}"

BOOT_PARTITION_FILE_NAME="${CUR_VENDOR_BOOT_PARTITION##*/}.img"
NEW_BOOT_PARTITION_FILE_NAME="${CUR_VENDOR_BOOT_PARTITION##*/}.new.img"

WORKDIR=""
BASE_WORKDIR=""

if [ "${BASE_WORKDIR}"x = ""x ] ; then
  if [ -d "/data/local/tmp" ] ; then
    BASE_WORKDIR="/data/local/tmp" 
  fi
fi

if [ "${BASE_WORKDIR}"x = ""x ] ; then
  if [ -d "/tmp" ] ; then
    BASE_WORKDIR="/tmp/workdir.$$" 
  fi
fi

CUR_USER="$( id -un )"

if [ "${CUR_USER}"x != "root"x ] ; then
  PREFIX="su - -c "
else
  PREFIX=""
fi

# ---------------------------------------------------------------------

echo "Enabling adb in the ramdisk on the partition \"${CUR_VENDOR_BOOT_PARTITION}\" ..."

# ---------------------------------------------------------------------

echo "Checking the pre-requisites ..."

TESTVAR="$( ${PREFIX} id -un )"
[ "${TESTVAR}"x != "root"x ] && die 10 "No root access"

[ "${BASE_WORKDIR}"x = ""x ] && die 12 "Can not find a working directory"

if [ "${MAGISKBOOT}"x = ""x ] ; then
  die 13 "The binary \"magiskboot\" does not exist or is not executable"
else  
  ${PREFIX} test -x "${MAGISKBOOT}" || die 15 "The binary \"${MAGISKBOOT}\" does not exist or is not executable"
fi

echo "Using the magiskboot executable \"${MAGISKBOOT}\" "

${PREFIX} test -b "${CUR_VENDOR_BOOT_PARTITION}" || die 17 "The partition \"${CUR_VENDOR_BOOT_PARTITION}\" does not exist"

WORKDIR="${BASE_WORKDIR}/vendor_boot${CUR_SLOT}.$$"

echo "Using the working directory \"${WORKDIR}\" ..."

# create the working directory
#
mkdir -p "${WORKDIR}"  && cd "${WORKDIR}"  || \
  die 25 "Can not create the temporary working directory \"${WORKDIR}\""

# ---------------------------------------------------------------------

echo "Copying the partition \"${CUR_VENDOR_BOOT_PARTITION}\" to the file \"${WORKDIR}/${BOOT_PARTITION_FILE_NAME}\" ..."

# extract and unpack the partition vendor_boot
#
${PREFIX} dd if="${CUR_VENDOR_BOOT_PARTITION}" of="${WORKDIR}/${BOOT_PARTITION_FILE_NAME}" || \
  die 30 "Can not copy the partition \"${CUR_VENDOR_BOOT_PARTITION}\" to the file \"${WORKDIR}/${BOOT_PARTITION_FILE_NAME}\""

mkdir image && cd image || \
  die 35 "Can not create the temporary directory \"${PWD}/image\" "

echo "Unpacking the image file \"${WORKDIR}/${BOOT_PARTITION_FILE_NAME}\" ..."

${PREFIX} ${MAGISKBOOT} unpack -h "${WORKDIR}/${BOOT_PARTITION_FILE_NAME}" || \
  die 37 "Error unpacking the file \"${WORKDIR}/${BOOT_PARTITION_FILE_NAME}\" "

echo "Unpacking the ramdisk from the image file \"${WORKDIR}/${BOOT_PARTITION_FILE_NAME}\" ..."

# unpack the ramdisk from the vendor_boot partition
#
mkdir ramdisk && cd ramdisk || \
  die 40 "Can not create the temporary directory \"${PWD}/image\" "


RAMDISK_FILE_TYPE="$( file ../ramdisk.cpio | cut -f2- -d " "  )"
if [[ "${RAMDISK_FILE_TYPE}"x == ASCII\ cpio\ archive* ]] ; then
  CPIO_ARCHIVE_COMPRESSED=${__FALSE}
else  
  CPIO_ARCHIVE_COMPRESSED=${__TRUE}
fi

if [ ${CPIO_ARCHIVE_COMPRESSED} = ${__TRUE} ] ; then
  echo "The file ramdisk.cpio is compressed"

  ${PREFIX} ${MAGISKBOOT} decompress ../ramdisk.cpio - 2>"${WORKDIR}/archive_format" | cpio -idm
  TEMPRC=$? 

  ARCHIVE_FORMAT="$( cat "${WORKDIR}/archive_format" | grep "Detected format" | awk '{ print $NF }' | tr -d "\[\]" )"
  
  echo "The cpio file with the ramdisk contents is compressed with the format \"${ARCHIVE_FORMAT}\" " 

else
  echo "The file ramdisk.cpio is not compressed"

  ${PREFIX} cat ../ramdisk.cpio | cpio -idm 
  TEMPRC=$? 
fi

# ignore warnings from cpio
#
if [ TEMPRC != 0 -a ! -d ./system -a ! -d ./first_stage_ramdisk ] ; then
  die 45 "Can not unpack the file ramdisk.cpio"
fi

# ---------------------------------------------------------------------

echo "Correcting the properties in the file \"prop.default\" if necessary ..."


[ ! -r prop.default ] && \
  die 100 "The file \"prop.default\" does not exist in the ramdisk (the directory with the ramdisk contents is \"${PWD}\" )"

echo "The config entries in the file \"prop.default\" are:"
echo
egrep "^ro.debuggable=|^ro.adb.secure=" prop.default
echo
  
cp prop.default prop.default.backup.$$ || \
  die 47 "Can not create a backup of the file \"prop.default\" in the file \"prop.default.backup.$$\""

RAMDISK_CHANGED=${__FALSE}

grep "^ro.debuggable=1" prop.default >/dev/null 
if [ $? -ne 0 ] ; then
  RAMDISK_CHANGED=${__TRUE}

  grep "^ro.debuggable=" prop.default >/dev/null 
  if [ $? -eq 0 ] ; then
    sed -i -e "s/^ro.debuggable=.*/ro.debuggable=1/g" prop.default
  else
    echo "ro.debuggable=1" >>prop.default
  fi
fi

grep "^ro.adb.secure=0" prop.default >/dev/null 
if [ $? -ne 0 ] ; then
  RAMDISK_CHANGED=${__TRUE}

  grep "^ro.adb.secure=" prop.default >/dev/null 
  if [ $? -eq 0 ] ; then
    sed -i -e "s/^ro.adb.secure=.*/ro.adb.secure=0/g" prop.default
  else
    echo "ro.adb.secure=0" >>prop.default
  fi
fi

if [ ${RAMDISK_CHANGED} = ${__FALSE} ] ; then
  die 1 "adb is already enabled in the ramdisk on the partition \"${CUR_VENDOR_BOOT_PARTITION}\" "
fi

echo "The config entries in the file \"prop.default\" are now:"
echo
egrep "^ro.debuggable=|^ro.adb.secure=" prop.default
echo

# ---------------------------------------------------------------------

echo "Recreating the ramdisk.cpio file ..."

${PREFIX} mv ../ramdisk.cpio ../ramdisk.cpio.org || \
  die 50 "Can not rename \"../ramdisk.cpio\" to \"../ramdisk.cpio.org\" "

# re-create the cpio file with the files for the ramdisk
#
if [ ${CPIO_ARCHIVE_COMPRESSED} = ${__TRUE} ] ; then

  echo "Recreating the file ramdisk.cpio and compressing it using the compression format \"${ARCHIVE_FORMAT}\" " 

  ${PREFIX} find . | cpio -o  | ${MAGISKBOOT} compress=${ARCHIVE_FORMAT} - ../ramdisk.cpio || \
    die 55 "Can not repack the file ramdisk.cpio"
else

  ${PREFIX} find . | cpio -o  >../ramdisk.cpio || \
    die 57 "Can not repack the file ramdisk.cpio"
fi

# ... and recreate the image for the vendor_boot partition

[ ! -r "${NEW_BOOT_PARTITION_FILE_NAME}" ] && \rm -f "${NEW_BOOT_PARTITION_FILE_NAME}"

echo "Repacking the image file for the vendor boot partition in the file \"${NEW_BOOT_PARTITION_FILE_NAME}\" ..."

${PREFIX} cd .. && ${MAGISKBOOT} repack "${WORKDIR}/${BOOT_PARTITION_FILE_NAME}"  "${NEW_BOOT_PARTITION_FILE_NAME}" || \
  die 60 "Can not repack the file \"../vendor_boot${CUR_SLOT}.img\" "

[ ! -r "${NEW_BOOT_PARTITION_FILE_NAME}" ] && die 63 "Something went wrong creating the file \"${NEW_BOOT_PARTITION_FILE_NAME}\" "

${PREFIX} dd if="${NEW_BOOT_PARTITION_FILE_NAME}" of="${CUR_VENDOR_BOOT_PARTITION}" || \
  die 65 "Can not write the image file \"${NEW_BOOT_PARTITION_FILE_NAME}\" to the partition \"/dev/block/by-name/vendor_boot${CUR_SLOT}\" "
  
die 0 "adb successfully enabled in the ramdisk on the partition \"${CUR_VENDOR_BOOT_PARTITION}\" "
