#!/system/bin/sh
#
# install_twrp_ramdisk.sh - install TWRP into the inactive slot on a phone running the Android OS
#h#
#h# Usage:
#h#
#h# install_twrp_ramdisk.sh [-h|-H]
#h#
#h# This script must run in a shell on the phone (or in an adb shell) after an OS update was installed (either manual or via OTA) but before rebooting the phone.
#h# The script will then install TWRP into the inactive slot.
#h#
#h# The script must be executed by the user "root"; if it's executed by a non-root user it will restart itself using "su - -c <scriptname>"
#h#
#
# History
#   15.05.2023 v1.0.0.0
#     initial release
#
#
#H# Supported environment variables
#H#
#H# WORK_DIR
#H#  directory with the ram disk image and probably the executable magiskboot
#H#
#H# TWRP_RAMDISK_NAME
#H#   name of the file with the ram disk image  (without path)
#H#
#H# Prerequisites
#H#
#H# The script requires these files:
#H#
#H# /data/develop/twrp/ramdisk_with_twrp.cpio  
#H#   - the ram disk with TWRP
#H#
#H# /data/develop/twrp/magiskboot or /data/adb/magisk/magiskboot
#H#   - the magiskboot executable
#H#
#H# To create the ram disk with TWRP do:
#H# 
#H# Boot the phone from the TWRP image (NOT from a TWRP installed in the recovery!), 
#H# open an adb session to the running TWRP on the phone and execute:
#H# 
#H# cd / && sha256sum --status -c ramdisk-files.sha256sum 
#H# if [ $? -eq 0 ] ; then
#H#   cd / && /system/bin/cpio -H newc -o < ramdisk-files.txt > /tmp/ramdisk_with_twrp.cpio && /system/bin/gzip -f /tmp/ramdisk_with_twrp.cpio
#H# fi
#H# 
#H# mkdir -p /data/develop/twrp
#H# cp /tmp/ramdisk_with_twrp.cpio.gz  /data/develop/twrp/ramdisk_with_twrp.cpio
#H# cp /bin/magiskboot /data/develop/twrp/   
#H# 
#H# Note:
#H# 
#H# It is recommended to store the files ramdisk_with_twrp.cpio and magiskboot also on the PC.
#H# The file magiskboot is only required if Magisk is not installed on the phone.
#H# The directory used for the files can be any directory on the phone on a filesystem supporting the execute permission bit.
#H# But do not forget to change the directory used in the script below (variable WORK_DIR) also.
#H# 
# ---------------------------------------------------------------------
# define some constants
#
__FALSE=1
__TRUE=0

# ---------------------------------------------------------------------
# define some variables
#
ERRORS_FOUND=${__FALSE}

WORK_DIR="${WORK_DIR:=/data/develop/twrp}"

TWRP_RAMDISK_NAME="${TWRP_RAMDISK_NAME:=ramdisk_with_twrp.cpio}"

TWRP_RAMDISK="${WORK_DIR}/${TWRP_RAMDISK_NAME}"

# ---------------------------------------------------------------------

function die {
  typeset THISRC=0
  
  if [ $# -ge 1 ] ; then
    THISRC=$1
    shift
  fi
 
  [ $# -ne 0 ] && echo "$*"

  exit ${THISRC}
}

# ---------------------------------------------------------------------
# main function
#

while [ $# -ne 0 ] ; do

  case $1 in 
    -h | --help )
     grep "^#h#" $0 | cut -c4-
     exit 1
     ;;

    -H  )
     egrep "^#h#|^#H#" $0 | cut -c4-
     exit 1
     ;;

    * )
      echo "ERROR: Unknown parameter found: $1"
      exit 5
      ;;
   esac
done

#
# check if we are running in the Android OS on the phone
#
CUR_SERIAL_NO="$( getprop ro.serialno 2>/dev/null )"
if [ $? -ne 0 -o "${CUR_SERIAL_NO}"x = ""x ] ; then
 die 3  "ERROR: This script must be executed in the running Android OS on a phone"
fi

