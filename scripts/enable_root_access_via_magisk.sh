# no hashbang : the path to sh is different in the Android OS and TWRP
# #!/sbin/sh
#
#H# enable_root_access_via_magisk.sh - script to enable root access by adding entries to the Magisk database
#H#
#H# Usage:
#H#
#h#    enable_root_access_via_magisk.sh [-f] [-H|--help] [id1 ... id#] 
#H#
#H# \"id#\" are the UIDs of the apps for which root access should be enabled
#H# If the script is running in the Android OS \"id#\" can also be the app name.
#H#
#H# The script was tested with these Magisk versions
#H#
#H#   Magisk 24.3
#H#   Magisk 25.1
#H#   Magisk 25.2 
#H#   Magisk 26.1
#H#   Magisk 26.2
#H#   Magisk 26.3
#H#   Magisk 26.4
#H#   Magisk 27.0
#H#   Magisk 28.0
#H#   Magisk 28.1
#H# 
#H# The format of the database entries for other Magisk versions may be different.
#H# Therefor to use it for databases created by other Magisk versions use the parameter "-f"
#H#
#H# The script can run in the Android OS or in an adb shell while booted from TWRP.
#H#
#H# The UIDs must be numeric if running in TWRP; to get the UID for an installed app use the command
#H#
#H#   pm list packages -U <app_name>  | cut -f3 -d ":" 
#H#
#H# e.g.
#H#
#H#   pm list packages -U com.android.shell  | cut -f3 -d ":" 
#H# 
#H# while the Android OS is running.
#H#
#H# The script uses the binary sqlite3 if found (either in the PATH or anywhere in /data/adb or /sdcard/Download ). 
#H# If no sqlite3 binary is found the magisk binary will be used. 
#H# If the binary magisk is available in the PATH, this is used, otherwise the Magisk binary /data/adb/magisk/magisk64 (or /data/adb/magisk/magisk32 for 32-bit CPUSs) is used.
#H#
#H# Environment variables used by the script if set:
#H#
#H#   MAGISK_DATA_DIR (Current value: \"${MAGISK_DATA_DIR}\")
#H#   BIN_DIR (Current value: \"${BIN_DIR}\")
#H#   TMPDIR (Current value: \"${TMPDIR}\")
#H#   SQLITE3 (Current value: \"${SQLITE3}\")
#H#
#H#
#
# History
#   05.12.2022 1.0.0.0 /bs  #VERSION
#     initial release
#  16.04.2023 v1.1.0.0 /bs #VERSION
#    enabled support for Magisk v26.1
#  07.05.2023 v1.2.0.0 /bs #VERSION
#    added code to create the Magisk Database if it does not yet exist
#  11.09.2023 v1.3.0.0 /bs #VERSION
#    enabled support for Magisk v26.2 and Magisk v26.3
#  11.11.2023 v1.4.0.0
#    enabled support for Magisk v26.4
#  05.02.2024 v1.5.0.0
#    enabled support for Magisk v27.0
#  21.11.2024 v1.6.0.0
#    enabled support for Magisk v28.0
#  09.02.2025 v1.7.0.0
#    enabled support for Magisk v28.1
#
# Author
#   Bernd.Schemmer (at) gmx.de
#   Homepage: http://bnsmb.de/
#
# Prerequisites
#   a phone with unlocked boot loader
#   an installed Magisk app on the phone
#   the script can run in the Android OS or in an adb shell while booted into TWRP
#   the script must be executed on the phone as user root (this is the default user in TWRP)
#   a working TWRP recovery image that can mount the /data partition (if running in TWRP)
#
# Test Environment
#   see above
#
# Notes:
#
#   n/a
#
#

SCRIPT_VERSION="$( grep "^#" $0 | grep "#VERSION" | grep "v[0-9]" | tail -1 | awk '{ print $3}' )"

SCRIPT_NAME="${0##*/}"
SCRIPT_PATH="${0%/*}"

# define some constants
#
__TRUE=0
__FALSE=1

#
# define variables
#
# list of Magisk versions tested
#
KNOWN_MAGISK_VERSIONS=" 24.2 24.3 25.1 25.2 26.1 26.2 26.3 26.4 27.0 28.0 28.1"

