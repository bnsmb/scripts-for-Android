# -----------------------------------------------------------------------------
#
# check_apks.sh - quick and dirty script to create "pm install" commands for all apks found with an outdated target sdk version
#
# Note that the script does NOT install or change anything!
#
# History
#   10.04.2024 1.0.0.0 /bs
#     initial release
#
#   26.04.2024 1.1.0.0 /bs
#     if the environment variable ALL_PKGS is not empty the script creates install commands for all apks.
#
#h# Usage:
#h#
#h#   cd <dir_with_apk_files>
#h#   check_apks.sh [sdk=nn] [for_android] > <output_file_for_the_pm_commands_to_install_the_apks>
#h#
#h# The parameter "sdk=nnn" can be used to change the SDK version used to check the target sdk version in the apk files
#h# If the parameter "for_android" is used, the script creates commands that must be executed in a shell on the phone
#h# even if running on a PC.
#h#
#h# Use the environment variable AAPT to define the aapt executable to be used (if not available via PATH variable)
#h# Use the environment variable TMPFILE_DIR to define a different directory for temporary files
#h#
# The script can run either in the Android OS or in the Linux OS running on the PC
# 
# The script needs the executable aapt from the Android SDK
# Set the environment variable AAPT if the aapt executable is not available via the PATH.
#
# The script checks all apk files found in the current directory (*.apk and *.apk.gz)
#
# If there is more than one version for an apk file, the script will only use the apk file with the latest timestamp
#
# The script writes the command to install the apk via "pm install" command to STDOUT for every apk file found with an outdated target sdk version.
#
# -----------------------------------------------------------------------------

__TRUE=0
__FALSE=1

# required target sdk version for the running Android OS
#
DEFAULT_REQUIRED_MINIMUM_TARGET_SDK_VERSION=23


# -----------------------------------------------------------------------------
# variables for the statistics
#
APKS_PROCESSED=""
NO_OF_APKS_PROCESSED=0

APKS_NOT_PROCESSED=""
NO_OF_APKS_NOT_PROCESSED=0

APKS_WITH_OUTDATED_TARGET_SDK=""
NO_OF_APKS_WITH_OUTDATED_TARGET_SDK=0

# -----------------------------------------------------------------------------

# ----------------------------------------------------------------------
# LogMsg
#
# function: write a message to STDERR
#
# usage: LogMsg [message]
#
#
function LogMsg {
  echo "$*" >&2
}

# ----------------------------------------------------------------------
# isNumber
#
# function: check if a value is an integer
#
# usage: isNumber testValue
#
# returns: ${__TRUE} - testValue is a number else not
#
typeset -f isNumber >/dev/null|| function isNumber {
  typeset THISRC=${__FALSE}

  [[ $1 == +([0-9]) ]] && THISRC=${__TRUE} || THISRC=${__FALSE}

  return ${THISRC}
}


# -----------------------------------------------------------------------------
# main function
#

LogMsg "check_apks.sh - check the target sdk version of apk files"
LogMsg ""

# the variable TMPFILE_DIR is used in the usage help
#
# check if we're running in Android or not
#
getprop 2>/dev/null >/dev/null
if [ $? -eq 0 ] ; then
  TMPFILE_DIR="${TMPFILE_DIR:=/sdcard/Download}"
else
  TMPFILE_DIR="${TMPFILE_DIR:=/tmp}"
fi
LogMsg ""

# aapt binary from the Android SDK
#
AAPT=${AAPT:=$( which aapt 2>/dev/null )}

# use the default for aapt
#
AAPT="${AAPT:=${DEFAULT_AAPT_BINARY}}"

# add the prefix "adb shell " to the "pm install" commands if running on a PC
#
ADB_SHELL_PREFIX=${__TRUE}

# process the parameter
#
PARAMETER_OKAY=${__TRUE}

while [ $# -ne 0 ] ; do
  CUR_PARAMETER="$1"
  shift
  
  case ${CUR_PARAMETER} in

    -h | --help )
      grep "^#h#" $0 | cut -c4-
      echo " The default sdk version for the check is ${DEFAULT_REQUIRED_MINIMUM_TARGET_SDK_VERSION}"
      echo " The default directory for temporary files is ${TMPFILE_DIR}"
      if [ "${AAPT}"x != ""x ] ; then
        echo " The aapt executable to use is \"${AAPT}\" "
      else
        echo " No aapt executable found "
      fi
      echo ""
      exit 1
      ;;

    for_android )
      ADB_SHELL_PREFIX=${__FALSE}
      ;;

    sdk=* )
      NEW_SDK=${CUR_PARAMETER#*=}
      if ! isNumber ${NEW_SDK} ; then
        LogMsg "The value for the parameter sdk=nnn is not a number: \"${NEW_SDK}\" "
        PARAMETER_OKAY=${__FALSE}
      else
        REQUIRED_MINIMUM_TARGET_SDK_VERSION=${NEW_SDK}
      fi       
      ;;
      
    * )
      LogMsg "Unknown parameter found: \"${CUR_PARAMETER}\" "
      PARAMETER_OKAY=${__FALSE}
      ;;
  esac
