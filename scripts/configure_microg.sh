# 
#h# configure_microg.sh - sample script to configure MicroG 
#h#
# This script enables the Google Device registration and the Cloud Messaging
# 
#h# Usage:
#h#   configure_microg.sh -x
#h#
#
# History:
#   06.12.2024 v1.0.0 /bs
#

# MicroG config file
#
MICROG_CONFIG_FILE="/data/data/com.google.android.gms/shared_prefs/com.google.android.gms_preferences.xml"

# temporary config file
#
TMP_MICROG_CONFIG_FILE="/sdcard/Download/com.google.android.gms_preferences.xml"

# MicroG service
#
MICROG_SERVICE="com.google.android.gms"

[ ${DEBUG}x != ""x ] && set -x

if [ "$1"x != "-x"x ] ; then
  grep "^#h#" $0 | cut -c4- 
  exit 1
elif [ "$( id -un )"x != "root"x ] ; then
  echo "Restarting the script as user \"root\" ..."
  su - -c $0 $*
  exit $?
elif [ ! -r   "${MICROG_CONFIG_FILE}" ] ; then
  echo "ERROR: The MicroG config file \"${MICROG_CONFIG_FILE}\" does not exist"
  exit 10
fi


pm list packages | grep "${MICROG_SERVICE}" >/dev/null
if [ $? -ne 0 ] ; then
  echo "MicroG is not installed"  
else
  echo "Configuring MicroG ..."
  
  cp "${MICROG_CONFIG_FILE}" "${TMP_MICROG_CONFIG_FILE}"

#
# enable the Google device registration
# 

  CUR_LINE="$( grep 'name="checkin_enable_service"' "${TMP_MICROG_CONFIG_FILE}" )"
  echo "${CUR_LINE}" | grep 'value="true"' >/dev/null
  if [ $? -eq 0  ] ; then
    echo "Google Device registration is already true"
  else
    echo "Enabling Google device registration ..."
    if [ "${CUR_LINE}"x != ""x ] ; then
      sed -i -e '/name="checkin_enable_service"/ s/value=".*"/value="true"/g' "${TMP_MICROG_CONFIG_FILE}"
    else
      sed -i -e 's#<map>#<map>\n    <boolean name="checkin_enable_service" value="true"/>#g' "${TMP_MICROG_CONFIG_FILE}"
    fi
  fi
  
#
# enable Cloud Messaging
#
  CUR_LINE="$( grep 'name="gcm_enable_mcs_service"' "${TMP_MICROG_CONFIG_FILE}" )"
  echo "${CUR_LINE}" | grep 'value="true"' >/dev/null
  if [ $? -eq 0  ] ; then
    echo "Cloud Messaging is already enabled"
  else
    echo "Enabling Cloud Messaging ..."
    if [ "${CUR_LINE}"x != ""x ] ; then
      sed -i -e '/name="gcm_enable_mcs_service"/ s/value=".*"/value="true"/g' "${TMP_MICROG_CONFIG_FILE}"
    else
      sed -i -e 's#<map>#<map>\n    <boolean name="gcm_enable_mcs_service" value="true" />#g' "${TMP_MICROG_CONFIG_FILE}"
    fi
  fi

#
# restart MicroG if necessary
#
  diff "${MICROG_CONFIG_FILE}" "${TMP_MICROG_CONFIG_FILE}"  >/dev/null
  if [ $? -eq 0 ] ; then
    echo "All MicroG settings are already okay"
  else
    echo "Changing the MicroG config and restarting MicroG ..."
    cp "${TMP_MICROG_CONFIG_FILE}" "${MICROG_CONFIG_FILE}"
    if [ $? -eq 0 ] ; then
      echo "Restarting MicroG ..."
#
# stop MicroG
#
      am force-stop "${MICROG_SERVICE}"

#
# start MicroG
#
      monkey -p "${MICROG_SERVICE}"  -c android.intent.category.LAUNCHER 1
    else
      echo "ERROR: Error changing the config file \"${MICROG_CONFIG_FILE}\" "
    fi
  fi
fi


