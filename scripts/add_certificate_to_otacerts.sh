#!/system/bin/sh
#h#
#h# add_certificate_to_otacerts.sh #VERSION# - add the certificate from an OS image file to the file /system/etc/security/otacerts.zip
#h#
#h# Usage: add_certificate_to_otacerts.sh  [-h|--help] [-H] [-d|--dryrun] [-u|--no_umount] [-w|--workdir workdir] [-v|--verbose] [-V|--version] [var=value] [os_image_file] [...]
#h#
#H# Known parameter:
#H# 
#H# -h               print the short usage help
#H# -H               print the detailed usage help
#H# -d               run the script in dry-run mode
#H# -u               do not try to umount /system/etc/security/otacerts.zip
#H# -w               use the working directory "workdir"
#H# -v               print more messages
#H# -V               print the script version and exit
#H# var=value        set the variable "var" to the value "value"
#H# os_image_file    ZIP file with an OS image for the phone or a directory with ZIP files with OS images
#H#
#H# Return codes:
#H#
#H#   0 - one or more certificates successfully added
#H#   1 - no ZIP file with a certificate found
#H#   else error
#H#
#H# Set the environment variable PREFIX to "echo" or something similar to run the script in dry-run mode
#H#  In dry-run mode everything is done execpt for replacing the file /system/etc/security/otacerts.zip
#H# Set the environment variable TRACE to any value to run the script with "set -x"
#H#
#H# The scripts supports zip and 7zz to add the certificate to the zip file. The binaries is searched in the PATH and, if not found, in /data/local/tmp.
#H# The script needs root access.
#H#
#H# The default working directory is /tmp/certs. If the directory /tmp does not exist, the script 
#H# creates a the directory /sdcard/tmp and mounts it to tmpfs; in this case the default working 
#H# directory is /sdcard/tmp/certs.
#H#
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
#   30.09.2025 /bs v1.0.0
#     initial release
#   05.11.2025 /bs v1.1.0
#     the script now handles ZIP files with missing PEM files (unzip -p ends with a return value of 0, even if no file was extracted  )
#     the script now also supports 7zz for adding the new certificate to the zip file  
#

# ----------------------------------------------------------------------
# define constants
#

__TRUE=0
__FALSE=1

# ---------------------------------------------------------------------
# global variables
#

# Script return code
#
THISRC=1

SCRIPT_PARAMETER="$*"


ZIP="$( which zip )"

ZIP="${ZIP:=/data/local/tmp/zip}"

_7ZZ="$( which 7zz )"
_7ZZ="${_7ZZ:=/data/local/tmp/7zz}"

OTACERTS_ZIP_FILE_NAME="otacerts.zip"

OTACERTS_ZIP_FILE="/system/etc/security/${OTACERTS_ZIP_FILE_NAME}"

WORKDIR=""

# IMPORTANT: The work directory must be readable by ANY user!
#
DEFAULT_WORKDIR="/tmp/certs"

# temporary directory used if /tmp does not exist
#
DEFAULT_NEWTMPDIR="/sdcard/tmp"

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
: ${SCRIPT_VERSION:=can not find the script version -- please check the source code of $0}

# script name and directory
#
typeset -r SCRIPT_NAME="${0##*/}"
typeset SCRIPT_DIR="${0%/*}"
if [ "${SCRIPT_NAME}"x = "${SCRIPT_DIR}"x ] ; then
  SCRIPT_DIR="$( whence ${SCRIPT_NAME} )"
  SCRIPT_DIR="${SCRIPTDIR%/*}"
fi  
REAL_SCRIPT_DIR="$( cd -P ${SCRIPT_DIR} ; pwd )"
REAL_SCRIPT_NAME="${REAL_SCRIPT_DIR}/${SCRIPT_NAME}"

CUR_SHELL="$( head -1 "${REAL_SCRIPT_NAME}" | cut -f1 -d " " | cut -c3- )"

WORKING_DIR="$( pwd )"

THIS_USER="$( id -un )"

THIS_PID="$$"

PARENT_PROGRAM="$( ps -p $PPID -o name | tail -1 )"

TMP_PID="$( ps -p $PPID -o PID | tail -1 )"

GRAND_PARENT_PROGRAM="$( ps -p ${TMP_PID} -o name | tail -1 )"

while [ "${GRAND_PARENT_PROGRAM}"x = "sh"x ] ; do
  TMP_PID="$( ps -p ${TMP_PID} -o PPID | tail -1 )"
  GRAND_PARENT_PROGRAM="$( ps -p ${TMP_PID} -o name | tail -1 )"
