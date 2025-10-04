#!/system/bin/sh
#h#
#h# change_os_build_date.sh #VERSION# - change the properties for the build date of the running OS
#h#
#h# Usage: change_os_build_date.sh  [-h|--help] [-H] [-d|--dryrun] [-v|--verbose] [-V|--version] [var=value] [-l|--list] [--spl|--spl=[date|file|logcat]] [new_date|os_image_file|logcat]
#h#
#H# Known parameter:
#H# 
#H# -h                   print the short usage help
#H# -H                   print the detailed usage help
#H# -d                   run the script in dry-run mode
#H# -v                   print more messages
#H# -V                   print the script version and exit
#H# var=value            set the variable "var" to the value "value"
#H# -l                   only print the current values
#H# --spl=[value]        correct the SPL (Security Patch Level) in the OS; the format for the "value" is either "yyyy-mm-dd"
#H#                      or "file" = read the SPL from the OS image file; 
#H#                      or "logcat" = read the SPL from the last error message from the update_engine in the logcat
#H# --spl                correct the SPL in the OS using the SPL from the file or from the logcat (depending on the other parameter)
#H# new_date             new build date (this value is the number of seconds since 1970)
#H# os_image_file        ZIP file with an OS image for the phone
#H# logcat               use the date found in the last error message from the update_engine in the logcat
#H#
#H# Return codes:
#H#
#H#   0 - properties updated or listed
#H#   else error
#H#
#H# Set the variable PREFIX to "echo" or something similar to run the script in dry-run mode
#H# Set the environment variable TRACE to any value to run the script with "set -x"
#H#
#
#
# Lines beginning with #h# are printed if the script is executed with the parameter "-h", "--help" or "-H"
#
# Lines beginning with #H# are printed if the script is executed with the parameter "-H"
#
# Author
#   Bernd Schemmer (bernd dot schemmer at gmx dot de)
#
# History
#   15.09.2025 /bs v1.0.0
#     initial release
#   16.09.2025 /bs v1.1.0
#     added the parameter logcat
#   30.09.2025 /bs v1.2.0
#     added code to also change the SPL
#     added the parameters --spl and --spl=value
#

# ----------------------------------------------------------------------
# define constants
#

__TRUE=0
__FALSE=1

# ---------------------------------------------------------------------
# global variables
#

PLAYSTORE_APP="com.android.vending"

# Script return code
#
THISRC=0

SCRIPT_PARAMETER="$*"

# ----------------------------------------------------------------------
# enable tracing if requested
#
if [ "${TRACE}"x != ""x ] ; then
  set -x
elif [[ $- == *x* ]] ; then
#
# tracing is already enabled 
#
  TRACE=${__TRUE}
fi

# ----------------------------------------------------------------------
# enable verbose mode if requested
#

if [[ " $* " == *\ -v\ * || " $* " == *\ --verbose\ *  ]] ; then
  VERBOSE=${__TRUE}
fi

# ----------------------------------------------------------------------
# install a trap handler for house keeping
#
trap "cleanup"  0

# ----------------------------------------------------------------------
# read the script version from the source code
#
SCRIPT_VERSION="$( grep  "^#" $0 | grep "/bs v"  | tail -1 | sed "s#.*v#v#g" )"

# ---------------------------------------------------------------------
# aliase
#
alias LogInfoVar='f() { [[ ${__FUNCTION} = "" ]] && __FUNCTION=main ; [[ ${VERBOSE} != 0 ]] && return; varname="$1"; eval "echo \"INFO: in $__FUNCTION:  $varname ist \${$varname}\" >&2"; unset -f f; } ;  f'

# ---------------------------------------------------------------------
# functions

# ---------------------------------------------------------------------
# LogMsg - write a message to STDOUT
#
# Usage: LogMsg [message]
#
function LogMsg {
  typeset __FUNCTION="LogMsg"
  
  typeset THISMSG="$@"

  echo "${THISMSG}"

  return ${__TRUE}
}

# ---------------------------------------------------------------------
# LogInfo - write a message to STDERR if VERBOSE is ${__TRUE}
#
# Usage: LogInfo [message]
#
# The function  returns ${__TRUE} if the message was written and
# ${__FALSE} if the message was not written
#
function LogInfo { 
  typeset __FUNCTION="LogInfo"

  [[ ${VERBOSE} == ${__TRUE} ]] && LogMsg "INFO: $@" >&2 || return ${__FALSE}
}

# ---------------------------------------------------------------------
# LogWarning - write a warning message to STDERR
#
# Usage: LogWarning [message]
#
function LogWarning {
  typeset __FUNCTION="LogWarning"

  LogMsg "WARNING: $@" >&2
}