# default value for the parameter -f
#
FORCE=${__FALSE}

# directory with the general executables 
#
BIN_DIR="${BIN_DIR:=/system/bin}"

# data directory from Magisk
#
MAGISK_DATA_DIR="${MAGISK_DATA_DIR:=/data/adb}"

MAGISK_BIN_DIR="${MAGISK_DATA_DIR}/magisk"

# executables used by the script
#
MAGISK="$( which magisk )"
if [ "${MAGISK}"x = ""x ] ; then
  
# starting with Magisk v28 the name of the binary is always magisk
#
  MAGISK_NEW="${MAGISK_BIN_DIR}/magisk"

  if [[ $( uname -m ) == *64 ]] ; then 
    MAGISK="${MAGISK_BIN_DIR}/magisk64"
  else
    MAGISK="${MAGISK_BIN_DIR}/magisk32"
  fi

  if [ -x "${MAGISK}" ] ; then
      :
  elif [ -x "${MAGISK_NEW}" ] ; then
    MAGISK="${MAGISK_NEW}"
  fi
fi

SQLITE3="${SQLITE3:=$( which sqlite3 )}"

# list of executables used
#
EXECUTABLES="${MAGISK}"

# data files used by the script
#
MAGISK_DATABASE="${MAGISK_DATA_DIR}/magisk.db"

# backup of the existing Magisk database
#
MAGISK_DATABASE_BACKUP="${MAGISK_DATABASE}.$$.bkp"

# list of data files used
#
DATA_FILES="${MAGISK_DATABASE}"

#
# values for the other entries in a Magisk database entry in the policy table for the new or changed entries
#
LOGGING_VALUE=1
NOTIFICATION_VALUE=1
UNTIL_VALUE=0


# directories for the temporary files
#
# Note: The files in /cache are also available if the phone is booted from the installed OS
#
TMPDIR="${TMPDIR:=/cache/${SCRIPT_NAME}.$$}"

#
# variables for the script control flow and the script return code
#
THISRC=${__TRUE}
CONT=${__TRUE}

# ----------------------------------------------------------------------
#
# functions
#

# ----------------------------------------------------------------------
# isNumber
#
# function: check if a value is an integer
#
# usage: isNumber testValue
#
# returns: ${__TRUE} - testValue is a number else not
#
function isNumber {
  typeset THISRC=${__FALSE}

  [[ $1 == +([0-9]) ]] && THISRC=${__TRUE} || THISRC=${__FALSE}

  return ${THISRC}
}

# ----------------------------------------------------------------------
# LogMsg
#
# function: write a message to STDOUT
#
# usage: LogMsg [message]
#
function LogMsg {
  [ "$1"x = "-"x ] && shift

  typeset THISMSG="$*"

  echo "${THISMSG}"
}

# ----------------------------------------------------------------------
# LogError
#
# function: write a message prefixed with "ERROR:" to STDERR
#
# usage: LogError [message]
#
function LogError {
  typeset THISMSG="$*"

  LogMsg "ERROR: ${THISMSG}" >&2
}