done

[ "${GRAND_PARENT_PROGRAM}"x != "sh"x ] && GRAND_PARENT_PID=$( echo ${TMP_PID} ) || GRAND_PARENT_PID=""

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
  typeset __FUNCTION="cleanup"

  LogInfo "cleanup from \"${SCRIPT_NAME}\" is running ..."

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
  typeset __FUNCTION="isNumber"

  typeset TESTVAR=""
  
# this code does not work in the sh in Android
#  [[ $1 == +([0-9]) ]] && THISRC=${__TRUE} || THISRC=${__FALSE}

# old code:
  if [ "$1"x != ""x ] ; then
    TESTVAR="$(echo "$1" | sed 's/[0-9]*//g' )"
    [ "${TESTVAR}"x = ""x ] && return ${__TRUE} || return ${__FALSE}
  fi
  
  return ${__FALSE}
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
# process the script parameter
#

LogInfo "Processing the parameter ..."

LogInfo "The parameter for the script are "  && \
  LogMsg "$*"

PRINT_USAGE_HELP=${__FALSE}

PRINT_DETAILED_USAGE_HELP=${__FALSE}

NEW_DATE=""

VIEW_ONLY=${__FALSE}

ZIP_FILES=""

UMOUNT_OTACERTS_ZIP=${__TRUE}

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

    -u | --no_umount  | --noumount )
      UMOUNT_OTACERTS_ZIP=${__FALSE}
      ;;

    -w | --workdir )
      if [ $# -ne 0 ] ; then
        WORKDIR="$1"
        shift
      else
        die 71 "The parameter \"-w\" is incomplete"
      fi
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

    --* | -* )
      die 17 "Unknown option found in the parameter: \"${CUR_PARAMETER}\" "
      ;;

     * )
      ZIP_FILES="${ZIP_FILES} ${CUR_PARAMETER}"
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
    echo "Use the parameter \"-H\" to print the detailed usage help"
  fi
              
  die 0
fi

# ---------------------------------------------------------------------
# check pre-requisites for the script
#
THIS_USER=$( id -un )

# ROOT_PREFIX=""

if [ "${THIS_USER}"x != "root"x ] ; then
  
# check for root access via su
#

  su - -c id 2>/dev/null >/dev/null
  if [ $? -eq 0 ] ; then

#    ROOT_PREFIX="su - -c "

    echo "Restarting the script as user \"root\" ..."

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

# ---------------------------------------------------------------------

if [ ! -x "${ZIP}" ] ; then
  if [ ! -x "${_7ZZ}" ] ; then
    die 10 "No zip executable found"
  else
    PACKPROG="7zz"
  fi
else
  PACKPROG="zip"
fi

# ---------------------------------------------------------------------
# check if the file /system/etc/security/otacerts.zip is the original file
#      

  CUR_OUTPUT="$( mount | grep "${OTACERTS_ZIP_FILE}" 2>/dev/null | tail -1 )"
  if [ "${CUR_OUTPUT}"x != ""x  ] ; then
    OTACERTS_ALREADY_CHANGED=${__TRUE}
  else    
    OTACERTS_ALREADY_CHANGED=${__FALSE}
  fi

# ---------------------------------------------------------------------

LogMsg "
The certificates in the file \"${OTACERTS_ZIP_FILE}\" are:
"
unzip -l "${OTACERTS_ZIP_FILE}"

LogMsg

# ---------------------------------------------------------------------

if [ "${ZIP_FILES}"x = ""x  ] ; then

  if [ ${OTACERTS_ALREADY_CHANGED} != ${__TRUE} ] ; then
    LogMsg "This is the original file from the OS"
  else
    LogMsg "This is already a modified file (use \"su - -c umount ${OTACERTS_ZIP_FILE}\" to restore the original file)"
  fi
  LogMsg 
  die 0 "No parameter found - nothing to do"

else