# ---------------------------------------------------------------------
# LogError - write an error message to STDERR
#
# Usage: LogError [message]
#
function LogError {
  typeset __FUNCTION="LogError"

  LogMsg "ERROR: $@" >&2
}


# ---------------------------------------------------------------------
# die - end the program
#
# Usage:
#  die [returncode] [message]
# 
# returns:
#   n/a
#
function die {
  typeset __FUNCTION="die"

  typeset THISRC="$1"

  [ "${THISRC}"x = ""x ] && THISRC=0

  [ $# -gt 0 ] && shift

  typeset THISMSG="$*"
  
  if [ ${THISRC} -le 4 ] ; then
    [ "${THISMSG}"x != ""x ] && LogMsg "${THISMSG} (RC=${THISRC})"
  else
    LogError "${THISMSG} (RC=${THISRC})"
  fi

  exit ${THISRC}
}


# ---------------------------------------------------------------------
# cleanup - house keeping at script end
#
# Usage:
#  cleanup
# 
# returns:
#   this function is used as trap handler to cleanup the environment
#
function cleanup {

  LogInfo "cleanup from $0 is running ..."

#
# remove the trap handler
#
  trap ""  0

  if [ "${PREFIX}"x != ""x ] ; then
    LogMsg ""
    LogMsg "*** The variable PREFIX is defined (PREFIX=\"${PREFIX}\") -- the script was executed in dry-run mode"
  fi

  LogMsg ""
  
# cleanup the environment 

}

# ----------------------------------------------------------------------
# isNumber
#
# check if a value is an integer
#
# usage: isNumber testValue
#
# returns: ${__TRUE} - testValue is a number else not
#
function isNumber {

# this code does not work in the sh in Android
#  [[ $1 == +([0-9]) ]] && THISRC=${__TRUE} || THISRC=${__FALSE}

# old code:
  if [ "$1"x != ""x ] ; then
    TESTVAR="$(echo "$1" | sed 's/[0-9]*//g' )"
    [ "${TESTVAR}"x = ""x ] && return ${__TRUE} || return ${__FALSE}
  fi
  
  return ${__FALSE}
}


# ----------------------------------------------------------------------
# print_date_values
#
# print the current values for the date properties
#
# usage: print_date_values [message]
#
# returns: ${__TRUE} 
#
function print_date_values {
  typeset THISRC=${__TRUE}
  
  typeset THIS_MSG="$*"
  typeset CUR_PROP=""
  
  if [ "${THIS_MSG}"x != ""x ] ; then
    LogMsg "${THIS_MSG}"
    LogMsg ""
  fi

  for CUR_PROP in ${GET_DATE_UTC_PROPERTIES}  ; do 
    LogMsg "${CUR_PROP} : $( ${GETPROP} ${CUR_PROP}  )"
  done
  LogMsg   

  CUR_PROP="ro.build.version.security_patch"

  if [ "${THIS_MSG}"x != ""x ] ; then
    LogMsg "The current SPL is: "
  fi
  
  LogMsg "${CUR_PROP} : $( ${GETPROP} ${CUR_PROP}  )"
  LogMsg   

   
  return ${THISRC}
}


# ----------------------------------------------------------------------
# read_date_from_logcat
#
# read the required date from the logcat messages
#
# usage: read_date_from_logcat [result_var]
#
# parameter:
#   result_var - name of the global variable for the date found in the logcat messags
#
# returns: ${__TRUE} - found a date in the logcat messages
#          ${__FALSE} - no date found in the logcat messages
#
function read_date_from_logcat {
  typeset THISRC=${__FALSE}
  
  typeset RESULT_VAR="$1"

  typeset LOGCAT_LINES_WITH_ERRORS=""
  typeset LOGCAT_LINE=""

  if [ "${RESULT_VAR}"x != ""x ] ; then
    unset ${RESULT_VAR}
  fi  

  LogMsg "Searching the new date in the logcat messages ..."
     
  LOGCAT_LINES_WITH_ERRORS="$( logcat -d | grep update_engine | grep  -E "Timestamp check failed with ErrorCode::kPayloadTimestampError:|is newer than the maximum timestamp in the manifest"  )"

  LogInfo "Error messages from the update_engine found in the logcat messages are: " && \
    LogMsg && \
    LogMsg "${LOGCAT_LINES_WITH_ERRORS}" && \
    LogMsg
    
  LOGCAT_LINE="$( echo "${LOGCAT_LINES_WITH_ERRORS}" | tail -1  )"
  if [ "${LOGCAT_LINE}"x = ""x ] ; then
    LogMsg "No update_engine error message regarding wrong timestamps found in the logcat messages"
  else
    LogMsg "Found this error message in the logcat messages:"
    LogMsg
    LogMsg "${LOGCAT_LINE}"

    if  [[ ${LOGCAT_LINE} == *Update\ timestamp* ]]; then
      TEST_DATE="$( echo "${LOGCAT_LINE}" | sed -e "s/.*Update timestamp: //g" -e "s/[[:space:]]//g"  )"
    else
      TEST_DATE="$( echo "${LOGCAT_LINE}" | sed "s/.*is newer than the maximum timestamp in the manifest//g" | tr -d " ()" )"
    fi
    
    if [ "${TEST_DATE}"x = ""x ] ; then
      LogError "No timestamp found in the error message from logcat messages"
    elif ! isNumber "${TEST_DATE}" ; then
      LogError "The timestamp found in the error message from logcat \"${TEST_DATE}\" is not a number"
    else
      LogMsg
      LogMsg "The date value in the logcat messages is: ${TEST_DATE} "
    
      if [ "${RESULT_VAR}"x != ""x ] ; then
        eval ${RESULT_VAR}="${TEST_DATE}"
      fi
      THISRC=${__TRUE}
    fi
  
  fi
  
  return ${THISRC}
}

# ----------------------------------------------------------------------
# read_date_from_image_file
#
# read the required date from the ZIP file with the OS image
#
# usage: read_date_from_image_file [zipfile] [result_var] [result_var_for_spl]
#
# parameter:
#   zipfile    - name of the ZIP file
#   result_var - name of the global variable for the date found in the logcat messags
#
# returns: ${__TRUE} - found a date in the zip file
#          ${__FALSE} - no date found in zip file
#
function read_date_from_image_file {
  typeset THISRC=${__FALSE}

  typeset THIS_FILE="$1"
  typeset RESULT_VAR="$2"
  typeset RESULT_VAR_FOR_SPL="$3"
  
  typeset THIS_DATE=""
  typeset THIS_SPL=""

  typeset THIS_METADATA=""
        
  if [ "$THIS_FILE}"x != ""x ] ; then
    LogMsg "Reading the new date from the image file \"${THIS_FILE}\" ..."
    if [ -r "${THIS_FILE}" ] ; then

      THIS_METADATA="$( unzip -p "${THIS_FILE}" META-INF/com/android/metadata )"
      if [ "${THIS_METADATA}"x = ""x ] ; then
        LogError "Error reading the metadata from the file \"${THIS_FILE}\" "
      else
      
        THIS_SPL="$( echo "${THIS_METADATA}" | grep post-security-patch-level= | cut -f2 -d"=" )"
   
        THIS_DATE="$( echo "${THIS_METADATA}" | grep post-timestamp= | cut -f2 -d "=" )"
        
        if [ "${THIS_DATE}"x = ""x ] ; then
          LogError "The file \"${THIS_FILE}\" is not a valid OS image"
        elif ! isNumber "${THIS_DATE}" ; then
          LogError "The timestamp found in the file \"${THIS_DATE}\" is not a number"
        else
          LogMsg
          
          LogMsg "The date value in the file \"${THIS_FILE}\" is : \"${THIS_DATE}\" "      
          if [ "${THIS_SPL}"x != ""x ] ; then
            LogMsg "The SPL (Security patch level) in the file \"${THIS_FILE}\" is : \"${THIS_SPL}\" "      
          fi  
          
          if [ "${RESULT_VAR}"x != ""x ] ; then
            eval ${RESULT_VAR}="${THIS_DATE}"
          fi

          if [ "${THIS_SPL}"x != ""x ] ; then
            eval ${RESULT_VAR_FOR_SPL}="${THIS_SPL}"
          fi

          THISRC=${__TRUE}
        fi  
      fi
    else
      LogError "The file \"${THIS_FILE}\" does not exist"
    fi
  else
    LogError "read_date_from_logcat: Filename missing"
  fi
  
  return ${THISRC}
}
  
# ---------------------------------------------------------------------
# main function

# ----------------------------------------------------------------------
# install the trap handler
#
trap "cleanup" 0

# ----------------------------------------------------------------------
#
if [ "${PREFIX}"x != ""x ] ; then
# 
# check mksh (in some mksh versions PREFIX is used for a directory name)
#
  if [ -d "${PREFIX}" ] ; then
    LogWarning "The variable PREFIX contains a directory name: \"${PREFIX}\" -- disabling dry-run mode now (use the parameter \"-d\" to enable dry-run mode"
    PREFIX=""
  fi
fi

# ---------------------------------------------------------------------



# ---------------------------------------------------------------------
# process the script parameter
#

LogInfo "Processing the parameter ..."

LogInfo "The parameter for the script are "  && \
  LogMsg "$*"

PRINT_USAGE_HELP=${__FALSE}

PRINT_DETAILED_USAGE_HELP=${__FALSE}

NEW_DATE=""

VIEW_ONLY=${__FALSE}

CHANGE_SPL=${__FALSE}
NEW_SPL=""

while [ $# -ne 0 ] ; do
  CUR_PARAMETER="$1"
  shift

  LogInfo "Processing the parameter \"${CUR_PARAMETER}\" ..."

  case  ${CUR_PARAMETER} in
  
    -h | --help )
      PRINT_USAGE_HELP=${__TRUE}
      ;;

    -H )
      PRINT_USAGE_HELP=${__TRUE}
      PRINT_DETAILED_USAGE_HELP=${__TRUE}
      ;;
  
    -d | --dryrun )
      PREFIX="echo"
      ;;

    --spl )
      CHANGE_SPL=${__TRUE}
      ;;

    --spl=* )
      CHANGE_SPL=${__TRUE}
      NEW_SPL="${CUR_PARAMETER#*=}"    
      ;;

    *=* )
      LogInfo "Executing now \"${CUR_PARAMETER}\" ..."
      eval ${CUR_PARAMETER}
      if [ $? -ne 0 ] ; then
        die 70 "Error executing \"${CUR_PARAMETER}\" "
      fi
      ;;

   -v | --verbose )
      VERBOSE=${__TRUE}
      ;;
       
   -V | --version )
      echo "${SCRIPT_VERSION}"
      die 0
      ;;

    -l | --list )
      VIEW_ONLY=${__TRUE}
      ;;

    --* | -* )
      die 17 "Unknown option found in the parameter: \"${CUR_PARAMETER}\" "
      ;;

       
    *  )
      if [ "${NEW_DATE}"x != ""x ]  ; then
        die 19 "Unknown parameter found: \"${CUR_PARAMETER}\" "
      else 
        NEW_DATE="${CUR_PARAMETER}"
      fi
      ;;

  esac
