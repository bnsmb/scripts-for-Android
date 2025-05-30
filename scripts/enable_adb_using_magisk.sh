# 
# 
# shell script to enable adb via an additional init .rc file configured using Magisk 
#
# Usage:
#
#   enable_adb_using_magisk.sh [boot_slot]
#
# Default for boot_slot is the inactive slot
#
#
# History
#   28.12.2022 1.0.0.0 /bs
#     initial release
#   11.01.2023 1.0.1.0 /bs
#     added debug code to the init script for enabling adb 
#     added code for the init script to check if adb is already enabled (like for example in the LineagOS)
#   14.01.2023 1.0.2.0 /bs
#     the value for the last connection in the created xml file is now the correct value for the epoch time in milli seconds
#   06.02.2024 1.1.0.0 /bs
#     the script now prints some more messages 
#     the script now creates a tar file 
#       /data/recovery/adb_misc_tar_$( date +%Y-%M-%d-%s ).tar 
#     with the new files created in /data/adb/misc
#     the .rc script executed by Magisk now waits up to 60 seconds until the settings executable is available
#     code to create the Magisk .rc script re written
#       
#   01.04.2024 1.1.1.0 /bs
#     the init script now keeps the last 10 versions of the log file /data/recovery/enable_adb_via_service.log
#
#   02.04.2024 1.1.2.0 /bs
#     the script now supports multiple public ssl keys in the input file
#
#   01.05.2024 1.1.3.0 /bs
#     the script enable_adb_via_service.sh created on the phone deletes the 1st log file -- fixed
#     the script enable_adb_via_service.sh created on the phone now restarts the adb on the phone after creating the ssl key config for adbd
#
#   09.05.2024 1.2.0.0 /bs
#     the script now creates an Magisk init script to in /data/adb/service.d to reset the usb port
#
#   10.05.2024 1.2.1.0 /bs
#     rewrote the script for running on the phone to enable adb to at least work without problems for installing the OmniROM
#     
#   11.05.2024 1.2.1.0 /bs
#     added code to install apks from /data/recovery to the script to enable adb
#
#   19.05.2024 1.2.2.0 /bs
#     the script now also does a syntax check for an already existing init script on the phone(/data/recovery/enable_adb_via_service.sh) 
#
#   23.05.2024 1.2.3.0 /bs
#     added code to wait until the service package is available if their are packages to install to the .rc script used to enable adb
#
# Prerequisites
#
#   The script must be executed in a running session in TWRP on the phone
#   Magisk must be already installed in the boot partition
#   The script reads the public ssl key from the file /tmp/adbkey.pub - if that file does not exist or is empty
#    no public ssl key for the access via adb will be configured
#
# The log file of the Magisk .rc script to enable adb is
#
#   /data/recovery/enable_adb_via_service.log
#
# The built-in logrotate in the script keeps the last 10 versions of the logfile.
#
# If debug is enabled in the Magisk .rc script (see the conents of the variablbe BOOT_SCRIPT_CODE below) to enable adb the script will created these additional files:
#
# global settings at script start:
#
#  /data/recovery/initial_settings.log
#
# global settings after enabling adb and developer mode
#
#  /data/recovery/initial_settings_with_enabled_adb.log
#
# To enabe debug in the .rc script change the value for the variable DEBUG to ${__TRUE}
#
# To re-run the script again for testing execute as root in an adb shell:
#
#    rm -rf /data/misc/adb /data/recovery/adb_initialized 
#
# and reboot the phone
#
# Notes
#
#   The files from Magisk in the directory /data/adb are not necessary for the Magisk features used by this script.
#   The magiskboot binary used is the binary from the TWRP image
#
# global variables
#

# the binary magiskboot is part of the TWRP recovery image
#
MAGISKBOOT="/system/bin/magiskboot"

DATA_DIR="/data"

# /cache is a symbolic link to this directory; /cache is used for the log files of Magisk
#
CACHE_DIR="${DATA_DIR}/cache"


#
# unencrypted files in /data/recovery are allowed
#
RECOVERY_DIR="${DATA_DIR}/recovery"

WORK_DIR="${RECOVERY_DIR}/work"