# ---------------------------------------------------------------------
# set the working directory to be used
#
  if [ "${WORKDIR}"x = ""x ] ; then
    BASE_WORKDIR="$( echo ${DEFAULT_WORKDIR} | cut -f1,2 -d "/"  )"
    
    if [ -d "${BASE_WORKDIR}" ] ; then
      WORKDIR="${DEFAULT_WORKDIR}"
    else
      MOUNT_TMP_DIR=${__FALSE}
  
      LogMsg "The directory \"${DEFAULT_WORKDIR}\" does not exist - now creating the directory \"${DEFAULT_NEWTMPDIR}\" ..."
      if [ -d "${DEFAULT_NEWTMPDIR}" ] ; then
        TEMP_DEVICE="$( df -h "${DEFAULT_NEWTMPDIR}" | tail -1 | cut -f1 -d " " )"
        if [ "${TEMP_DEVICE}"x != "tmpfs"x ] ; then
          FILES_IN_NEWTMPDIR="$( ls "${DEFAULT_NEWTMPDIR}"  )"
          if [ "${FILES_IN_NEWTMPDIR}"x != ""x ] ; then
            die 108 "The directory \"${DEFAULT_NEWTMPDIR}\" exists and is not empty but is not mounted to tmpfs"
          else
            MOUNT_TMP_DIR=${__TRUE}      
          fi
        fi
      else
        MOUNT_TMP_DIR=${__TRUE}
      fi
       
      if [ ${MOUNT_TMP_DIR} = ${__TRUE} ] ; then
        ( set -x ;  mkdir -p "${DEFAULT_NEWTMPDIR}" &&  mount -t tmpfs tmpfs "${DEFAULT_NEWTMPDIR}"  ) || \
        die 107 "Can not create the temporary /tmp directory \"${DEFAULT_NEWTMPDIR}\""
      fi
      
      WORKDIR="${DEFAULT_NEWTMPDIR}/certs"
    fi
  fi
  LogMsg "Using the working directory \"${WORKDIR}\" "


# ---------------------------------------------------------------------

NEW_OTACERTS_ZIP_FILE="${WORKDIR}/${OTACERTS_ZIP_FILE_NAME}"

# ---------------------------------------------------------------------

# check for directories in the parameter
#
  LogMsg
  LogMsg "  --------------------------------------------------------------------- "
  LogMsg "Creating the list of ZIP files to process ..."
  LogMsg
  
  NEW_ZIP_FILES=""
  for CUR_ZIP_FILE in ${ZIP_FILES} ; do
    if [ -d "${CUR_ZIP_FILE}" ] ; then
      LogMsg "Adding all ZIP files in the directory \"${CUR_ZIP_FILE}\" ..."
      CUR_OUTPUT="$( ls "${CUR_ZIP_FILE}"/*.zip )"
      if [ "${CUR_OUTPUT}"x = ""x ] ; then
        LogMsg "No zip files found in the directory \"${CUR_ZIP_FILE}\" "
      else
        NEW_ZIP_FILES="${NEW_ZIP_FILES} 
${CUR_OUTPUT}"
      fi
    else
      LogMsg "Adding the ZIP file(s)  \"${CUR_ZIP_FILE}\" ..."
      CUR_OUTPUT="$( ls "${CUR_ZIP_FILE}" )"
      if [ "${CUR_OUTPUT}"x = ""x ] ; then
        LogMsg "The zip files \"${CUR_ZIP_FILE}\" does not exist"
      else
        NEW_ZIP_FILES="${NEW_ZIP_FILES} 
${CUR_OUTPUT}"
      fi
    fi      
  done

  if [ "${NEW_ZIP_FILES}"x = ""x ] ; then
    die 7 "No zip files found"
  else
    ZIP_FILES="${NEW_ZIP_FILES}"
   
  fi

  LogMsg
  LogMsg "  --------------------------------------------------------------------- "
  LogMsg "The ZIP files to process are : "
  LogMsg "${NEW_ZIP_FILES}"
  LogMsg
  
  mkdir -p "${WORKDIR}" && cd "${WORKDIR}" || die 15 "Can not create the working directory \"${WORKDIR}\" "

  
# ---------------------------------------------------------------------
# cleanup the working directory
#
  rm -f "${NEW_OTACERTS_ZIP_FILE}"
  
  cp "${OTACERTS_ZIP_FILE}" "${NEW_OTACERTS_ZIP_FILE}" 
  TEMPRC=$?
  
  if [ ${TEMPRC} -ne 0 ] ; then
    die 20 "Can not copy the file \"${OTACERTS_ZIP_FILE}\" to the working directory \"${NEW_OTACERTS_ZIP_FILE}\" "
  fi

  LogMsg
  LogMsg "  --------------------------------------------------------------------- "
  LogMsg "Adding the certificates to the file \"${NEW_OTACERTS_ZIP_FILE}\" ..."
  
  CERTIFICATES_ADDED=${__FALSE}
  
  for CUR_ZIP_FILE in ${ZIP_FILES} ; do
    LogMsg 
    LogMsg "Processing the file \"${CUR_ZIP_FILE}\" ..."

    if [ ! -r "${CUR_ZIP_FILE}" ] ; then
      LogError "The file \"${CUR_ZIP_FILE}\" does not exist"
      THISRC=200
      continue
    fi

    CUR_ZIP_FILE_NAME="${CUR_ZIP_FILE##*/}"
    NEW_CERT_FILE="${CUR_ZIP_FILE_NAME%.*}.x509.pem"
    
    unzip -p "${CUR_ZIP_FILE}" META-INF/com/android/otacert >"${NEW_CERT_FILE}"
    if [ $? -eq 0 -a -r "${NEW_CERT_FILE}" ] ; then
      if [ ! -s "${NEW_CERT_FILE}" ] ; then
        LogWarning "\"${CUR_ZIP_FILE}\" is not an OS image file"

