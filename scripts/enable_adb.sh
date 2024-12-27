#!/system/bin/sh
#
#H# enable_adb.sh - enable adb on a phone running the Android OS while the phone is booted from a recovery
#H#
#H# Usage:
#H#
#H#    enable_adb.sh
#H#
#H#    The script will wait up to 60 seconds until the settings command is usable and then enable
#H#    the development option and the adb connection.
#H#
#H#    The script will do nothing if the file "/cache/enable_adb_disabled" exists.
#H#    The script will write the messages into the file "/cache/enable_adb.log" if running in a session without tty
#H#
#H#    The script must run on the phone while the Android OS is running
#H#
#H#    The script should be used as a script in service.d for Magisk.
#H#
#H#
#H#
#
# History
#   16.12.2022 1.0.0.0 /bs
#     inital release

# for debugging:
#
# set -x

# define some constants
#
__TRUE=0
__FALSE=1

# semaphor file - the script will do nothing if this file exists
#
SEMFILE="/cache/enable_adb_disabled"

#
# logfile to use if running in a session without tty
#
LOGFILE="/cache/enable_adb.log"

# maximum time in seconds to wait until the command "settings" work
#
MAX_WAIT_TIME_IN_SECONDS=60

#
# executable to change the settings
#
SETTINGS="/system/bin/settings"


#
# check if we're running in a session with tty
#
/system/bin/tty -s 
if [ $? -eq 0 ] ; then 
  RUNNING_WITH_TTY_SESSION=${__TRUE}
  echo "Running in a session with tty "
else
  echo "Running in a session without tty -- using the logfile \"${LOGFILE}\" "
  exec 2>"${LOGFILE}" 1>&2
  RUNNING_WITH_TTY_SESSION=${__FALSE}
fi

echo "$0 -- enabling adb connections via USB"

#
# check if the sempahor file exists
#
if [ -r "${SEMFILE}" ] ; then
  if [ ${RUNNING_WITH_TTY_SESSION} = ${__TRUE} ] ; then
    echo "WARNING: The file \"${SEMFILE}\" exists -- the script will do nothing if executed via Magisk"
  else
    echo "$0: The file \"${SEMFILE}\" exists -- will do nothing "
    exit 0
  fi
fi


echo "Waiting up to ${MAX_WAIT_TIME_IN_SECONDS} seconds until the settings command work ..."

i=0
while [ $i -lt ${MAX_WAIT_TIME_IN_SECONDS} ] ; do
  if [ -x "${SETTINGS}" ] ; then
    "${SETTINGS}" get global development_settings_enabled 2>/dev/null  1>/dev/null 
    [ $? -eq 0 ] && break
  fi
  echo "Waiting 5 seconds ..."
  let i=i+5
  sleep 5
done

ADB_ENABLED="$( "${SETTINGS}" get global adb_enabled )"
DEVELOPMENT_SETTINGS_ENABLED="$( "${SETTINGS}" get global development_settings_enabled )"

ENABLING_ADB_WAS_SUCCESSFULL=${__TRUE}

if [ $? -ne 0 ] ; then
  echo "ERROR: The command settings still does not work - probably you should increase the  wait time; current value is ${MAX_WAIT_TIME_IN_SECONDS} seconds"
else
  echo "The time to wait until the command \"${SETTINGS}\" works was ${i} seconds"
  
  echo "The current value for the setting \"global development_settings_enabled\" is : ${DEVELOPMENT_SETTINGS_ENABLED}"
  echo "The current value for the setting \"global adb_enabled\" is : ${ADB_ENABLED}"

  if [ "${DEVELOPMENT_SETTINGS_ENABLED}"x = "1"x ] ; then
    echo "The development settings are already enabled"
  else
    echo "Now enabling the development settings ...."
	"${SETTINGS}" put global development_settings_enabled 1
    if [ $? -ne 0 ] ; then
      echo "ERROR: Something went wrong enabling the development settings"
      ENABLING_ADB_WAS_SUCCESSFULL=${__FALSE} 

    fi
  fi

  if [ "${ADB_ENABLED}"x = "1"x ] ; then
    echo "The adb connection is already enabled"
  else
    echo "Now enabling the adb connection  ...."
	"${SETTINGS}" put global adb_enabled 1
    if [ $? -ne 0 ] ; then
      echo "ERROR: Something went wrong enabling the adb connection"
      ENABLING_ADB_WAS_SUCCESSFULL=${__FALSE}

    fi
  fi

  echo "Re-reading the values for the changed settings now ..."
  
  NEW_ADB_ENABLED="$( "${SETTINGS}" get global adb_enabled )"
  NEW_DEVELOPMENT_SETTINGS_ENABLED="$( "${SETTINGS}" get global development_settings_enabled )"

  echo "The current value for the setting \"global development_settings_enabled\" is now : ${NEW_DEVELOPMENT_SETTINGS_ENABLED}"
  echo "The current value for the setting \"global adb_enabled\" is now : ${NEW_ADB_ENABLED}"
fi

if [ ${RUNNING_WITH_TTY_SESSION} = ${__FALSE} ] ; then

  if [ ${ENABLING_ADB_WAS_SUCCESSFULL} = ${__TRUE} ] ; then
    echo "Enabling adb was successfull - will now disable the automatic start of this script"
#
# disable the automatic start of the script for the next reboots if executed via Magisk
#
    touch "${SEMFILE}"
  else
    echo "Enabling adb was not successfull - will not disable the automatic start of this script"
  fi
fi

exit 0
