#!/system/bin/sh
#
# pre install script for the Android OS installation via prepare_phone.sh
#
# This script is executed after the 1st reboot of the phone 
# Note that there is no root access yet
#

# check if we're running in the LineageOS
#
PRODCUT_SYSTEM_NAME="$( getprop ro.product.system.name )"

SETUP_STATUS=$( settings get secure user_setup_complete 2>/dev/null )
if [ "${SETUP_STATUS}"x = "0"x ] ; then
  echo "Disabling the setup dialog .."
  settings put secure user_setup_complete 1
fi

# 3 button mode
#
  settings put secure navigation_mode 0


if [ "${PRODCUT_SYSTEM_NAME}"x != "lineage_sake"x ]  ; then
  echo "The OS on the phone is not the LineageOS"
else
  echo "Configuring initial settings for the LineageOS ..."

# --------------------------------------------------------------------  
# system settings

# locale for the system
#
  settings put system system_locales de-DE


# --------------------------------------------------------------------  
# secure settings
#

# --------------------------------------------------------------------  
# global settings
#

# --------------------------------------------------------------------  
fi

# disable the setup wizzards if installed
#

SETUP_WIZZARDS="$( pm list packages | grep "setupwizard$"  | cut -f2 -d ":"  )"
if [ "${SETUP_WIZZARDS}"x != ""x ] ; then

  for CUR_WIZZARD in ${SETUP_WIZZARDS} ; do	
    echo "Disabling the setup wizzard \"${CUR_WIZZARD}\" now ..."
    pm disable-user --user 0 "${CUR_WIZZARD}" 
  done
else
  echo "OK, no setup wizzard found"
fi

exit 0
