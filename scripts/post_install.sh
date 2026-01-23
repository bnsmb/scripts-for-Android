#
# sample post install script for the customizing of the phone
#
# This script will be copied to the phone and executed there
#
# The script is executed by the user shell; use "su - -c <command>" to execute commands as user root
#
# code to get the UID used for an app:
#
# id -un $( dumpsys package com.machiav3lli.backup  | grep uid= | awk '{ print $1 }' | cut -f2 -d "=" )
#
# get a list of all IDs used for the apps:
#
# for i in $( pm list packages  | cut -f2 -d ":" ) ; do  APPID=$( dumpsys package $i | grep appId | tail -1 | cut -f2 -d "=" ); [ ! -z "${APPID}" ] && echo "$i: UID = $APPID, User =  $( id -un $APPID)"  ; done
#
# or to only list the UIDs
# 
# pm list packages -U
#
__TRUE=0
__FALSE=1

SU_PREFIX="su - -c "

LOGFILE="/sdcard/Download/${0##*/}.log"

# 
# execute the script with the commnad "script" if its available to get a log file
#
if [  "${POST_INSTALL_RUNNING}"x = ""x ] ; then
  SCRIPT="$( which script )"
  if [ "${SCRIPT}"x != ""x ]  ; then
    export POST_INSTALL_RUNNING=TRUE

    echo "Restarting the script with \"script\" ..."
    exec "${SCRIPT}" -a "${LOGFILE}" -c "sh $0 $*"
    exit $?
  fi
else
  echo
  echo "Script successfully restarted with script"
  echo
fi
  
if ! tty -s ; then
  echo "Running in an non-interactive session"
  RUNNING_IN_ADB_SESSION=${__FALSE}

# the settings command does not work with redirected STDOUT
# 
#  exec >"${LOGFILE}" 2>&1
#
else
  echo "Running in an interactive session"
  RUNNING_IN_ADB_SESSION=${__TRUE}
fi

echo ""
echo "*** Postinstall script is running ..."
echo ""
 

if [ ! -r /sdcard/Download/empty_misc.img ] ; then
# create a copy of the empty misc partition
#
  echo "Copying the partition /dev/block/by-name/misc to the file /sdcard/Download/empty_misc.img ..."

  ${SU_PREFIX} dd if=/dev/block/by-name/misc of=/sdcard/Download/empty_misc.img
else
  echo "The image file for the empty partition /dev/block/by-name/misc already exists:"
  ls -l /sdcard/Download/empty_misc.img
fi

#
# enable adb via WiFI
#
${SU_PREFIX} setprop persist.adb.tcp.port 6666

# alternative:
# settings put global mobile_data1 0
# settings put global mobile_data2 0
#
#
#
# waiting until the service manager is ready
#
SERVICE_MANAGER_READY=${__FALSE}
TIMEOUT=120
i=0

if getprop | grep "^\[servicemanager.ready\]" >>/dev/null ; then

  printf "Waiting up to ${TIMEOUT} seconds until the service manager is ready "
  while  [ $i -lt $TIMEOUT ] ;do

    CUR_VALUE=$( getprop servicemanager.ready )
    if [ "${CUR_VALUE}"x = "true"x ] ; then

#
# looks like that check is not sufficient 
# #
      	    
      SERVICE_MANAGER_READY=${__TRUE}
      printf "\n"
      echo "The service manager is ready after $i seconds (servicmanager.ready is \"${CUR_VALUE}\") "

      CUR_VALUE1=$( settings get global adb_enabled )
      if  [ "${CUR_VALUE1}"x != "1"x -a "${CUR_VALUE1}"x != "0"x ] ; then
	      echo "The settings command does not yet work (adb_enabled is \"${CUR_VALUE1}\") "
      else
        break
      fi
    fi
    printf "."
    sleep 1
    (( i = i + 1 ))
  done
else
  echo "Warning: Property \"servicemanager.ready\" not defined in this OS!"
fi