# ----------------------------------------------------------------------
# die
#
# function: print a message and end the script
#
# usage: die [script_exit_code] [message]
#
# the parameter "message" is optional; the script will add a leading "ERROR: "
# to the message if the script_exit_code is not zero
#
# returns: n/a
#
function die  {
  typeset THISRC=$1
  [ $# -ne 0 ] && shift
  typeset THISMSG="$*"

  if [ "${THISMSG}"x != ""x ] ; then
    if [ ${THISRC} != 0 ] ; then
      LogError "${THISMSG} (RC=${THISRC})" >&2
    else
      LogMsg "${THISMSG}"
    fi
  fi

  exit ${THISRC}
}

# ----------------------------------------------------------------------
# running_in_twrp
#
# function: check if the script is running in a shell in TWRP
#
# usage: running_in_twrp
#
# returns: ${__TRUE} - the script is running in a shell in TWRP
#          ${__FALSE} - the script is NOT running in a shell in TWRP
#
# global variables used:
#
#   PROP_RO_TWRP_BOOTMODE - value of the property ro.twrp.bootmode
#

function running_in_twrp  {
  typeset THISRC=${__FALSE}
  
  PROP_RO_TWRP_BOOTMODE="$( getprop ro.twrp.boot 2>/dev/null)"
  
  [ "${PROP_RO_TWRP_BOOTMODE}"x = "1"x ]  && THISRC=${__TRUE} || THISRC=${__FALSE}

  return ${THISRC}
}

# ----------------------------------------------------------------------
# twrp_is_booted_from_a_partition
#
# function: check if the running TWRP was booted from a partition or from an image file
#
# usage: twrp_is_booted_from_a_partition
#
# returns: ${__TRUE}  - the running TWRP was booted from a partition
#          ${__FALSE} - the running TWRP was booted from an image fil
#
# global variables used:
#
#    PROP_RO_BOOTMODE - value of the propery ro.bootmode
#
function twrp_is_booted_from_a_partition  {
  typeset THISRC=${__FALSE}
   
  PROP_RO_BOOTMODE="$( getprop ro.bootmode 2>/dev/null )"

  [ "${PROP_RO_BOOTMODE}"x = "recovery"x ] && THISRC=${__TRUE} || THISRC=${__FALSE}
 
  return ${THISRC}
}

# ----------------------------------------------------------------------
# user_is_root
#
# function: check if the script is executed by the root user
#
# usage: user_is_root
#
# returns: ${__TRUE}  - the script is executed by the user root
#          ${__FALSE} - the script is NOTe executed by the user root
#
# global variables used:
#
#    CUR_USER_ID - current user id (e.g. root)
#
function user_is_root  {
  typeset THISRC=${__FALSE}
   
  CUR_USER_ID="$( id -un )"
  [ "${CUR_USER_ID}"x = "root"x ] && THISRC=${__TRUE} || THISRC=${__FALSE}
 
  return ${THISRC}
}

# ----------------------------------------------------------------------
# create_magisk_db
#
# function: create the magisk database /data/adb/magisk.db using magisk64
#
# usage: create_magisk_db
#
# returns: ${__TRUE}  - ok, patching was sucessfull
#          ${__FALSE} - an error occured
#
function create_magisk_db {
  typeset THISRC=${__TRUE}
     
  typeset MAGISK_DAEMON_STARTED=${__FALSE}
  typeset MAGISK_DAEMON_RUNNING=${__FALSE}

  if [ -r "${MAGISK_DATABASE}" ] ; then
    echo "The Magisk database file \"${MAGISK_DATABASE}\" already exists."
    ls -l "${MAGISK_DATABASE}"
  elif [ ! -r "${MAGISK}" ] ; then
    echo "ERROR: ${MAGISK} does not exist"
    THISRC=${__FALSE}
  elif [ ! -x "${MAGISK}" ] ; then
    echo "ERROR: ${MAGISK} is not executable"
    THISRC=${__FALSE}
  else
#
# create the database using magisk
#
    echo "The Magisk database does not yet exist "
    echo "Checking if the Magisk daemon is running ..."
    ${MAGISK} -v 
    if [ $? -ne 0 ] ; then
      echo "The Magisk daemon is not running -- will start it now ..."
      ${MAGISK} --daemon

      ${MAGISK} -v 
      if [ $? -ne 0 ] ; then
        echo "ERROR: Error starting the the Magisk daemon"
        THISRC=${__FALSE}
      else
        echo "Successfully started the Magisk daemon"
        MAGISK_DAEMON_STARTED=${__TRUE}
        MAGISK_DAEMON_RUNNING=${__TRUE}
      fi      
    else
      MAGISK_DAEMON_RUNNING=${__TRUE}
    fi

    if [ ${MAGISK_DAEMON_RUNNING} = ${__TRUE} ] ; then
      
      echo "Creating the database \"${MAGISK_DATABASE}\" using \"${MAGISK}\" ..."
      ${MAGISK} --sqlite "PRAGMA user_version"
      if [ $? -eq 0 ] ; then
        echo "Successfully created the Magisk database \"${MAGISK_DATABASE}\" :"
        ls -l "${MAGISK_DATABASE}"
      else
        echo "Error creating the Magisk database \"${MAGISK_DATABASE}\" "   
        THISRC=${__FALSE}
      fi
    fi
  
    if [ ${MAGISK_DAEMON_STARTED} = ${__TRUE} ]; then
      echo "Stopping the Magisk daemon now "
      ${MAGISK} --stop

      ${MAGISK} -v 
      if [ $? -eq 0 ] ; then
         echo "WARNING: Error stopping the The Magisk daemon"
      fi    
    fi    
  fi
   
  return ${THISRC}
}

# ----------------------------------------------------------------------
# print_magisk_policies
#
# function: print the policy table from the Magisk database
#
# usage: print_magisk_policies
#
# returns: ${__TRUE}  - database table successfully printed
#          ${__FALSE} - error
#
# Note
#  
# The function uses either sqlite3 or magisk to process the magisk database
#
function print_magisk_policies  {
  typeset THISRC=${__FALSE}

  LogMsg "Current entries in the Magisk database table \"policies\":"
  LogMsg ""
  if [ "${SQLITE3}"x != ""x ] ; then
    ${SQLITE3} -column -header "${MAGISK_DATABASE}" "select * from policies ;"
  else
    ${MAGISK} --sqlite "select * from policies ;"
  fi

  return ${THISRC}
}

# ----------------------------------------------------------------------
# read_magisk_policies_database
#
# function: read the table policies from the Magisk database into the global variable CURRENT_LIST_OF_APPS_WITH_ROOT_ACCESS
#
# usage: read_magisk_policies_database
#
# returns: ${__TRUE}  - database table successfully read
#          ${__FALSE} - error
#
# Note
#  
# The function uses either sqlite3 or magisk to process the magisk database
#
function read_magisk_policies_database  {
  typeset THISRC=${__FALSE}
  
  if [ "${SQLITE3}"x = ""x ] ; then
    CURRENT_LIST_OF_APPS_WITH_ROOT_ACCESS="$( ${MAGISK} --sqlite "select * from policies ;"  2>&1 )"
    TEMPRC=$?
  else
    CURRENT_LIST_OF_APPS_WITH_ROOT_ACCESS="$( ${SQLITE3} "${MAGISK_DATABASE}"  "select * from policies ;"  2>&1 )"
    TEMPRC=$?    
  fi
  
  [ ${TEMPRC} -eq 0 ] && THISRC=${__TRUE} ||  THISRC=${__FALSE} 

  return ${THISRC}
}


# ----------------------------------------------------------------------
# enable_root_for_existing_entry
#
# function: enable root access for an already existing entry in the database
#
# usage: enable_root_for_existing_entry ${CUR_ID}
#
# returns: ${__TRUE}  - ok
#          ${__FALSE} - error
#
# Note
#  
# The function uses either sqlite3 or magisk to process the magisk database
#
function enable_root_for_existing_entry  {
  typeset THISRC=${__FALSE}

  typeset CUR_UID="$1"

  if [ "${SQLITE3}"x = ""x ] ; then
    CUR_OUTPUT="$( ${MAGISK} --sqlite "REPLACE INTO policies (uid,policy,until,logging,notification) values(${CUR_UID},2,${UNTIlL_VALUE},${LOGGING_VALUE},${NOTIFICATION_VALUE});" )"
    TEMPRC=$?    
  else
    CUR_OUTPUT="$( ${SQLITE3} "${MAGISK_DATABASE}"  "REPLACE INTO policies (uid,policy,until,logging,notification) values(${CUR_UID},2,${UNTIL_VALUE},${LOGGING_VALUE},${NOTIFICATION_VALUE});" )"
    TEMPRC=$?    
  fi

  LogMsg "${CUR_OUTPUT}"
  
  [ ${TEMPRC} -eq 0 ] && THISRC=${__TRUE} ||  THISRC=${__FALSE} 

  return ${THISRC}
}

# ----------------------------------------------------------------------
# enable_root_for_new_entry
#
# function: enable root access with a new entry in the database
#
# usage: enable_root_for_new_entry ${CUR_ID}
#
# returns: ${__TRUE}  - ok
#          ${__FALSE} - error
#
# Note
#  
# The function uses either sqlite3 or magisk to process the magisk database
#
function enable_root_for_new_entry  {
  typeset THISRC=${__FALSE}

  typeset CUR_UID="$1"

  if [ "${SQLITE3}"x = ""x ] ; then
    CUR_OUTPUT="$( ${MAGISK} --sqlite "INSERT INTO policies (uid,policy,until,logging,notification) values(${CUR_UID},2,${UNTIL_VALUE},${LOGGING_VALUE},${NOTIFICATION_VALUE});" )"
    TEMPRC=$?    
  else
    CUR_OUTPUT="$( ${SQLITE3} "${MAGISK_DATABASE}"  "INSERT INTO policies (uid,policy,until,logging,notification) values(${CUR_UID},2,${UNTIL_VALUE},${LOGGING_VALUE},${NOTIFICATION_VALUE});" )"
    TEMPRC=$?    
  fi

  LogMsg "${CUR_OUTPUT}"

  [ ${TEMPRC} -eq 0 ] && THISRC=${__TRUE} ||  THISRC=${__FALSE} 

  return ${THISRC}
}


# ----------------------------------------------------------------------
# get_root_status_for_existing_entry
#
# function: get the root status for an existing entry in the database
#
# usage: get_root_status_for_existing_entry ${CUR_ID}
#
# returns: status of the entry (or "" if the entry does not exist in the database)
#
# The function uses the global variable CURRENT_LIST_OF_APPS_WITH_ROOT_ACCESS
#
# The function stores the database entry in the global variable DATABASE_ENTRY
# The function sets the global variable DATABASE_ENTRY_FOUND to ${__TRUE} if the entry exist in the database
# The status of the entry will be stored in the global variable DATABASE_ENTRY_STATUS
#
# Note
#  
# The function uses either sqlite3 or magisk to process the magisk database
#
function get_root_status_for_existing_entry  {
  typeset THISRC=${__FALSE}

  typeset CUR_UID="$1"
  
# init the global variables
#
  DATABASE_ENTRY=""
  DATABASE_ENTRY_FOUND=${__FALSE}
  DATABASE_ENTRY_STATUS=""
  
  if [ "${SQLITE3}"x != ""x ] ; then
    DATABASE_ENTRY="$( echo "${CURRENT_LIST_OF_APPS_WITH_ROOT_ACCESS}" | grep "^${CUR_UID}|" )"
    if [ "${DATABASE_ENTRY}"x != ""x ] ; then
      DATABASE_ENTRY_STATUS="$( echo "${DATABASE_ENTRY}" | cut -f2 -d "|"  )"
      DATABASE_ENTRY_FOUND=${__TRUE}
    fi
  else
    DATABASE_ENTRY="$(  echo "${CURRENT_LIST_OF_APPS_WITH_ROOT_ACCESS}" | grep "|uid=${CUR_UID}|" )"
    if [ "${CUR_ENTRY}"x != ""x ] ; then
      DATABASE_ENTRY_STATUS="$( echo "${DATABASE_ENTRY}" | cut -f3 -d "|" | cut -f2 -d "="  )"
      DATABASE_ENTRY_FOUND=${__TRUE}
    fi     
  fi
  
  return ${DATABASE_ENTRY_STATUS}
}

# ----------------------------------------------------------------------
# main function
#

if [ "$1"x = "-h"x ] ; then
#
# extract the usage help from the script source
#
  eval HELPTEXT=\""$( grep "^#h#" $0 | cut -c4- )"\"
  echo "
${HELPTEXT}
"
  exit 1

elif [ "$1"x = "-H"x -o "$1"x = "--help"x ] ; then
#
# extract the usage help from the script source
#
  eval HELPTEXT=\""$( grep -E "^#H#|^#h#" $0 | cut -c4- )"\"
  echo "
${HELPTEXT}
"
  exit 1
fi

LogMsg ""
LogMsg "Enabling root access for apps by adding entries to the Magisk database"
LogMsg ""

#
# check the prerequisites
#
user_is_root || die 100 "The script \"${SCRIPT_NAME}\" must be executed by the user root (the current user is \"${CUR_USER_ID}\")"

ERRORS_FOUND=${__FALSE}
LIST_OF_UIDS=""

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then

  running_in_twrp 
  if [ $? -eq 0 ] ; then
    LogMsg "OK, running in TWRP"
    
    RUNNING_IN_TWRP=${__TRUE}
#
# the next output is only for information
#    
    twrp_is_booted_from_a_partition 
    if [ $? -eq 0 ] ; then
      LogMsg "TWRP is booted from a boot or recovery partition"
    else
      LogMsg "TWRP is booted from an image file"
    fi
  else
    RUNNING_IN_TWRP=${__FALSE}
    
    LogMsg "Running in the Android OS"
  fi

  LogMsg "Using the Magisk binary \"${MAGISK}\" "

  LogMsg "Using the Magisk database \"${MAGISK_DATABASE}\" "
fi  


LogMsg "Checking the prerequisites ..."

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  
  LogMsg "Checking if the required executables exist ..."
  for CUR_FILE in ${EXECUTABLES} ; do
    if [ ! -x "${CUR_FILE}" ] ; then
      LogError "The executable \"${CUR_FILE}\" does not exist or is not executable"
      ERRORS_FOUND=${__TRUE}
    else
      LogMsg "OK, the file \"${CUR_FILE}\" exists and is executable"
    fi
  done

#
# create the Magisk database if it not already exists
#
  create_magisk_db || ERRORS_FOUND=${__TRUE}

  LogMsg "Checking if the required data files exist ..."
  for CUR_FILE in ${DATA_FILES} ; do
    if [ ! -r "${CUR_FILE}" ] ; then
      LogError "The file \"${CUR_FILE}\" does not exist"
      ERRORS_FOUND=${__TRUE}
    else
      LogMsg "OK, the file \"${CUR_FILE}\" exists"
    fi
  done

  if [ "${SQLITE3}"x != ""x ] ; then
    if [ ! -x "${SQLITE3}" ] ; then
      SQLITE3=""
    fi
  fi
  
  if [ "${SQLITE3}"x = ""x ] ; then
    LogMsg "Searching the sqlite3 binary in /data/adb/ ..."
    SQLITE3="$( find /data/adb/ -name sqlite3 -executable | head -1 )"
  fi

  if [ "${SQLITE3}"x = ""x ] ; then
    LogMsg "Searching the sqlite3 binary in /sdcard/Download/ ..."
    SQLITE3="$( find /sdcard/Download/ -name sqlite3 -executable | head -1 )"
  fi

  if [ "${SQLITE3}"x != ""x ] ; then
    LogMsg "Using the sqlite3 executable \"${SQLITE3}\" "
  elif [ ! -x "${MAGISK}" ] ; then
    LogError "The Magisk binary does not exist"
  else
    LogMsg "No sqlite3 executable found - using the binary \"${MAGISK}\" to process the Magisk database"    

    LogMsg "Checking if the Magisk daemon is already running ..."
    ${MAGISK} -v 
    if [ $? -eq 0 ] ; then
      LogMsg "OK, the Magisk daemon is already running"
    else
      LogMsg "The Magisk daemon is not running -- starting the Magisk Daemon now ..."
      ${MAGISK} --daemon
      
      LogMsg "Checking if the Magisk daemon start was successfull ..."
      ${MAGISK} -v 
      if [ $? -eq 0 ] ; then
        LogMsg "OK, the Magisk daemon is now running"      
      else
        LogError "Error starting the Magisk daemon"
        ERRORS_FOUND=${__TRUE}
      fi
    fi
  fi
     
  if [ $# -eq 0 ] ; then
    LogError "No parameter found"
    ERRORS_FOUND=${__TRUE}
  fi

  if [ ${ERRORS_FOUND} = ${__TRUE} ]; then
    LogError "One or more errors found -- will exit now"
    THISRC=${__FALSE}
  fi

fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then

  LogMsg "Checking the parameter ..."

  for CUR_PARAM in $* ; do
    case ${CUR_PARAM} in
    
      -f | --force )
        FORCE=${__TRUE}
        ;;

      +f | ++force )
        FORCE=${__FALSE}
        ;;

       * )
        [[ ${CUR_PARAM} = apps=* ]] && CUR_PARAM="${CUR_PARAM#*=}"
        
        for CUR_APP in $( echo "${CUR_PARAM}" | tr "," " " ) ; do
          isNumber "${CUR_APP}"
          if [ $? -ne 0 ] ; then
            if [ ${RUNNING_IN_TWRP} = ${__TRUE} ] ; then
              LogError "\"${CUR_APP}\" is not a number"
              ERRORS_FOUND=${__TRUE}
            else
              CUR_UID="$( pm list packages -U  | grep ":${CUR_APP} " | cut -f3 -d":" )"
              if [ "${CUR_UID}"x != ""x ] ; then
                isNumber "${CUR_UID}"
                if [ $? -eq 0 ] ; then
                  LogMsg "The UID for \"${CUR_APP}\" is \"${CUR_UID}\" "
                  LIST_OF_UIDS="${LIST_OF_UIDS} ${CUR_UID}"
                else
                  CUR_UID=""
                fi
              fi
  
              if [ "${CUR_UID}"x = ""x ] ; then
                LogError "\"${CUR_APP}\" is not a number and not an known app name"
                ERRORS_FOUND=${__TRUE}
              fi
            fi           
          else
            LogMsg "The parameter \"${CUR_APP}\" is okay"
            LIST_OF_UIDS="${LIST_OF_UIDS} ${CUR_APP}"
          fi
        done
        ;;
    esac
  done

  if [ ${ERRORS_FOUND} = ${__TRUE} ]; then
    LogError "One or more invalid parameter found -- will exit now"
    THISRC=${__FALSE}
  else
    LogMsg "OK, all parameter are okay"
  fi

fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then

  CUR_MAGISK_VERSION="$( ${MAGISK} -c | cut -f1 -d ":"  )"

  if [[ " ${KNOWN_MAGISK_VERSIONS} " == *\ ${CUR_MAGISK_VERSION}\ * ]] ; then
    LogMsg "OK, the installed Magisk version \"${CUR_MAGISK_VERSION}\" is supported"
  else
    if [ ${FORCE} = ${__TRUE} ] ; then
      LogMsg "The installed Magisk version \"${CUR_MAGISK_VERSION}\" is not tested but the parameter \"-f\" was used"
    else
      LogError "The installed Magisk version \"${CUR_MAGISK_VERSION}\" is not tested (use the parameter \"-f\" to continue anyway)"
      LogMsg "The supported Magisk versions are: \"${KNOWN_MAGISK_VERSIONS}\" "
      THISRC=${__FALSE}
    fi
  fi
fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  LogMsg "Creating a backup of the existing Magisk database in \"${MAGISK_DATABASE_BACKUP}\" ..."

  CUR_OUTPUT="$( cp "${MAGISK_DATABASE}" "${MAGISK_DATABASE_BACKUP}" 2>&1 )"
  TEMPRC=$?
  
  if [ ${TEMPRC} != 0 ] ; then
    LogMsg "${CUR_OUTPUT}"
    die 15 "Error creating a backup of the existing Magisk database in \"${MAGISK_DATABASE_BACKUP}\" "
  fi