# script used by the init *rc service to enable adb and install simulated "pre-installed" apks if requested
#
ENABLE_ADB_SCRIPT="${RECOVERY_DIR}/enable_adb_via_service.sh"

# file for the definition of the new service
#
RC_FILE="${WORK_DIR}/enable_adb_via_service.rc"

# script to restore the boot partition from the image with the original contents of the partition
#
RESTORE_BOOT_PARTITION_SCRIPT="${WORK_DIR}/restore_boot_partition.sh"

# public ssl key for the access via adb
#
TMP_PUB_KEY_FILE="/tmp/adbkey.pub"


# variables used for creating the public ssl key for access via adb
#
CUR_PUB_KEY=""
ADB_XML_FILE_CONTENTS=""

# files with the public ssl keys used by the script enable_adb_via_service.sh
#
PERSISTENT_PUB_KEY_FILE="${RECOVERY_DIR}/adbkey.pub"
PERSISTENT_HUMAN_XML_FILE="${RECOVERY_DIR}/adb_temp_keys.xml.human"

# ---------------------------------------------------------------------
# script to enable access via adb
#

# variables defined in this script (enable_adb_using_magisk.sh) that should be used in the .rc script
#
BOOT_SCRIPT_VARIABLES="#
#
# variables defined in enable_adb_using_magisk.sh to be used in the Magisk .rc script:
#
  PERSISTENT_PUB_KEY_FILE=\"${PERSISTENT_PUB_KEY_FILE}\"
  PERSISTENT_HUMAN_XML_FILE=\"${PERSISTENT_HUMAN_XML_FILE}\"
"

# the code for the Magisk .rc script
#
# Note: Variables from the script enable_adb_using_magisk.sh can not be used in the code in BOOT_SCRIPT_CODE
#       To use these variables add the values to the variable BOOT_SCRIPT_VARIABLES (see above)
#
BOOT_SCRIPT_CODE='#
#
#
# constants
#
__TRUE=0
__FALSE=1

#
# for testing
#
#DEBUG=${__FALSE}
DEBUG=${__TRUE}


[ ${DEBUG}x = ${__TRUE}x ] && set -x

# ---------------------------------------------------------------------

function print_date {
  echo "The current time is: $( date )"
}