if [ ${SERVICE_MANAGER_READY} != ${__TRUE} ] ; then
  printf "\n"
  echo "Warning: The service manager is still not ready after ${TIMEOUT} seconds"
fi

# Disable sound effects
# 
echo "Disabling sound effects ..."

settings put system sound_effects_enabled 0
settings put system notification_sound_set 0  

# enable WiFi
#
echo "Enabling WiFi ..."
svc wifi enable

#
#
# define SIM to use for phone calls
#
echo "Use SIM 1 for phone calls ..."

settings put global multi_sim_voice_call 1

# define SIM to use for data connections
#
echo "Use SIM 1 for data connections ..."

settings put global multi_sim_data_call 1

echo "Disabling mobile data ..."

svc data disable

echo "Enable logcat for boot messages ..."

if ${SU_PREFIX} test -r /data/scripts/0001logcatboot -a -d /data/adb/post-fs-data.d/  ; then
  ${SU_PREFIX} cp /data/scripts/0001logcatboot /data/adb/post-fs-data.d/0001logcatboot &&  \
    ${SU_PREFIX} chmod 755 /data/adb/post-fs-data.d/0001logcatboot
fi

# enable notifications for Magisk in the Magisk installation task 
# sometimes is not persistent for unknown reaons
#
dumpsys package com.topjohnwu.magisk | grep android.permission.POST_NOTIFICATIONS: | grep "granted=true"  >/dev/null
if [ $? -ne 0 ] ; then

  echo "Grant the necessary permission to Magisk now ..."

  pm grant com.topjohnwu.magisk android.permission.POST_NOTIFICATIONS
  
fi

pm list packages | grep com.termux  >/dev/null
if [ $? -eq 0 ] ; then
  echo "Termux is installed"
  echo "Grant necessary permissions for Termux ..."
  pm grant com.termux android.permission.POST_NOTIFICATIONS
  pm grant com.termux android.permission.READ_EXTERNAL_STORAGE
  pm grant com.termux android.permission.WRITE_EXTERNAL_STORAGE
  pm grant com.termux android.permission.READ_MEDIA_AUDIO
  pm grant com.termux android.permission.READ_MEDIA_VIDEO
  pm grant com.termux android.permission.ACCESS_MEDIA_LOCATION
  pm grant com.termux android.permission.READ_MEDIA_IMAGES
fi

pm list packages | grep com.machiav3lli.backup  >/dev/null
if [ $? -eq 0 ] ; then
  echo "NeoBackup is installed"
  echo "Grant necessary permissions for NeoBackup ..."
  pm grant com.machiav3lli.backup android.permission.READ_SMS
  pm grant com.machiav3lli.backup android.permission.POST_NOTIFICATIONS
  pm grant com.machiav3lli.backup android.permission.READ_CALL_LOG
  pm grant com.machiav3lli.backup android.permission.RECEIVE_WAP_PUSH
  pm grant com.machiav3lli.backup android.permission.RECEIVE_MMS
  pm grant com.machiav3lli.backup android.permission.RECEIVE_SMS
  pm grant com.machiav3lli.backup android.permission.READ_EXTERNAL_STORAGE
  pm grant com.machiav3lli.backup android.permission.SEND_SMS
  pm grant com.machiav3lli.backup android.permission.WRITE_CALL_LOG
  pm grant com.machiav3lli.backup android.permission.WRITE_EXTERNAL_STORAGE
  pm grant com.machiav3lli.backup android.permission.READ_CONTACTS
  pm grant com.machiav3lli.backup android.permission.PACKAGE_USAGE_STATS

# Not working:
#  pm grant com.machiav3lli.backup android.permission.REQUEST_INSTALL_PACKAGES


  settings put secure install_non_market_apps 1
  settings put global package_verifier_enable 0

  appops set com.machiav3lli.backup MANAGE_EXTERNAL_STORAGE allow

  appops set com.machiav3lli.backup GET_USAGE_STATS allow
  appops set com.machiav3lli.backup RUN_IN_BACKGROUND allow
  appops set com.machiav3lli.backup MANAGE_EXTERNAL_STORAGE allow