#
# restart as user root if started by a non-root user
#
CUR_ID="$( id -u -n )"
if [ "${CUR_ID}"x != "root"x ] ; then
	echo "The user starting the script is \"${CUR_ID}\" -- restarting the script as user \"root\" ..."
	su - -c $0 $*
	exit $?
fi

if [ !  -r "${TWRP_RAMDISK}" ]  ; then
  echo "ERROR: The TWRP ramdisk \"${TWRP_RAMDISK}\" does not exist"
  ERRORS_FOUND=${__FALSE}
fi

MAGISKBOOT="${WORK_DIR}/magiskboot"
if  [ ! -x "${MAGISKBOOT}" ] ; then
  MAGISK_BOOT="/data/adb/magisk/magiskboot"
  if  [ ! -x "${MAGISKBOOT}" ] ; then
    MAGISK_BOOT=""
    echo "ERROR: Can not find the executable \"magiskboot\" "
    ERRORS_FOUND=${__TRUE}
  fi
fi

echo "Get the current slot ..."
CURRENT_SLOT="$( getprop ro.boot.slot_suffix )"
if [ "${CURRENT_SLOT}"x = ""x ] ; then
  echo "ERROR: This script only works on phones with A/B slot"
  ERRORS_FOUND=${__TRUE}
else
  [ "${CURRENT_SLOT}"x = "_b"x ] && NEXT_SLOT="_a" || NEXT_SLOT="_b"
  echo "Installing TWRP into the boot partition for the slot \"${NEXT_SLOT}\" ..." 
fi

[ ${ERRORS_FOUND} != ${__FALSE} ] && die 5 "One or more errors found"


CUR_BOOT_IMAGE="${WORK_DIR}/boot${NEXT_SLOT}.img"

NEW_BOOT_IMAGE="${WORK_DIR}/boot${NEXT_SLOT}_with_twrp.img"

BOOT_DEVICE="/dev/block/by-name/boot${NEXT_SLOT}"

echo "Copying the partition \"${BOOT_DEVICE}\" into the file \"${CUR_BOOT_IMAGE}\" ..."

dd if="${BOOT_DEVICE}" of="${CUR_BOOT_IMAGE}" || \
  die 10 "ERROR copying the partition \"${BOOT_DEVICE}\" into the file \"${CUR_BOOT_IMAGE}\" " 

cd "${WORK_DIR}" || die 20 "Can not change the working directory to \"${WORK_DIR}\" "

echo "Unpacking the image file \"${CUR_BOOT_IMAGE}\" ..."
${MAGISKBOOT} unpack -h  "${CUR_BOOT_IMAGE}" || die 25 "Error unpacking the image file \"${CUR_BOOT_IMAGE}\"" 

mv ramdisk.cpio ramdiks.cpio.org

cp "${TWRP_RAMDISK_NAME}" ramdisk.cpio

echo "Creating the image file \"${NEW_BOOT_IMAGE}\" ..."
${MAGISKBOOT} repack   "${CUR_BOOT_IMAGE}" "${NEW_BOOT_IMAGE}" || die 25 "Error repacking the image file \"${CUR_BOOT_IMAGE}\" into the file \"${NEW_BOOT_IMAGE}\" " 
[ ! -r "${NEW_BOOT_IMAGE}" ] && die 30 "Something went wrong re-packing the image file: The file \"${NEW_BOOT_IMAGE}\" does not exist"

echo "Writing the image file \"${NEW_BOOT_IMAGE}\" to the partition \"${BOOT_DEVICE}\" ..."

blockdev --setrw "${BOOT_DEVICE}"

dd if="${NEW_BOOT_IMAGE}" of="${BOOT_DEVICE}" 
if [ $? -ne 0 ] ; then
  echo "Error writing the image file \"${NEW_BOOT_IMAGE}\" to the partition \"${BOOT_DEVICE}\" "
  echo  "The backup of the boot partition \"${BOOT_DEVICE}\" is in the file \"${CUR_BOOT_IMAGE}\" "
  die 40 "Error installing TWRP"
fi

die 0 "TWRP successfully installed in the boot partition \"${BOOT_DEVICE}\" "

