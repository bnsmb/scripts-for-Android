#!/bin/bash
#
# rename_apk.sh - rename apk files using the application name and version from the within the apk
#
# Usage: Usage: %0 [apkfile1] [...[apkfile#]]"
#
# The script uses the executable "aapt" to read the meta data of the apk files.
# The executable "aapt" must be available via the PATH or via the variable AAPT
#
# History
#   05.02.2024 v1.0.0.0 /bs
#     initial release
#

# uncomment the line enable dry-run mode (or set the variable PREFIX to "echo" before starting the script)
#
# PREFIX="echo"

if [ "${PREFIX}"x != ""x ] ; then
  echo ""
  echo "-----------------------------------------------------------------------"
  echo "INFO: The script is running dry-run mode -- no filename will be changed"
  echo "-----------------------------------------------------------------------"
  echo ""
fi

# search the aapt executable
#
AAPT="${AAPT:=$( which aapt )}"

if [ "$1"x = ""x -o "$1"x = "-h"x -o "$1"x = "--help"x ] ; then
  echo "Usage: %0 [apkfile1] [...[apkfile#]]"
  echo "(set the environment variable \"PREFIX\" to \"echo\" before starting the script for dry-run mode)"
  exit 1
fi

if [ "${AAPT}"x = ""x ] ; then
  echo "ERROR: aapt executable not found in the path and the variable AAPT is empty"
  exit 5
fi

while [ $# -ne 0 ] ; do
  echo ""
  CUR_APK_FILE="$1"
  shift
  
  echo "Processing the apk file \"${CUR_APK_FILE}\" ..."
  
  CUR_APP_NAME="$( "${AAPT}"  dump badging "${CUR_APK_FILE}" | sed -n "s/^application-label:'\(.*\)'/\1/p" )"
  CUR_APP_VERSION="$( "${AAPT}"  dump badging ""${CUR_APK_FILE}"" | grep  "versionName=" | cut -d"'" -f6 )"
  
  echo "  The application name is \"${CUR_APP_NAME}\" "
  echo "  The application version is \"${CUR_APP_VERSION}\" "

  if [ "${CUR_APP_NAME}"x = ""x ] ; then
    echo "ERROR: Can not read the application name for the apk fle \"${CUR_APK_FILE}\" "
    continue
  fi
  
  if [ "${CUR_APP_VERSION}"x = ""x ] ; then
    echo "WARNING: Can not read the application version for the apk fle \"${CUR_APK_FILE}\" - now using 1.0"
    CUR_APP_VERSION="1.0"
  fi
  
  [[ ${CUR_APP_VERSION} != v* ]] && CUR_APP_VERSION="v${CUR_APP_VERSION}"
  
  NEW_APK_FILE_NAME="$( echo "${CUR_APP_NAME}"  | tr " " "_" )_${CUR_APP_VERSION}.apk"
  
  echo "Now renaming \"${CUR_APK_FILE}\" to \"${NEW_APK_FILE_NAME}\" ..."
  ${PREFIX} mv "${CUR_APK_FILE}" "${NEW_APK_FILE_NAME}"
  
done

if [ "${PREFIX}"x != ""x ] ; then
  echo ""
  echo "-----------------------------------------------------------------------"
  echo "INFO: The script was running in dry-run mode -- no filename was changed"
  echo "----------------------------------------------------------------------"
  echo ""
fi
