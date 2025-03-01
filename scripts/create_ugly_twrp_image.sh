#h#
#h# create_ugly_twrp_image.sh - "create" an TWRP image for an Android OS version not supporting TWRP (e.g an OS based on Lineage 20.x or newer)
#h#
#h# Usage:  create_ugly_twrp_image.sh [-h] [-v] [boot_partition|boot_partition_image_file] [noprop|-p]
#h#
#H# Parameter:
#H#
#H# boot_partition - boot partition on the phone to be used for the TWRP image (default: use the boot partition of the active slot)
#H#
#H# boot_partition_image_file - image file with a boot partition on the PC to be used for the TWRP image
#H#
#H# noprop - do not copy the properties from the running OS
#H#
#H# This script must run on PC running the Linux OS; a working TWRP image for the phone is required and access via adb to the phone 
#H# is required if the script should copy the boot partition for the TWRP image from the phone or change the properties in the ramdisk
#H# for the new TWRP image
#H# 
#
# History
#  27.06.2024 v1.0.0 /bs
#    initial release
#
#  25.02.2025 v1.0.0 /bs
#   added the variable DEFAULT_TWRP_IMAGE for the default TRWP image that is used if the varialbe TWRP_IMAGE is not defined
#
#H# Environment variables used if set:
#H#
#H#  MAGISKBOOT    - set this variable to the fully qualified namee of the magiskboot executable if it's not available via the PATH variable
#H#                  (default: search the executable in the PATH)
#H#
#H#  ADB           - set this variable to the fully qualified name of the adb executable if it's not available via the PATH variable
#H#                  (default: search the executable in the PATH)
#H#
#H#  ADB_OPTIONS   - additional options for adb (there is no default for this variable)
#H#
#H#  TWRP_IMAGE    - fully qualified name of the TWRP image to be used to create the new TWRP image
#H#
#H#  WORKDIR       - working directory (default: /tmp/create_twrp.$$)
#H#
#H#  NEW_TWRP_FILE - name of the TWRP file to create (default: /tmp/twrp_boot.img)
#H#
#H#  KEEP_WORK_DIR - set this variable to 0 to not delete the temporary directory at script end 
#H#                  (default: only keep the temporary directory if an error occured)
#H#

# define some constants
#
typeset __TRUE=0
typeset __FALSE=1

# set the variable KEEP_WORK_DIR to 0 to disable the cleanup at script end
#

# KEEP_WORK_DIR=${__TRUE}

# process the parameter
#
CUR_PARAMETER=""

COPY_PROPERTIES=${__TRUE}

VERBOSE=${__FALSE}

SHOW_USAGE=${__FALSE}

while [ $# -ne 0 ] ; do

 CUR_PARAMETER="$1"
 shift
 
 case ${CUR_PARAMETER} in 
   -h | --help )
     SHOW_USAGE=${__TRUE}
     ;;

   -p | noprop | no_prop | no_properties )
     COPY_PROPERTIES=${__FALSE}
     ;;

   -H )
     SHOW_USAGE=${__TRUE}
     VERBOSE=${__TRUE}
     ;;
  
   -v | --verbose )
     VERBOSE=${__TRUE}
     ;;

   * )        
     if [ "${BOOT_PARTITION_PARAMETER}"x != ""x ] ; then
       echo "ERROR: unknown parameter found: ${CUR_PARAMETER}"
       exit 10  
     else
       BOOT_PARTITION_PARAMETER="${CUR_PARAMETER}"
     fi
     ;;
  esac
      
done

if [ ${SHOW_USAGE} = ${__TRUE} ] ; then
  grep "^#h#" $0 | cut -c4-
     
  if [ ${VERBOSE} = ${__TRUE} ] ; then
    grep "^#H#" $0 | cut -c4-
  fi

   exit 5
fi

# properties for the TWRP image - the values for these properties are copied to the TWRP image if they exist in running OS
#
PROPERTIES_TO_COPY_TO_THE_TWRP_IMAGE="
ro.lineage.build.version
ro.statix.version
ro.omni.version
ro.lmodroid.build_name
ro.build.description
ro.build.display.id
"

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

echo "Creating an ugly TWRP image ..."
echo ""

echo "Initializing the variables ..."

CUR_BOOT_PARTITION=""
CUR_BOOT_IMAGE_FILE=""

WORKDIR="${WORKDIR:=/tmp/create_twrp.$$}"

NEW_TWRP_FILE="${NEW_TWRP_FILE:=/tmp/twrp_boot.img}"

# set the variables ADB and MAGISKBOOT if these executables are not available via PATH
#
ADB="${ADB:=$( which adb )}"