#
# the file is empty 
#
        rm -f "${NEW_CERT_FILE}"
        continue
      fi
      
      LogMsg "Adding the certificate \"${NEW_CERT_FILE}\" to the file \"${NEW_OTACERTS_ZIP_FILE}\" ..."
      if [ "${PACKPROG}"x = "zip"x ] ; then
        ${ZIP} "${NEW_OTACERTS_ZIP_FILE}" "${NEW_CERT_FILE}"
        TEMPRC=$?
      else
        ${_7ZZ} a "${NEW_OTACERTS_ZIP_FILE}"  "${NEW_CERT_FILE}"
        TEMPRC=$?
      fi
      
      if [ ${TEMPRC} -ne 0 ] ; then
        LogError "Error adding the certificate \"${NEW_CERT_FILE}\" to the file \"${NEW_OTACERTS_ZIP_FILE}\""
        THISRC=200
      else
        CERTIFICATES_ADDED=${__TRUE}
      fi
    else
      LogError "Error extracting the certificate from the file file \"${CUR_ZIP_FILE}\" "
      THISRC=200
    fi
  done

  if [ ${CERTIFICATES_ADDED} = ${__TRUE} ] ; then

    LogMsg
    LogMsg "  --------------------------------------------------------------------- "
    LogMsg "The certificates in the file \"${NEW_OTACERTS_ZIP_FILE}\" are now :
"
    unzip -l "${NEW_OTACERTS_ZIP_FILE}"

    LogMsg 
    LogMsg "  --------------------------------------------------------------------- "

    chmod 666 "${NEW_OTACERTS_ZIP_FILE}"


# check, if the file otacerts.zip is already bind mounted
#
    if [ ${UMOUNT_OTACERTS_ZIP} = ${__TRUE} ] ; then

      if [ ${OTACERTS_ALREADY_CHANGED} = ${__TRUE} ] ; then
        if [[ ${CUR_OUTPUT} != /dev/block/*  ]] ; then
          LogMsg "Umounting \"${OTACERTS_ZIP_FILE}\" ..."
          umount "${OTACERTS_ZIP_FILE}"
        fi
      fi
    fi

    LogMsg "Replacing the file \"${OTACERTS_ZIP_FILE}\" with the file \"${NEW_OTACERTS_ZIP_FILE}\" now ..."

    SELINUX_CONTEXT="$( stat -c %C  "${OTACERTS_ZIP_FILE}" )"
    chcon "${SELINUX_CONTEXT}" "${NEW_OTACERTS_ZIP_FILE}"

    ${PREFIX} mount -o bind "${NEW_OTACERTS_ZIP_FILE}" "${OTACERTS_ZIP_FILE}"
    if [ $? -ne 0 ] ; then
      die 250 "Error replacing the file \"${OTACERTS_ZIP_FILE}\" with the file \"${NEW_OTACERTS_ZIP_FILE}\" "      
    else
      LogMsg "
The certificates in the file \"${OTACERTS_ZIP_FILE}\" are now:
"

      unzip -l "${OTACERTS_ZIP_FILE}"

      LogMsg
      
# check the access to that directory

      
      TEST_USER="$( ps -ef  | grep updater | head -1 | cut -f1 -d " " )"
      if [ "${TEST_USER}"x != ""x ] ; then
        LogMsg "Checking whether access to the working directory \"${WORKDIR}\" is permitted for all users ... "

        CUR_OUTPUT="$( su - ${TEST_USER} -c unzip -l "${OTACERTS_ZIP_FILE}" )"
        if [ $? -ne 0 ] ; then
          LogWarning "The used working directory is NOT readable by all users - the update may therefor fail"
        else
          LogMsg "OK, the access seems to be okay"
        fi
      fi

      THISRC=0
    fi
  else
    LogMsg "No certificates added - replacing the file \"${OTACERTS_ZIP_FILE}\" is not necessary"
    THISRC=1
  fi
fi

die ${THISRC}
