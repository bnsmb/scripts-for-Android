#!/system/bin/sh
#h#
#h# change_os_build_date.sh #VERSION# - change the properties for the build date of the running OS
#h#
#h# Usage: change_os_build_date.sh  [-h|--help] [-H] [-d|--dryrun] [-v|--verbose] [-V|--version] [var=value] [-l|--list] [new_date|os_image_file]
#h#
#H# Known parameter:
#H# 
#H# -h               print the short usage help
#H# -H               print the detailed usage help
#H# -d               run the script in dry-run mode
#H# -v               print more messages
#H# -V               print the script version and exit
#H# var=value        set the variable "var" to the value "value"
#H# -l               only print the current values
#H# new_date         new build date (this value is the number of seconds since 1970)
#H# os_image_file    ZIP file with an OS image for the phone
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
# main function


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

    -l|--list )
      VIEW_ONLY=${__TRUE}
      ;;

    --* | -* )
      die 17 "Unknown option found in the parameter: \"${CUR_PARAMETER}\")"
      ;;

    
    *  )
      if [ "${NEW_DATE}"x != ""x ]  ; then
        die 19 "Unknown parameter found: \"${CUR_PARAMETER}\")"
      else 
        NEW_DATE="${CUR_PARAMETER}"
      fi
      ;;

  esac
done


# ---------------------------------------------------------------------

if [ "${PREFIX}"x != ""x ] ; then
  LogMsg ""
  LogMsg "*** The script is running in dry-run mode: PREFIX is \"${PREFIX}\" "
  LogMsg ""
fi

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

GETPROP="$( which getprop )"

if [ "${GETPROP}"x = ""x ] ; then
  die 105 "Executable \"getprop\" not found -- is the script running in Android?"
fi

RESETPROP="$( which resetprop )"

if [ "${RESETPROP}"x = ""x ] ; then
  die 107 "Executable \"resetprop\" not found -- is Magisk installed?"
fi

# ---------------------------------------------------------------------
# check the parameter
#

IMAGE_FILE_USED=${__FALSE}

if [ "${NEW_DATE}"x = ""x -a ${VIEW_ONLY} != ${__TRUE} ] ; then
  die 109 "The parameter for the new date is missing"
fi
  
if ! isNumber "${NEW_DATE}" ; then
  if [ ! -r "${NEW_DATE}" ] ; then
    die 111 "\"${NEW_DATE}\" is neither a number nor a file name"
  else
    LogMsg "Reading the new date from the file \"${NEW_DATE}\" ..."
    TEST_DATE="$( unzip -p "${NEW_DATE}" META-INF/com/android/metadata | grep post-timestamp= | cut -f2 -d "=" )"
    if [ $? -ne 0 ] ; then 
      die 113 "Error reading the file \"${NEW_DATE}\" "
    elif [ "${TEST_DATE}"x = ""x ] ; then
      die 115 "The file \"${NEW_DATE}\" is not a valid OS image"
    else
      IMAGE_FILE_USED=${__TRUE}
      OS_IMAGE_FILE="${NEW_DATE}"

      NEW_DATE="${TEST_DATE}"
    fi
  fi
fi

LogMsg "Using tne new date \"${NEW_DATE}\""

LogMsg "Retrieving the list of date properties in the running OS ..."

GET_DATE_UTC_PROPERTIES="$( ${GETPROP} | grep date.utc |   tr -d "[]" | cut -f1 -d ":" )"

if [ "${GET_DATE_UTC_PROPERTIES}"x = ""x ]  ; then
  die 117 "No date properties found"
fi

LogMsg "The current values of the date properties are:" 
LogMsg 
for CUR_PROP in ${GET_DATE_UTC_PROPERTIES} ; do 
  LogMsg "${CUR_PROP} : $( ${GETPROP} ${CUR_PROP}  )"
done
LogMsg 

OS_BUILD_DATE="$( ${GETPROP} ro.build.date.utc )"
if [ "${OS_BUILD_DATE}"x != ""x ] ; then
  LogMsg "The build date of the running OS is \"${OS_BUILD_DATE}\" ( $( date -u -d   @${OS_BUILD_DATE} ) )"
fi

if [ ${VIEW_ONLY} != ${__TRUE} ] ; then

  LogMsg "Changing the value for the date properties to \"${NEW_DATE}\" ( $( date -u -d   @${NEW_DATE} ) ) ..."

  for CUR_PROP in ${GET_DATE_UTC_PROPERTIES} ; do 
    ${RESETPROP} "${CUR_PROP}" "${NEW_DATE}"
  done

  LogMsg "The values of the date properties are now:" 
  LogMsg 
  for CUR_PROP in ${GET_DATE_UTC_PROPERTIES} ; do 
    LogMsg "${CUR_PROP} : $( ${GETPROP} ${CUR_PROP}  )"
  done
  LogMsg 
else

  if [ ${IMAGE_FILE_USED} = ${__TRUE} ] ; then
    if [ "${OS_BUILD_DATE}"x != ""x  -a  "${NEW_DATE}"x != ""x  ] ; then
      LogMsg
      (( DIFF = NEW_DATE - OS_BUILD_DATE ))
      if [ ${DIFF} -ge 0 ] ; then
        LogMsg "OK, the installation of the image file \"${OS_IMAGE_FILE}\" should work without changing the date properties"
      else
        LogMsg "The installation of the image file \"${OS_IMAGE_FILE}\" requires new values for the date properties"
      fi
    fi
  fi
  
fi

return ${THISRC}