done

if [ ${PARAMETER_OKAY} != ${__TRUE} ] ; then
  LogMsg "One or more invalid parameter found"
  exit 5
fi

REQUIRED_MINIMUM_TARGET_SDK_VERSION="${REQUIRED_MINIMUM_TARGET_SDK_VERSION:=${DEFAULT_REQUIRED_MINIMUM_TARGET_SDK_VERSION}}"

# check if we're running in Android or not
#
getprop 2>/dev/null >/dev/null
if [ $? -eq 0 ] ; then
  LogMsg "Running in the Android OS" 
  CUR_OS="android"
  ADB_PREFIX=""
  DEFAULT_AAPT_BINARY=""
  TMPFILE_DIR="${TMPFILE_DIR:=/sdcard/Download}"
else
  LogMsg "NOT running in the Android OS"
  CUR_OS="non-android"
  if [ ${ADB_SHELL_PREFIX} = ${__TRUE} ] ; then
    LogMsg "Creating \"pm install\" commands that must be executed on the PC"    
    ADB_PREFIX="adb shell "
  else
    LogMsg "Creating \"pm install\" commands that must be executed in a shell on the phone"    
  fi
  DEFAULT_AAPT_BINARY="/data/develop/android/android_sdk/build-tools/34.0.0/aapt"
  TMPFILE_DIR="${TMPFILE_DIR:=/tmp}"
fi
LogMsg ""

if [ "${AAPT}"x = ""x  ] ; then
  LogMsg "ERROR: aapt binary not found (set the variable AAPT before starting this script if aapt is not available via PATH)"
  exit 200
fi

LogMsg "Searching for apk files with a target sdk value less then ${REQUIRED_MINIMUM_TARGET_SDK_VERSION}"

# get the file used for STDOUT

