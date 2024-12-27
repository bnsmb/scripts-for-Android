#!/system/bin/sh
# 
# enable_wifi.sh - script for Android to enable WiFi in the persistent global settings
#
# History
#  20.11.2022 /bs
#    initial release
#
# Important Note:
#
# This script is only an example for how to process files in Android Binary XML format in a script!
#
# To change the settings stored in the file /data/system/users/0/settings_global.xml in Android there is the native command 
# 
# settings
# 
# that can be used to get or set the global settings, e.g.
# 
# 
# e.g to set or get the WiFi status:
# 
# 
# ASUS_I006D:/ $ settings  get global wifi_on                                                                                  
# 1
# ASUS_I006D:/ $
# 
# ASUS_I006D:/ $ settings  put global wifi_on  0                                                                               
# ASUS_I006D:/ $
# 
# ASUS_I006D:/ $ settings  get global wifi_on                                                                                      
# 0
# ASUS_I006D:/ $
# 
# ASUS_I006D:/ $ settings  put global wifi_on  1                                                                                   
# ASUS_I006D:/ $
# 
# ASUS_I006D:/ $ settings  get global wifi_on                                                                                      
# 1
# ASUS_I006D:/ $ 
# 

SETTINGS_GLOBAL_XML_FILE_BINARY="/data/system/users/0/settings_global.xml"
SETTINGS_GLOBAL_XML_FILE_HUMAN="data/local/tmp/setttings_global.xml.human.$$"

while true ;do

  echo "Checking WiFi status in the persistent global settings ..."

  if [ "$( id -u -n )"x != "root"x ] ; then
    echo "ERROR: This script must be executed by the root user"
    break
  fi
  
  if ! which abx2xml >/dev/nul ; then
    echo "ERROR: Executable \"abx2xml\" not found" 
    break
  fi
   
  if [ ! -r "${SETTINGS_GLOBAL_XML_FILE_BINARY}"  ] ; then
    echo "ERROR: Global settings file \"${SETTINGS_GLOBAL_XML_FILE_BINARY}\" not found"
    break
  fi

  echo "Converting the file \"${SETTINGS_GLOBAL_XML_FILE_BINARY}\" to an XML file in text format \"${SETTINGS_GLOBAL_XML_FILE_HUMAN}\" ..."

  abx2xml "${SETTINGS_GLOBAL_XML_FILE_BINARY}" "${SETTINGS_GLOBAL_XML_FILE_HUMAN}" || break

  CUR_OUTPUT="$( grep  'name="wifi_on"'  "${SETTINGS_GLOBAL_XML_FILE_HUMAN}" )"
  if [ "${CUR_OUTPUT}"x = ""x ] ; then
    echo "ERROR: No setting for WiFi found in the file \"${SETTINGS_GLOBAL_XML_FILE_BINARY}\" "
    break
  fi

  echo "${CUR_OUTPUT}" |  grep 'value="1"' >/dev/null
  if [ $? -eq 0 ] ; then
    echo "WiFi is already enabled in the persistent global settings"
    break
  fi
  
  echo "WiFi is currently disabled -- enabling WiFi now :.."
  sed -i -e  '/name="wifi_on"/ s/value="0"/value="1"/g' "${SETTINGS_GLOBAL_XML_FILE_HUMAN}" || break

  xml2abx  "${SETTINGS_GLOBAL_XML_FILE_HUMAN}" "${SETTINGS_GLOBAL_XML_FILE_BINARY}" || break

  echo "... WiFi enabled in the persistent global settings."
  echo ""
  echo "To activate the change reboot the phone"
  break
done