# probably not working code
#
if [ 0 = 1 ] ;then
  NEO_BACKUP_DIR=""
  NEO_BACKUP_CONFIG_FILE="/data/data/com.machiav3lli.backup/shared_prefs/com.machiav3lli.backup_preferences.xml"
  if [ -r "${NEO_BACKUP_CONFIG_FILE}" ] ; then
    grep backup_location "${NEO_BACKUP_CONFIG_FILE}" 
    if [ $? -eq 0 ] ;then
      echo "The backup location is already definded in the file ${NEO_BACKUP_CONFIG_FILE} "
    else
      [ -d /sdcard/NeoTestBackup ] &&  NEO_BACKUP_DIR="/sdcard/NeoTestBackup"
      [ -d /sdcard/NeoBackup ] &&  NEO_BACKUP_DIR="/sdcard/NeoBackup"
      if [ "${NEO_BACKUP_DIR}"x != ""x ] ; then
         echo "Configuring the NeoBackup Backup Dir ${NEO_BACKUP_DIR} ..."
         sed -i -e "s#</map>#    <string name=\"backup_location\">${NEO_BACKUP_DIR}</string>\n</map>#g" "${NEO_BACKUP_CONFIG_FILE}"
         echo "The contents of the config file for NeoBackup are now:"
         echo
         cat "${NEO_BACKUP_CONFIG_FILE}" 
         echo 
      else
        echo "No directoryo with NeoBackup files found"
      fi
    fi
  else
    echo "The config file ${NEO_BACKUP_CONFIG_FILE} does not exist"
  fi
fi
   

fi
  
pm list packages | grep "package:com.keramidas.TitaniumBackup" >/dev/null
if [ $? -eq 0 ] ; then
  echo "Titanium Backup is installed"

# workaround for restores in Titanium Backup
  echo "Disabling verify for apps installed over usb ..."
  settings put global verifier_verify_adb_installs 0     

  echo "Grant the necessary permission to Titanum Backup now ..."

  pm grant com.keramidas.TitaniumBackup android.permission.POST_NOTIFICATIONS
        
  pm grant com.keramidas.TitaniumBackup android.permission.READ_EXTERNAL_STORAGE
  pm grant com.keramidas.TitaniumBackup android.permission.READ_PHONE_STATE
  pm grant com.keramidas.TitaniumBackup android.permission.GET_ACCOUNTS
  pm grant com.keramidas.TitaniumBackup android.permission.WRITE_EXTERNAL_STORAGE

  pm grant com.keramidas.TitaniumBackup  android.permission.READ_CONTACTS
  pm grant com.keramidas.TitaniumBackup  android.permission.ACCESS_MEDIA_LOCATION  
  
#  pm grant com.keramidas.TitaniumBackup  android.permission.READ_MEDIA_VISUAL_USER_SELECTED
  pm grant com.keramidas.TitaniumBackup  android.permission.READ_MEDIA_IMAGES
  pm grant com.keramidas.TitaniumBackup  android.permission.WRITE_CONTACTS
  pm grant com.keramidas.TitaniumBackup  android.permission.READ_MEDIA_AUDIO
  pm grant com.keramidas.TitaniumBackup  android.permission.READ_MEDIA_VIDEO
  pm grant com.keramidas.TitaniumBackup  android.permission.GET_ACCOUNTS
  pm grant com.keramidas.TitaniumBackup  android.permission.ACCESS_MEDIA_LOCATION
  pm grant com.keramidas.TitaniumBackup  com.android.voicemail.permission.ADD_VOICEMAIL

else
  echo "Titanium Backup is currently not installed"
fi


echo "Removing the directories system/priv-app/DocumentsUIGoogle and system/priv-app/DocumentsUI from the MiXplorer Magisk Module ..."
${SU_PREFIX} "\rm -rf /data/adb/modules/MiXplorer/system/priv-app/DocumentsUIGoogle /data/adb/modules/MiXplorer/system/priv-app/DocumentsUI"