done

# ---------------------------------------------------------------------

if [ ${PRINT_USAGE_HELP} = ${__TRUE} ] ; then
  grep "^#h#" $0 | cut -c4- | sed \
        -e "s/#VERSION#/${SCRIPT_VERSION}/g" 
  
  if [ ${PRINT_DETAILED_USAGE_HELP} = ${__TRUE} ] ;then
    grep "^#H#" $0 | cut -c4- 
  else
    echo " Use the parameter \"-H\" to print the detailed usage help"
  fi
              
  die 0
fi

# ---------------------------------------------------------------------
# check pre-requisites for the script
#
THIS_USER=$( id -un )

if [ "${THIS_USER}"x != "root"x ] ; then

# check for root access via su
#
  su - -c id 2>/dev/null >/dev/null
  if [ $? -eq 0 ] ; then
   echo "Restarting the script as user \"root\" ..."
#
# root access via su is workgin
#
    exec su - -c $0 ${SCRIPT_PARAMETER}
  
    die 200 "Restarting the script as user \"root\" via \"su - -c $0 $*\" failed"
  else
    die 100 "This script needs root access rights (the current user is \"${THIS_USER}\")"
  fi
fi

# ---------------------------------------------------------------------

if [ "${PREFIX}"x != ""x ] ; then
  LogMsg ""
  LogMsg "*** The script is running in dry-run mode: PREFIX is \"${PREFIX}\" "
  LogMsg ""