# ---------------------------------------------------------------------
# builtin logrotate 
#
function LogRotate {
  typeset CUR_FILE=""
  typeset j=0
   
  [ ${DEBUG}x = ${__TRUE}x ] && set +x

  while [ $# -ne 0 ] ; do
    CUR_FILE="$1"
    shift
    for i in 8 7 6 5 4 3 2 1 0 ; do
      let j=i+1
      [ -r "${CUR_FILE}.$i" ] && mv "${CUR_FILE}.$i" "${CUR_FILE}.$j"
    done
    [ -r "${CUR_FILE}" ] && mv "${CUR_FILE}" "${CUR_FILE}.0"
  done
  [ ${DEBUG}x = ${__TRUE}x ] && set -x
}

# ---------------------------------------------------------------------
# create a backup of current properties and settings
#
function backup_properties_and_settings {
  typeset THISRC=0
  
  typeset CUR_FILE=""
  typeset FILE_LIST=""
  typeset CUR_TYPE=""
  
  typeset KEY="$1"
  
  CUR_FILE="/data/recovery/${KEY}props"
    
  LogRotate "${CUR_FILE}"
  getprop >"${CUR_FILE}"

  FILE_LIST="${FILE_LIST} ${CUR_FILE}"
  
  for CUR_TYPE in system global secure ; do
    CUR_FILE="/data/recovery/${KEY}settings_${CUR_TYPE}"
    LogRotate "${CUR_FILE}"
    
    settings list ${CUR_TYPE} >"${CUR_FILE}"
    
    FILE_LIST="${FILE_LIST} ${CUR_FILE}"

  done

  [ -d /sdcard/Download ] && cp ${FILE_LIST} /sdcard/Download  

 return ${THISRC}
}

# ---------------------------------------------------------------------
# reset the USB port
#
# Note: This function is currently not used anymore in this script
#
function reset_usb_port {
  typeset CUR_OUTPUT=""
  typeset i=0
  typeset STEP=10
  
  typeset THISRC=${__FALSE}

  echo "Resetting the USB port now ..."  

  MAX_WAIT_TIME_IN_SECONDS=${MAX_WAIT_TIME_IN_SECONDS:=60}

# wait until a reset of the USB port works
#
  i=0
  while [ $i -lt ${MAX_WAIT_TIME_IN_SECONDS} ] ; do

# the RC of svc is 0 even if there is an error ...
#
    CUR_OUTPUT=$( svc usb resetUsbPort 2>&1 )
    if [[ ${CUR_OUTPUT} == Error* ]] ; then
  
      echo "USB reset did not yet work -- waiting now for ${STEP} seconds ..."
      sleep ${STEP}
      let i=i+${STEP}
    else
      echo "USB reset works after $i seconds(s)"
      THISRC=${__TRUE}
      break
    fi
  done

  if [ ${THISRC}x != ${__TRUE}x ] ; then
    echo "WARNING: reset did not work even after $i seconds"
  fi
  
  return ${THISRC}
}

# ---------------------------------------------------------------------
# restart the adb daemon 
#
# Note: This function is currently not used 
#
function restart_adbd {
  typeset THISRC=${__FALSE}
  
  typeset THIS_PARAMETER="$1"

  typeset RESTART_ADB=${__FALSE}

  print_date  
  
  if [ "${THIS_PARAMETER}"x = "force"x ] ; then
#
# restart the adb without any checks
#
     RESTART_ADB=${__TRUE}
     echo "Forced restart of the adbd requested"
  else
#
# check for already running adb sessions
#
    CUR_OUTPUT=$( ps -ef | grep -v grep | grep shell | grep -E -v "adbd|com.android.shell" )
    if [ "${CUR_OUTPUT}"x != ""x ] ; then
      echo "There is already at least one adb session running:"
      echo ""
      echo "${CUR_OUTPUT}"
      echo ""
      echo "adbd restart is not necessary"
      RESTART_ADB=${__FALSE}
    else
      echo "There are no adb sessions running - restarting the adbd is okay"
      RESTART_ADB=${__TRUE}
    fi
  fi

  if [ ${RESTART_ADB} = ${__TRUE} ] ; then
    print_date  
    echo "Now restarting the adb daemon ..."
    setprop ctl.start adbd
    sleep 1
    setprop ctl.restart adbd
  fi
  
  return ${RESTART_ADB} 
}

# ---------------------------------------------------------------------
#
# check if we do have a tty
#
tty -s 
if [ $? -ne 0 ] ; then
#
# running in a session without tty -- send STDOUT and STDERR to a file
#
  LogRotate /data/recovery/enable_adb_via_service.log

  exec >/data/recovery/enable_adb_via_service.log 2>&1
  print_date  

  [ ${DEBUG}x = ${__TRUE}x ] && set -x
fi

# ---------------------------------------------------------------------

print_date  
echo "*** Init script is starting "

CUR_PID=$$
echo "The PID of the process running this script is ${CUR_PID}"

PATH=/system/bin:$PATH
export PATH

SETTINGS="/system/bin/settings"

MAX_WAIT_TIME_IN_SECONDS=60

# tar file with a copy of the adb key files created by the script
#
TAR_FILE_WITH_DATA_MISC="/data/recovery/adb_misc_tar_${CUR_PID}_$( date +%Y-%M-%d-%s ).tar"

APK_INSTALL_STATUS_FILE="/data/recovery/additional_apks_already_installed"

# ---------------------------------------------------------------------
print_date  

echo "Waiting up to ${MAX_WAIT_TIME_IN_SECONDS} seconds until the settings command work ..."

STEP=5

i=0
while [ $i -lt ${MAX_WAIT_TIME_IN_SECONDS} ] ; do
  if [ -x ${SETTINGS} ] ; then
    CUR_OUTPUT=$( ${SETTINGS} get global development_settings_enabled 2>/dev/null  )
    [ "${CUR_OUTPUT}"x != ""x ] && break
#
    [ $? -eq 0 ] && break
  fi
  echo "Waiting ${STEP} seconds ..."
  let i=i+${STEP}
  sleep ${STEP}
done

print_date  

if [ -x /system/bin/settings ] ; then
  echo "/system/bin/settings is available after $i second(s) "
else
  echo "ERROR: /system/bin/settings is NOT available, not even after $i second(s)"
fi

if [ ${DEBUG}x = ${__TRUE}x ] ; then
  backup_properties_and_settings "start"  
fi

#
# only do this once
#
if [ ! -r /data/recovery/adb_initialized ] ; then

  print_date  

  echo "Creating the semaphor file /data/recovery/adb_initialized ..."

  touch /data/recovery/adb_initialized 

#
# check if adb is already enabled
#
  ADB_ENABLED=$( settings get global adb_enabled )
  if [ ${ADB_ENABLED}x = 1x ] ; then
    echo "adb is already enabled"
  else

# without this sleep it does not work!
#
  print_date  
    i=30
    echo "Sleeping $i seconds now ..."
    sleep $i
  print_date  


# ---------------------------------------------------------------------
# install additional apk files found in the directory /data/recovery 
#

# add the necessary options for the pm command in Android 14 or newer to install outdated apks
#
  PM_INSTALL_OPTION=""
  ANDROID_VERSION=$( getprop ro.build.version.release )
  
  if [ "${ANDROID_VERSION}"x != ""x  ] ; then
     echo "Running in Android ${ANDROID_VERSION} "
     if [ ${ANDROID_VERSION} -ge 14 ] ; then
       echo "Using the pm option \"--bypass-low-target-sdk-block\" to allow installing outdated apks "
       PM_INSTALL_OPTION=" --bypass-low-target-sdk-block "
    fi
  fi

  NO_OF_INSTALLED_APKS=0
  if [ ! -r "${APK_INSTALL_STATUS_FILE}" ] ; then
    echo "### Additional apk files installed at $( date) " >"${APK_INSTALL_STATUS_FILE}"

    echo "apk files in /data/recovery are:"
    ls -l /data/recovery/*.apk 
    TEMPRC=$?
    
    if [ ${TEMPRC} -eq 0 ] ; then

#
# wait until the service package is ready
#
      echo "Waiting up to 60 seconds until the service \"package\" is ready ..."
      i=0
      while [ $i -lt 60 ] ; do
        SERVICE_STATUS="$( service check package 2>/dev/null  )"
        SERVICE_STATUS="$( echo "${SERVICE_STATUS}" | cut -f2 -d ":" )"
        if [ "${SERVICE_STATUS}"x != " found"x ] ; then
          (( i = i + 5 ))
          sleep 5
        else 
          echo "The service \"package\" is ready after $i second(s)"
          break
        fi
      done
    fi
          
    for CUR_APK_FILE in /data/recovery/*.apk; do
      [[ ${CUR_APK_FILE} == *\** ]] && break

      echo "Installing the apk file \"${CUR_APK_FILE}\" ..."

      CUR_APK_FILE_SIZE="$( ls -l "${CUR_APK_FILE}"  | awk "{ print \$5 }" )"

      cat ${CUR_APK_FILE} | pm install ${PM_INSTALL_OPTION} -S "${CUR_APK_FILE_SIZE}" 
      if [ $? -eq 0 ] ; then
        echo "\"${CUR_APK_FILE}\" successfully installed" | tee -a "${APK_INSTALL_STATUS_FILE}"
        (( NO_OF_INSTALLED_APKS = NO_OF_INSTALLED_APKS + 1 ))
      else
        echo "ERROR: \"${CUR_APK_FILE}\" not installed" | tee -a "${APK_INSTALL_STATUS_FILE}"
      fi        
    done
    echo "${NO_OF_INSTALLED_APKS} apk(s) successfullly installed"
  else
    echo "Additional apk files already installed"
    cat "${APK_INSTALL_STATUS_FILE}"
  fi

# ---------------------------------------------------------------------

# set device provisioned 
#
  settings put global device_provisioned 1

#
# enable the developer options
#  
    echo "Enabling the develop options now ..."

    settings put global development_settings_enabled 1

#
# enable access via adb
#
    echo "Enabling adb now ..."

    settings put global adb_enabled 1
  fi
  
  if [ ${DEBUG}x = ${__TRUE}x ] ; then
    backup_properties_and_settings "initial"  

    if [ -d  /data/misc/adb  ] ; then
      echo "Directory /data/misc/adb:"
      ls -ldZ $( find /data/misc/adb )
    else
      echo "The directory /data/misc/adb does not yet exist"
    fi
  fi

#
# configure the public key for access via adb
# 
  FILES_CREATED=${__FALSE}
  
  if [ ! -d /data/misc/adb ] ; then
  
    echo "Creating the directory /data/misc/adb ... "

    mkdir -p /data/misc/adb
    chmod 2750 /data/misc/adb
    chown system:shell /data/misc/adb
    chcon -v u:object_r:adb_keys_file:s0 /data/misc/adb

    FILES_CREATED=${__TRUE}
  else
    echo "The directory /data/misc/adb already exists"
  fi

  ls -ldZ data/misc/adb 

  if [ ! -r /data/misc/adb/adb_keys ] ; then
    echo "Creating the file /data/misc/adb/adb_keys ..."

    touch /data/misc/adb/adb_keys
    chown system:shell /data/misc/adb/adb_keys
    chmod 0640 /data/misc/adb/adb_keys
    chcon -v u:object_r:adb_keys_file:s0 /data/misc/adb/adb_keys

    FILES_CREATED=${__TRUE}
    
  else
    echo "The file /data/misc/adb/adb_keys already exits"
  fi

  ls -ldZ /data/misc/adb/adb_keys

  if [ -r ${PERSISTENT_PUB_KEY_FILE} ] ; then
    echo "Creating the file /data/misc/adb/adb_keys ..."
    cat ${PERSISTENT_PUB_KEY_FILE}>>/data/misc/adb/adb_keys

    FILES_CREATED=${__TRUE}
  
    if [ -r ${PERSISTENT_HUMAN_XML_FILE} ] ; then
#
# create the XML file in Android binary XML format
# 
      echo "Creating the file /data/misc/adb/adb_temp_keys.xml ..."

      xml2abx ${PERSISTENT_HUMAN_XML_FILE} /data/misc/adb/adb_temp_keys.xml
      chmod 0600 /data/misc/adb/adb_temp_keys.xml
      chown system:shell /data/misc/adb/adb_temp_keys.xml
      chcon -v u:object_r:adb_keys_file:s0 /data/misc/adb/adb_temp_keys.xml   

      FILES_CREATED=${__TRUE}

    fi
  else
    echo "The public key for access via adb is not defined"
   
    if [ ! -r /data/misc/adb/adb_keys ] ; then
      echo "WARNING: The file /data/misc/adb/adb_keys does not exist "
    fi
  fi  

  ls -ldZ /data/misc/adb/adb_keys

  if [ ${FILES_CREATED} = ${__TRUE} ] ; then

    print_date  

    echo "Creating the file ${TAR_FILE_WITH_DATA_MISC} with the initial created files in /data/misc/adb ... "
    tar -cvf "${TAR_FILE_WITH_DATA_MISC}" /data/misc/adb     

    print_date  

  fi

  if [ ${DEBUG}x = ${__TRUE}x ] ; then
    echo "Directory /data/misc/adb is now:"
    ls -ldZ $( find /data/misc/adb )
  fi


# this seems to be neccessary for StatiXOS and LMODroid 
#
   settings put global device_provisioned 1
  
  LogRotate /data/recovery/initial_logcat.out

  /system/bin/logcat -d >/data/recovery/initial_logcat.out

else
  echo "$( date ): adb access already initialized"  

  if [ ${DEBUG}x = ${__TRUE}x ] ; then
    backup_properties_and_settings "second"  
  fi
  
  LogRotate /data/recovery/logcat.out

  /system/bin/logcat -d >/data/recovery/logcat.out

  if [ "${APK_INSTALL_STATUS_FILE}"x != ""x ] ; then
    if [ -r "${APK_INSTALL_STATUS_FILE}" -a -d /sdcard/Download ] ; then
      if [ ! -r "/sdcard/Download/${APK_INSTALL_STATUS_FILE##*/}" ] ; then
        cp "${APK_INSTALL_STATUS_FILE}" /sdcard/Download
      fi
    fi
  fi