if  [ -r /system/bin/sshd ] ; then
  echo "Enabling the automatic start of the sshd ..."
  touch /data/local/tmp/start_sshd

  grep bernd@oc8260701612.ibm.com /data/local/tmp/home/.ssh/authorized_keys 2>/dev/null 1>/dev/null
  if [ $? -ne 0 ] ; then
	  echo "Adding my public ssh key to /data/local/tmp/home/.ssh/authorized_keys ..."

	  echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAtxsGDqlD1UhJXkWjyA3kaP9ZUYc8nXYJr7u7uCsHZUIOnzWdPffvWBL+a7+yGVDaZucyz9wslD9sKZFIbodJqQBuQ0um/RuQRmLawGs+4QBMPdekzHCAjpearhvesz7arwIw79n3NmxI7n9i71oIGyqZxgCfP0Dr4WJ/izXLM2D7E+wP+U+PF4dxfJMPrKu1SPa/nZDMcy63ypGqtEGYu/m120cbfgasjTBe9P9gPX4jezMP2NKoXzUe1icGoH5aFGldYM9bb+2J9LAzoGPnifZd7fXBczAfzCiNl4qAeXSMjBMjTroTwJWNHCCP4yJYO2llf6p+U/SFzir5Gg3tRw== bernd@oc8260701612.ibm.com">>/data/local/tmp/home/.ssh/authorized_keys
  fi
else
  echo "/system/bin/sshd not found - can not configure the automatic start of the sshd"
fi


# configuring MicroG
#

MICROG_CONFIG_FILE="/data/data/com.google.android.gms/shared_prefs/com.google.android.gms_preferences.xml"
TMP_MICROG_CONFIG_FILE="/sdcard/Download/com.google.android.gms_preferences.xml"

MICROG_SERVICE="com.google.android.gms"

pm list packages | grep "${MICROG_SERVICE}" >/dev/null
if [ $? -ne 0 ] ; then
  echo "MicroG is not installed"
else
  echo "Configuring MicroG ..."
  
  ${SU_PREFIX} cp "${MICROG_CONFIG_FILE}" "${TMP_MICROG_CONFIG_FILE}"
  ${SU_PREFIX} chmod 644 "${TMP_MICROG_CONFIG_FILE}"
  
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

  ${SU_PREFIX} diff "${MICROG_CONFIG_FILE}" "${TMP_MICROG_CONFIG_FILE}"  >/dev/null
  if [ $? -eq 0 ] ; then
    echo "All MicroG settings are already okay"
  else
    echo "Changing the MicroG config and restarting MicroG ..."
    ${SU_PREFIX} cp "${TMP_MICROG_CONFIG_FILE}" "${MICROG_CONFIG_FILE}"
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

# disable the setup wizards if installed
#

SETUP_WIZARDS="$( pm list packages | grep "setupwizard$"  | cut -f2 -d ":"  )"
if [ "${SETUP_WIZARDS}"x != ""x ] ; then

  for CUR_WIZARD in ${SETUP_WIZARDS} ; do
    echo "Disabling the setup wizard \"${CUR_WIZARD}\" now ..."
    pm disable-user --user 0 "${CUR_WIZARD}"
  done
else
  echo "OK, no setup wizard found"
fi


#
# this settings kills the adb sessions
#
# echo "Setting the USB port to File transfer ..."
# svc usb setFunctions mtp 

if [ ${RUNNING_IN_ADB_SESSION} = ${__TRUE} ] ; then
       echo "Running in an interactive session - no automatic reboot required"
else
  echo "Waiting 15 seconds now before rebooting - press CTRL-C to abort ...."
  i=0
  ( while [ $i -lt 15 ] ; do
    (( i = i + 1 ))
    printf "."
    sleep 1
  done )
  printf "\n"

  echo "Now rebooting the phone ..."

  reboot
fi
#