fi

# ---------------------------------------------------------------------

GETPROP="$( which getprop )"

if [ "${GETPROP}"x = ""x ] ; then
  die 105 "Executable \"getprop\" not found -- is the script running in Android?"
fi

RESETPROP="$( which resetprop )"

if [ "${RESETPROP}"x = ""x ] ; then
  die 107 "Executable \"resetprop\" not found -- is Magisk installed?"
fi

# ---------------------------------------------------------------------

LogMsg "Retrieving the list of date properties in the running OS ..."

GET_DATE_UTC_PROPERTIES="$( ${GETPROP} | grep date.utc |   tr -d "[]" | cut -f1 -d ":" )"

if [ "${GET_DATE_UTC_PROPERTIES}"x = ""x ]  ; then
  die 109 "No date properties found"
fi

# ---------------------------------------------------------------------
# check the parameter
#
IMAGE_FILE_USED=${__FALSE}

if [ ${CHANGE_SPL} = ${__TRUE} ] ; then
  case ${NEW_SPL} in 
    logcat | file )
      :
      ;;

   ????-??-?? )
      :
      ;;

   "" )
      :
      ;;

    * )
      die 110 "The value for the parameter \"--spl\" is invalid: \"${NEW_SPL}\" "
      ;;
  esac
fi