STDOUT=$( ls -l /proc/$$/fd/1 | awk '{ print $NF}' )
[[ ${STDOUT} == /dev/pts/* ]] && STDOUT="standard output (use redirection for stdout (> <filename>) to write to a file)"

LogMsg "The pm commands to install the apks will be written to \"${STDOUT}\" "
LogMsg ""

if [ ! -d "${TMPFILE_DIR}" ] ; then
  LogMsg "ERROR: The directory for temporary files \"${TMPFILE_DIR}\" does not exist -- set the variable TMPFILE_DIR before starting this script"
  exit 5
fi


# a temporary file is necessary to process compressed apk files
#
TMP_APK="${TMPFILE_DIR}/test.$$"

# the script writes the list of apks found including the name, version, and target sdk version to this file
#
OUTFILE="${TMPFILE_DIR}/apks.$$.lst"

echo "# APK file : target sdk version : app name  : app version"      >"${OUTFILE}"

LogMsg "Processing the apk files in the directory \"${PWD}\" ..."

# get the list of apk files in the current directory
#
LIST_OF_APKS="$( ls -a *.apk *.apk.gz | sed "s/-[a-f0-9]*.apk.*//g" | sort | sort | uniq | grep -E -v "^android$|com.keramidas.TitaniumBackup.apk" )"
NO_OF_APKS_FOUND=$( echo "${LIST_OF_APKS}" | wc -l | tr -d " " )
LogMsg "${NO_OF_APKS_FOUND} apk(s) found"

LogMsg "Creating the list of latest apk files ..:"

# only process the latest version of each apk found
#
CURRENT_APKS="" ; for i in $LIST_OF_APKS ; do printf "." >&2 ; j=$( ls -tr $i-*.apk* | tail -1 ); CURRENT_APKS="${CURRENT_APKS} $j" ; done   
printf "\n" >&2
NO_OF_CURRENT_APKS="$( echo "${CURRENT_APKS}" | tr " " "\n" | grep -E -v "^$" |  wc -l | tr -d " " )"
LogMsg "${NO_OF_CURRENT_APKS} unique apk(s) found"
LogMsg ""

# -----------------------------------------------------------------------------

for CUR_APK in ${CURRENT_APKS} ; do

  LogMsg "  Processing the file \"${CUR_APK}\" ..."

  if [[ ${CUR_APK} == *apk.gz ]] ; then
# 
# uncompress compressed apk files to a temporary file
#
    gzip -cd "${CUR_APK}" >"${TMP_APK}"
    if [ $? -eq 0 ] ; then
      CAT_COMMAND="gzip -cd "
      CUR_APK_FILE="${TMP_APK}"
    else
      LogMsg "ERROR: Can not uncompress the apk file \"${CUR_APK}\" "  
      APKS_NOT_PROCESSED="${APKS_NOT_PROCESSED} ${CUR_APK}"
      (( NO_OF_APKS_NOT_PROCESSED = NO_OF_APKS_NOT_PROCESSED + 1 ))
      continue
    fi
  else
   CAT_COMMAND="cat "
   CUR_APK_FILE="${CUR_APK}"
  fi

# read the infos from the apk file
#
  APK_BADGE=$( ${AAPT} dump badging "${CUR_APK_FILE}" 2>/dev/null )

# for debugging only
#  echo "${APK_BADGE}" >"/tmp/${CUR_APK}.badge"

  if [ "${APK_BADGE}"x = ""x ] ; then
    LogMsg "ERROR: Can not read the infos for the apk file \"${CUR_APK}\" "  
    APKS_NOT_PROCESSED="${APKS_NOT_PROCESSED} ${CUR_APK}"
    (( NO_OF_APKS_NOT_PROCESSED = NO_OF_APKS_NOT_PROCESSED + 1 ))
    continue
  fi

  APKS_PROCESSED="${APKS_PROCESSED} ${CUR_APK}"
  (( NO_OF_APKS_PROCESSED = NO_OF_APKS_PROCESSED + 1 ))


  APK_TARGET_SDK_VERSION="$( echo "${APK_BADGE}" | grep "^targetSdkVersion:" | cut -f2 -d"'" )"

  APK_LABEL="$( echo "${APK_BADGE}" | grep "^application-label:" | cut -f2 -d"'" )"
  [ "${APK_LABEL}"x = ""x ] && APK_LABEL="$( echo "${APK_BADGE}" | grep "^application: label="  | cut -f2 -d "'" )"

  APK_VERSION="$( echo "${APK_BADGE}" | grep "^versionName:" | cut -f2 -d"'" )"
  [ "${APK_VERSION}"x = ""x ] && APK_VERSION="$( echo "${APK_BADGE}" | grep versionName | sed "s/.*versionName=//g" | cut -f2 -d "'" )"


  LogMsg "    This is the app \"${APK_LABEL:=???} ${APK_VERSION}\"; the target sdk version is ${APK_TARGET_SDK_VERSION} "

  echo "${CUR_APK} : ${APK_TARGET_SDK_VERSION} : ${APK_LABEL} : ${APK_VERSION}" >>"${OUTFILE}"

  if [[ ${APK_TARGET_SDK_VERSION} -lt ${REQUIRED_MINIMUM_TARGET_SDK_VERSION} ]] ; then
    LogMsg "    The target sdk version is too old - writing the pm install command to STDOUT ..."
    CUR_APK_FILE_SIZE="$( ls -l "${CUR_APK_FILE}" | awk '{ print $5}' )"

    CUR_CMD="# ${APK_LABEL} ${APK_VERSION} - target sdk version: ${APK_TARGET_SDK_VERSION}
${CAT_COMMAND} "${CUR_APK}" | ${ADB_PREFIX} pm install --bypass-low-target-sdk-block -S "${CUR_APK_FILE_SIZE}" "

    echo ""
    echo "${CUR_CMD}"

    APKS_WITH_OUTDATED_TARGET_SDK="${APKS_WITH_OUTDATED_TARGET_SDK} ${CUR_APK}"
    (( NO_OF_APKS_WITH_OUTDATED_TARGET_SDK = NO_OF_APKS_WITH_OUTDATED_TARGET_SDK + 1 ))

  else
    LogMsg "    The target sdk version okay"

    if [ "${ALL_PKGS}"x = ""x ] ; then
      CUR_APK_FILE_SIZE="$( ls -l "${CUR_APK_FILE}" | awk '{ print $5}' )"

      CUR_CMD="# ${APK_LABEL} ${APK_VERSION} - target sdk version: ${APK_TARGET_SDK_VERSION}
${CAT_COMMAND} "${CUR_APK}" | ${ADB_PREFIX} pm install  -S "${CUR_APK_FILE_SIZE}" "

      echo ""
      echo "${CUR_CMD}"

    fi    
  fi

done

# -----------------------------------------------------------------------------

# print the summaries
#
if [ ${NO_OF_APKS_PROCESSED} != 0 ] ; then
  LogMsg ""
  LogMsg "${NO_OF_APKS_PROCESSED} apk file(s) processed"
  [ "${VERBOSE}"x != ""x ] && LogMsg "$( echo "${APKS_PROCESSED}" | tr " " "\n" )"
fi

if [ ${NO_OF_APKS_NOT_PROCESSED} != 0 ] ; then
  LogMsg ""
  LogMsg "${NO_OF_APKS_NOT_PROCESSED} apk file(s) not processed due to errors"
  LogMsg "$( echo "${APKS_NOT_PROCESSED}" | tr " " "\n" )"
fi

if [ ${NO_OF_APKS_WITH_OUTDATED_TARGET_SDK} != 0 ] ; then
  LogMsg ""
  LogMsg "${NO_OF_APKS_WITH_OUTDATED_TARGET_SDK} apk file(s) found with outdated target sdk"
  [ "${VERBOSE}"x != ""x ] && LogMsg "$( echo "${APKS_WITH_OUTDATED_TARGET_SDK}" | tr " " "\n" )"
fi

LogMsg ""
LogMsg "The pm commands to install the apks are stored in the file \"${STDOUT}\" "

LogMsg ""
LogMsg "The list of apks including the target sdk size were written to \"${OUTFILE}\" "
LogMsg ""

# -----------------------------------------------------------------------------

exit 0

# -----------------------------------------------------------------------------