fi

if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
  LogMsg ""
  LogMsg "Reading the current entries from the Magisk database ..."

  read_magisk_policies_database || die 10 "Can not read the Magisk database"
  
  print_magisk_policies

  LogMsg ""
  LogMsg "Enabling the root access for these app UIDs: ${LIST_OF_UIDS} "
    
  UID_WITH_ENABLED_ROOT_ACCESS=""
  NO_OF_UID_WITH_ENABLED_ROOT_ACCESS=0
  
  UID_WITH_NOT_ENABLED_ROOT_ACCESS=""
  NO_OF_UID_WITH_NOT_ENABLED_ROOT_ACCESS=0
  
  UID_WITH_ALREADY_ENABLED_ROOT_ACCESS=""
  NO_OF_UID_WITH_ALREADY_ENABLED_ROOT_ACCESS=0
  
  for CUR_UID in ${LIST_OF_UIDS} ; do
    LogMsg ""
    LogMsg "Processing the UID \"${CUR_UID}\" ..."

    if [[ " ${UID_WITH_ENABLED_ROOT_ACCESS} " == *\ ${CUR_UID}\ * ]] ; then
      LogMsg "This a duplicate entry -- the UID was already processed"
      continue
    fi
    
    TEMPRC=""

    get_root_status_for_existing_entry "${CUR_UID}"