print_date_values "The current values of the date properties are:" 

OS_BUILD_DATE="$( ${GETPROP} ro.build.date.utc )"
if [ "${OS_BUILD_DATE}"x != ""x ] ; then
  LogMsg "The build date of the running OS is \"${OS_BUILD_DATE}\" ( $( date -u -d   @${OS_BUILD_DATE} ) )"
fi

if [ "${NEW_DATE}"x = ""x ] ; then
  if [ ${VIEW_ONLY} != ${__TRUE} ] ; then
    die 111 "The parameter for the new date is missing"
  else 
    die 0
  fi
fi

if [ "${NEW_DATE}"x = "logcat"x ] ; then
  read_date_from_logcat NEW_DATE
  if [ $? -ne ${__TRUE} ] ; then
    die 113 "No update_engine error message regarding wrong timestamps found in the logcat"
  fi  
  [ "${NEW_SPL}"x = ""x ] &&  NEW_SPL="logcat"    
  
elif isNumber "${NEW_DATE}" ; then
  :
  
elif [ -r "${NEW_DATE}" ] ; then
  OS_IMAGE_FILE="${NEW_DATE}"
  LogMsg
  read_date_from_image_file "${OS_IMAGE_FILE}" NEW_DATE SPL_IN_ZIP_FILE
  if [ $? -ne ${__TRUE} ] ; then    
    die 115 "No date found in the file \"${OS_IMAGE_FILE}\" "
  fi  
  [ "${NEW_SPL}"x = ""x ] &&  NEW_SPL="file"    
  
else
  die 117 "\"${NEW_DATE}\" is neither a number nor the name of an existing file"
fi


if [ ${VIEW_ONLY} = ${__TRUE} ] ; then
  LogMsg 
  LogMsg "Tne maximum value for the date properties is ${NEW_DATE} ( $( date -u -d   @${NEW_DATE} ) )"

  if [ "${OS_BUILD_DATE}"x != ""x  -a  "${NEW_DATE}"x != ""x  ] ; then
    LogMsg
    (( DIFF = NEW_DATE - OS_BUILD_DATE ))
    if [ ${DIFF} -ge 0 ] ; then
      LogMsg "OK, the installation of the image file should work without changing the date properties"
    else
      LogMsg "The installation of the image file requires new values for the date properties"
    fi
  fi
else  

  LogMsg 
  LogMsg "Using the new date \"${NEW_DATE}\""
  LogMsg
  LogMsg "Changing the value for the date properties to \"${NEW_DATE}\" ( $( date -u -d   @${NEW_DATE} ) ) ..."

  for CUR_PROP in ${GET_DATE_UTC_PROPERTIES} ; do 
    ${PREFIX} ${RESETPROP} "${CUR_PROP}" "${NEW_DATE}"
  done
 
  if [ ${CHANGE_SPL} = ${__TRUE} ] ; then
   
    if [ "${NEW_SPL}"x = "file"x ] ; then 
      if [ "${SPL_IN_ZIP_FILE}"x != ""x ] ; then
        NEW_SPL="${SPL_IN_ZIP_FILE}"
      else
        LogError "No value for the SPL found in the file \"${OS_IMAGE_FILE}\""
      fi
    elif [ "${NEW_SPL}"x = "logcat"x ] ; then 

      CUR_LINE="$( logcat -d | grep "Target build SPL" | tail -1 )"
      if [ "${CUR_LINE}"x != ""x ] ; then
        CUR_LINE="${CUR_LINE#*Target build SPL}"
        CUR_LINE="${CUR_LINE%is older than*}"
        if [ "${CUR_LINE}"x = ""x ] ; then
          LogError "WARNING: Invalid SPL downgrade message found in logcat - use the parameter \"--spl=date\" "
          NEW_SPL=""
        fi
      else      
         LogError "WARNING: No SPL downgrade message found in logcat  - use the parameter \"--spl=date\" "
         NEW_SPL=""
      fi
    fi

    if [ "${NEW_SPL}"x != ""x ] ; then 
      LogMsg "Changing the current SPL to \"${NEW_SPL}\" ..."
      ${PREFIX} ${RESETPROP} "ro.build.version.security_patch" "${NEW_SPL}"
    fi     
  fi

  LogMsg
  print_date_values "The values of the date properties are now:" 
  
fi

return ${THISRC}