MAGISKBOOT="${MAGISKBOOT:=$( which magiskboot )}"

DEFAULT_TWRP_IMAGE="/data/backup/ASUS_ZENFONE8/twrp/current_twrp.img"

if [ "${MAGISKBOOT}"x = ""x  ] ; then
  echo "

ERROR: magiskboot executable not found - to fix that do:

Download the Magisk apk file from https://github.com/topjohnwu/Magisk/releases and extract the executable magiskboot using the commands.

unzip -p  Magisk-v27.0.apk  lib/x86/libmagiskboot.so  >magiskboot && chmod 755 magiskboot
"

 die 10 "executable magiskboot not found"
fi

if [ "${TWRP_IMAGE}"x = ""x -a  "${DEFAULT_TWRP_IMAGE}"x != ""x  ] ; then
  [ -r "${DEFAULT_TWRP_IMAGE}" -o -L "${DEFAULT_TWRP_IMAGE}" ] && TWRP_IMAGE="${DEFAULT_TWRP_IMAGE}"
fi

[ "${TWRP_IMAGE}"x = ""x ] && die 15 "No TWRP image to use defined (the environment variable TWRP_IMAGE is empty)"

echo "Using the TWRP image \"${TWRP_IMAGE}\" to create the TWRP image"

if [ "${BOOT_PARTITION_PARAMETER}"x != ""x ] ; then
  if [ -r "${BOOT_PARTITION_PARAMETER}" ] ; then
    CUR_BOOT_IMAGE_FILE="$( readlink -f ${BOOT_PARTITION_PARAMETER} )"

    echo "Using the boot image file \"${CUR_BOOT_IMAGE_FILE}\" to create the TWRP image"

  elif [[ "${BOOT_PARTITION_PARAMETER}" != /dev/* ]] ; then
    CUR_BOOT_PARTITION="/dev/block/by-name/${BOOT_PARTITION_PARAMETER}"
  else
    CUR_BOOT_PARTITION="${BOOT_PARTITION_PARAMETER}"  
  fi

fi

mkdir -p "${WORKDIR}" && cd "${WORKDIR}" || \
  die 20 "Can not create the temporary working directory \"${WORKDIR}\" "

if [ "${CUR_BOOT_IMAGE_FILE}"x = ""x -o  ${COPY_PROPERTIES} = ${__TRUE} ] ; then
 
  [ "${ADB}"x = ""x  ] && die 25 "executable adb not found"

  ${ADB} ${ADB_OPTIONS} shell uname -a >/dev/null || \
    die 30 "Can not access the phone via adb"

fi

if [ "${CUR_BOOT_IMAGE_FILE}"x = ""x ] ; then

  CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell id -un )"
  if [ "${CUR_OUTPUT}"x = "root"x ] ; then
    PREFIX=""
  else
    PREFIX="su - -c "
  fi

  CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell ${PREFIX} id -un )"
  if [ "${CUR_OUTPUT}"x != "root"x ] ; then
    die 35 "root access missing -- the scripts needs adb access as root user to copy the boot  partition from the phone"
  fi

fi

if [ "${CUR_BOOT_PARTITION}"x = ""x -a "${CUR_BOOT_IMAGE_FILE}"x = ""x ] ; then
  
# get the current boot slot
#
  CUR_SLOT="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.boot.slot_suffix )"        

  CUR_BOOT_PARTITION="/dev/block/by-name/boot${CUR_SLOT}"
  
  echo "Using the partition \"${CUR_BOOT_PARTITION}\" on the phone to create the TWRP image"
fi

if [ "${CUR_BOOT_PARTITION}"x != ""x ] ; then
  CUR_BOOT_IMAGE_FILE="${WORKDIR}/boot.img"

  echo "Copying the partition \"${CUR_BOOT_PARTITION}\" to the file \"${CUR_BOOT_IMAGE_FILE}\" ..."   

  ${ADB} ${ADB_OPTIONS} shell ${PREFIX} dd if="${CUR_BOOT_PARTITION}" >"${CUR_BOOT_IMAGE_FILE}" || \
    die 40 "Error copying the partition \"${CUR_BOOT_PARTITION}\" to the file \"${CUR_BOOT_IMAGE_FILE}\"  "
fi

mkdir image && cd image || \
  die 45 "Can not create the temporary directory \"${PWD}/image\" "

IMG_DIR="${PWD}"

echo "Unpacking the image file \"${CUR_BOOT_IMAGE_FILE}/\" ..."

${MAGISKBOOT} unpack -h "${CUR_BOOT_IMAGE_FILE}" || \
  die 50 "Error unpacking the image file \"${CUR_BOOT_IMAGE_FILE}\" "
  
mkdir twrp && cd twrp || \
  die 55 "Can not create the temporary directory \"${PWD}/twrp\" "

TWRP_DIR="${PWD}"

${MAGISKBOOT} unpack -h "${TWRP_IMAGE}" || \
  die 60 "Error unpacking the TWRP image file \"${TWRP_IMAGE}\" "

# read the cmdline for the TWRP image
#
TWRP_CMDLINE="$( grep cmdline header | cut -f2- -d"=" )"

${MAGISKBOOT} cpio ./ramdisk.cpio "extract ./prop.default ./prop.default"
[ ! -r "./prop.default" ] && \
  die 65 "Error extracting the file \"prop.default\" from the TWRP image"
  
  
if [ ${COPY_PROPERTIES} = ${__TRUE} ] ; then
  
  PROPERTIES_CHANGED=${__FALSE}
  
  cp "./prop.default" "./prop.default.$$.org"
  
  for CUR_PROP in ${PROPERTIES_TO_COPY_TO_THE_TWRP_IMAGE} ; do
  
    CUR_OS_VALUE="$( ${ADB} ${ADB_OPTIONS} shell getprop ${CUR_PROP} | cut -f2- -d"=" )"
    
    if [ "${CUR_OS_VALUE}"x = ""x ] ; then  
      echo "The property \"${CUR_PROP}\" is not defined in the running OS"
      continue
    fi
  
    CUR_TWRP_VALUE="$( grep "^${CUR_PROP}=" ./prop.default | cut -f2- -d"="  )"
    if [ "${CUR_TWRP_VALUE}"x = "${CUR_OS_VALUE}"x ] ; then  
      echo "The value for the property \"${CUR_PROP}\" in the TWRP image is already the correct value: \"${CUR_TWRP_VALUE}\" "
    elif [ "${CUR_TWRP_VALUE}"x = ""x ] ; then  
      echo "Adding the property \"${CUR_PROP}=${CUR_OS_VALUE}\" to the TWRP image ..."
      echo "${CUR_PROP}=${CUR_OS_VALUE}" >>./prop.default
      PROPERTIES_CHANGED=${__TRUE}
  
    else 
      echo "Changing the value for the property \"${CUR_PROP}\" to \"${CUR_OS_VALUE}\" in the file \"./prop.default\" for the ramdisk in the new TWRP image ..."
      sed -i -e "s/^${CUR_PROP}=.*/${CUR_PROP}=${CUR_OS_VALUE}/g" ./prop.default
      PROPERTIES_CHANGED=${__TRUE}
    fi
  done
  
  if [ ${PROPERTIES_CHANGED} = ${__TRUE} ] ; then
    echo "Properties changed in the new TWRP image are:"
    echo
    diff "./prop.default" "./prop.default.$$.org"
    echo
    
    echo "Replacing the file \"./prop.default\" in the ramdisk for the new TRWP image ..."
    ${MAGISKBOOT} cpio  "${TWRP_DIR}/ramdisk.cpio" "add 0644 ./prop.default ./prop.default" || \
      die 70 "Error replacing the file \"./prop.default\" in the ramdisk for the new TRWP image"
  
  else
    echo "All properties in the file \"prop.default\" in the ramdisk from the TWRP image are already okay"
  fi
else
  echo "Not changing the properties in the ramdisk for the TWRP image as requested via parameter"  
fi

cd "${IMG_DIR}"

cp "${TWRP_DIR}/ramdisk.cpio" "${IMG_DIR}/ramdisk.cpio"  || \
  die 75 "Error copying the file \"${TWRP_DIR}/ramdisk.cpio\" to \"${IMG_DIR}/ramdisk.cpio\" "

echo "Correcting the cmdline in the header file ..."
  
sed -i -e "s#^cmdline=#cmdline=${TWRP_CMDLINE} #g" header || \
  die 80 "Error correcting the cmdline in the header file"
    
echo "Creating the new TWRP file \"${NEW_TWRP_FILE}\" ..."

${MAGISKBOOT} repack "${CUR_BOOT_IMAGE_FILE}" "${NEW_TWRP_FILE}" || \
  die 85 "Error creating the TWRP file \"${NEW_TWRP_FILE}\" "
    
echo "New file:"
echo 
ls -l "${NEW_TWRP_FILE}"
echo

die 0 "TWRP file \"${NEW_TWRP_FILE}\" successfully created"
  
    
# ---------------------------------------------------------------------