fi

'

# create the final .rc script
#
BOOT_SCRIPT_CONTENTS="#
${BOOT_SCRIPT_VARIABLES}
${BOOT_SCRIPT_CODE}
"

# ---------------------------------------------------------------------
# definitions for the new trigger for the .rc file to enable access via adb
#
RC_FILE_CONTENTS="
#
# additional .rc service to enable the access via adb after the 1st boot into the new installed Android OS
#
service bnsmb_enable_adb /system/bin/sh ${ENABLE_ADB_SCRIPT} 
    user root 
    group root 
    seclabel u:r:magisk:s0 
    disabled
    oneshot

on zygote-start
    setprop sys.bnsmb_enable_adb_done 0
    start bnsmb_enable_adb

#
# Note: the following entries are for testing only!
#
on zygote-start
   write /data/recovery/semfile Here_I_am
   setprop sys.bnsmb.test.okay 0
"

# ---------------------------------------------------------------------
#

# ---------------------------------------------------------------------
# functions
#
function die {
  typeset THISRC=0
  
  if [ $# -ne 0 ] ; then
    THISRC=$1
    shift
  fi  
  
  if [ $# -ne 0 ] ; then
    echo "$*"
  fi
  
  exit ${THISRC}
}


# ---------------------------------------------------------------------
# main function 

#
# get the current boot slot
#
CUR_BOOT_SLOT="$( getprop ro.boot.slot_suffix )"

#
# check which boot slot should be patched
#
if [ $# -ne 0 ] ; then
  BOOT_SLOT_TO_PATCH="$1"
else
#
# default boot slot for patching is the inactive boot slot
#
  if [ "${CUR_BOOT_SLOT}"x = "_a"x ] ; then
    BOOT_SLOT_TO_PATCH="_b"
  elif [ "${CUR_BOOT_SLOT}"x = "_b"x ] ; then
    BOOT_SLOT_TO_PATCH="_a"
  else
    BOOT_SLOT_TO_PATCH=""
  fi
fi

# ---------------------------------------------------------------------
# check the prerequisites for the script
#

#
# check if the binary magiskboot exists (magiskboot is part of the TWRP recovery image)
#
if [ ! -x "${MAGISKBOOT}" ] ; then
  die 2 "The executable \"${MAGISKBOOT}\" does not exist or is not executable"
fi

#
# check if the directory /data exists
#
if [ ! -d "${DATA_DIR}" ] ; then
  die 3 "The mount point \"${DATA_DIR}\" does not exist"
fi

#
# check if /data is mounted to a partition
#
ROOT_DEV="$( df -h / | tail -1 | cut -f1 -d " " )"
DATA_DEV="$( df -h "${DATA_DIR}" | tail -1 | cut -f1 -d " " )"

if [ "${ROOT_DEV}"x = "${DATA_DEV}"x ] ; then
  die 5 "${DATA_DIR} is not mounted on a separate partition"
fi

# create the directory /data/recovery if it does not yet exist
#
if [ ! -d "${RECOVERY_DIR}" ] ; then
  echo "The directory ${RECOVERY_DIR} does not exist -- will now create it ..."
  mkdir -p "${RECOVERY_DIR}" && \
    chown system:cache "${RECOVERY_DIR}" && \
    chmod 0700 "${RECOVERY_DIR}" && \
    chcon -v "u:object_r:system_data_file:s0" "${RECOVERY_DIR}"
  if [ $? -ne 0 ] ; then
    die 7 "Error creating the directory \"${RECOVERY_DIR}\" "
  fi
fi


# create the directory /data/cache if it does not yet exist
#
if [ ! -d "${CACHE_DIR}" ] ; then
  echo "The directory ${CACHE_DIR} does not exist -- will now create it ..."
  mkdir -p "${CACHE_DIR}" && \
    chown system:cache "${CACHE_DIR}" && \
    chmod 0770 "${CACHE_DIR}" && \
    chcon -v "u:object_r:cache_file:s0" "${CACHE_DIR}"
  if [ $? -ne 0 ] ; then
    die 8 "Error creating the directory \"${CACHE_DIR}\" "
  fi
fi


# create the work dir to patch the boot partition if it does not yet exist
#
if [ ! -d "${WORK_DIR}" ] ; then
  echo "The working directory \"${WORK_DIR}\" does not exist -- will now create it ..."
  mkdir -p "${WORK_DIR}" && \
    chown system:cache "${WORK_DIR}" && \
    chmod 0700 "${WORK_DIR}" && \
    chcon -v "u:object_r:system_data_file:s0" "${WORK_DIR}"
  if [ $? -ne 0 ] ; then
    die 9 "Error creating the directory \"${WORK_DIR}\" "
  fi
fi

#
# delete existing key files in the directory /data/recovery
#
rm -f "${PERSISTENT_PUB_KEY_FILE}" 2>/dev/null
rm -f "${PERSISTENT_HUMAN_XML_FILE}" 2>/dev/null

#
# read the public ssl file for the access via adb from the temporary file
#

if [ -r "${TMP_PUB_KEY_FILE}" ] ; then

  echo "Reading the public ssl key for the access via adb from the file \"${TMP_PUB_KEY_FILE}\" ..."
 
  CUR_PUB_KEY="$( cat "${TMP_PUB_KEY_FILE}" )"
  if [ "${CUR_PUB_KEY}"x != ""x ] ; then

    grep -E -v "^$|^#" "${TMP_PUB_KEY_FILE}" >"${PERSISTENT_PUB_KEY_FILE}"

    LAST_CONNECTION_TIME="$( date +%s%3N )"

    ADB_XML_FILE_CONTENTS="<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<keyStore version=\"1\">"

   while read LINE ; do 
     ADB_XML_FILE_CONTENTS="${ADB_XML_FILE_CONTENTS}
  <adbKey key=\"${LINE}\" lastConnection=\"${LAST_CONNECTION_TIME}\" />"      
   done < "${PERSISTENT_PUB_KEY_FILE}"

   ADB_XML_FILE_CONTENTS="${ADB_XML_FILE_CONTENTS}
</keyStore>"

    echo "${ADB_XML_FILE_CONTENTS}" >"${PERSISTENT_HUMAN_XML_FILE}"

  else
    echo "The file \"${TMP_PUB_KEY_FILE}\" is empty (or there was an error reading that file) -- will not configure a public ssl key for the access via adb"
  fi 
  
else
  echo "The file \"${TMP_PUB_KEY_FILE}\" does not exist -- will not configure a public ssl key for the access via adb"
fi

# create the script and rc file used to implement the feature
#

if [ -r "${ENABLE_ADB_SCRIPT}" ] ; then
  echo "The script to enable access via adb \"${ENABLE_ADB_SCRIPT}\" already exists:"
  echo "# ---------------------------------------------------------------------"
  cat "${ENABLE_ADB_SCRIPT}"
  echo "# ---------------------------------------------------------------------"
else
  echo "Creating the script to enable access via adb \"${ENABLE_ADB_SCRIPT}\" ..."

  echo "${BOOT_SCRIPT_CONTENTS}" >"${ENABLE_ADB_SCRIPT}" && \
    chmod 755 "${ENABLE_ADB_SCRIPT}" &&
    chcon -v u:object_r:system_data_file:s0 "${ENABLE_ADB_SCRIPT}"
  if [ $? -ne 0 ] ; then
    die 11 "Error creating the script \"${ENABLE_ADB_SCRIPT}\" "
  fi
fi
  
echo "Doing a syntax check for the script \"${ENABLE_ADB_SCRIPT}\" ..."

sh -x -n "${ENABLE_ADB_SCRIPT}"
if [ $? -ne 0 ] ; then
  die 14 "There is a syntax error in the script \"${ENABLE_ADB_SCRIPT}\" "
fi

if [ -r "${RC_FILE}" ] ; then
  echo "The .rc file with the additional trigger to enable access via adb \"${RC_FILE}\" already exists:"
  echo "# ---------------------------------------------------------------------"
  cat "${RC_FILE}"
  echo "# ---------------------------------------------------------------------"
else
  echo "Creating the .rc file with the additional trigger to enable access via adb \"${RC_FILE}\" ..."

  echo "${RC_FILE_CONTENTS}" >"${RC_FILE}"
  if [ $? -ne 0 ] ; then
    die 13 "Error creating the .rc file with the additional trigger to enable access via adb \"${RC_FILE}\" "
  fi
  
fi

cd "${WORK_DIR}" || die 15 "Can not change the working directory to \"${WORK_DIR}\" "

#
# patch the boot parttion
#

BOOT_PARTITION_TO_PATCH="/dev/block/by-name/boot${BOOT_SLOT_TO_PATCH}"

CUR_IMAGE_FILE="boot${BOOT_SLOT_TO_PATCH}.img"
NEW_IMAGE_FILE="boot${BOOT_SLOT_TO_PATCH}_new.img"

CUR_IMAGE_FILE_SYMLINK="original_boot_partition.img"

echo "Copying the partition \"${BOOT_PARTITION_TO_PATCH}\" into the file \"${CUR_IMAGE_FILE}\" ..."

dd if="${BOOT_PARTITION_TO_PATCH}" of="${CUR_IMAGE_FILE}"
if [ $? -ne 0 ] ; then
  die 17 "Error copying the partition \"${BOOT_PARTITION_TO_PATCH}\" into the file \"${CUR_IMAGE_FILE}\" "
else
#
# create a symlink to the image file with the original boot partition with a fixed name
#  
  [ -L "${CUR_IMAGE_FILE_SYMLINK}" ] && rm "${CUR_IMAGE_FILE_SYMLINK}"
  ln -s "${CUR_IMAGE_FILE}" "${CUR_IMAGE_FILE_SYMLINK}"

#
# create the script to restore the boot partition via dd
#
  echo "#  

  echo \"Restoring the boot partition ${BOOT_PARTITION_TO_PATCH} from the file ${WORK_DIR}/${CUR_IMAGE_FILE_SYMLINK} \"
  if [ \"\$1\"x != \"yes\"x ] ; then
    echo \"Press <yes> enter to continue\"
    read USER_INPUT
    if [ \"\${USER_INPUT}\"x != \"yes\"x ] ; then
      echo \"Script aborted by the user\"
      exit 5
    fi
  fi
  dd if=${WORK_DIR}/${CUR_IMAGE_FILE_SYMLINK} of=${BOOT_PARTITION_TO_PATCH} 
"  >"${RESTORE_BOOT_PARTITION_SCRIPT}" && \
  chmod 755 "${RESTORE_BOOT_PARTITION_SCRIPT}"
  if [ $? -ne 0 ] ; then
    echo "WARNING: Can not create the script \"${RESTORE_BOOT_PARTITION_SCRIPT}\" to restore the boot partition"
  else
    echo "Successfully created the script \"${RESTORE_BOOT_PARTITION_SCRIPT}\" to restore the boot partition"
  fi
fi

echo "Extracting the ramdisk from the file \"${CUR_IMAGE_FILE}\" ..."
${MAGISKBOOT} unpack  -h "${CUR_IMAGE_FILE}" 
if [ $? -ne 0 -o ! -r ramdisk.cpio ] ; then
  die 21 "Error extracting the ramdisk from the file \"${CUR_IMAGE_FILE}\" "
fi

echo "Adding the new .rc file \"${RC_FILE}\" to the ramdisk ..."

${MAGISKBOOT} cpio ramdisk.cpio \
    "mkdir 0700 overlay.d" \
    "add 0700 overlay.d/init.custom.rc ${RC_FILE}"  

if [ $? -ne 0 ] ; then
  die 23 "Error adding the new .rc file \"${RC_FILE}\" to the ramdisk"
fi

echo "Recreating the boot image file \"${CUR_IMAGE_FILE}\" ..."

${MAGISKBOOT} repack "${CUR_IMAGE_FILE}" "${NEW_IMAGE_FILE}"
if [ $? -ne 0  -o ! -r "${NEW_IMAGE_FILE}" ] ; then
  die 25 "Recreating the boot image file \"${NEW_IMAGE_FILE}\"  "
fi

echo "Patching the new image file \"${NEW_IMAGE_FILE}\" to the boot partition ${BOOT_PARTITION_TO_PATCH} ..."

dd if="${NEW_IMAGE_FILE}" of="${BOOT_PARTITION_TO_PATCH}" 
if [ $? -ne 0 ] ; then
  die 27 "Error patching the new image file \"${NEW_IMAGE_FILE}\" to the boot partition ${BOOT_PARTITION_TO_PATCH}"
fi

die 0