# global varialbes set by get_root_status_for_existing_entry are:
#
#  DATABASE_ENTRY
#  DATABASE_ENTRY_FOUND
#  DATABASE_ENTRY_STATUS
#

    if [ ${DATABASE_ENTRY_FOUND} = ${__TRUE} ] ; then
      LogMsg "The entry for the UID \"${CUR_UID}\" already exists in the Magisk database:"
      
      if [ "${DATABASE_ENTRY_STATUS}"x = "2"x ] ; then
        LogMsg "OK, root access is already enabled for the UID \"${CUR_UID}\" "

       UID_WITH_ALREADY_ENABLED_ROOT_ACCESS="${UID_WITH_ALREADY_ENABLED_ROOT_ACCESS} ${CUR_UID}"
       (( NO_OF_UID_WITH_ALREADY_ENABLED_ROOT_ACCESS = NO_OF_UID_WITH_ALREADY_ENABLED_ROOT_ACCESS + 1 ))

      else
        LogMsg "root acces for the UID \"${CUR_UID}\" is not enabled -- enabling root access for the UID \"${CUR_UID}\" now ..."

        enable_root_for_existing_entry "${CUR_UID}"
        TEMPRC=$?
      fi
    else
      LogMsg "Enabling root access for the UID \"${CUR_UID}\" now ..."

      enable_root_for_new_entry "${CUR_UID}"
      TEMPRC=$?
    fi

    if [ "${TEMPRC}"x != ""x ] ; then

      if [ ${TEMPRC} = ${__TRUE} ] ; then
        LogMsg "OK, root access successfully enabled for the UID \"${CUR_UID}\""

        UID_WITH_ENABLED_ROOT_ACCESS="${UID_WITH_ENABLED_ROOT_ACCESS} ${CUR_UID}"
        (( NO_OF_UID_WITH_ENABLED_ROOT_ACCESS = NO_OF_UID_WITH_ENABLED_ROOT_ACCESS + 1 ))

      else
        LogError "Error enabling root access for the UID \"${CUR_UID}\" "

        UID_WITH_NOT_ENABLED_ROOT_ACCESS="${UID_WITH_NOT_ENABLED_ROOT_ACCESS} ${CUR_UID}"
        (( NO_OF_UID_WITH_NOT_ENABLED_ROOT_ACCESS = NO_OF_UID_WITH_NOT_ENABLED_ROOT_ACCESS + 1 ))

      fi    
    fi
    
  done
  
  LogMsg ""
  LogMsg "Summary"

  if [ ${NO_OF_UID_WITH_ENABLED_ROOT_ACCESS} != 0 ] ; then
    LogMsg ""
    LogMsg "root access enabled for ${NO_OF_UID_WITH_ENABLED_ROOT_ACCESS} UID(s):"
    LogMsg "  ${UID_WITH_ENABLED_ROOT_ACCESS}"
  fi

  if [ ${NO_OF_UID_WITH_ALREADY_ENABLED_ROOT_ACCESS} != 0 ] ; then
    LogMsg ""
    LogMsg "root access was already enabled for ${NO_OF_UID_WITH_ALREADY_ENABLED_ROOT_ACCESS} UID(s):"
    LogMsg "  ${UID_WITH_ALREADY_ENABLED_ROOT_ACCESS}"
  fi

  if [ ${NO_OF_UID_WITH_NOT_ENABLED_ROOT_ACCESS} != 0 ] ; then
    LogMsg ""
    LogMsg "root access could not be enabled for ${NO_OF_UID_WITH_NOT_ENABLED_ROOT_ACCESS} UID(s):"
    LogMsg "  ${UID_WITH_NOT_ENABLED_ROOT_ACCESS}"
  fi

  LogMsg ""

  print_magisk_policies
  
  LogMsg ""
  
fi

exit ${THISRC}
