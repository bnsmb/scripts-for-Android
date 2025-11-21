#!/usr/bin/bash
#
# view_payload_bin.sh - list the files in the file payload.bin in a zip file with an Android OS imgae
#
# Usage: view_payload_bin.sh [-h] [-k|--keep] [-n|--dry-run] [zipfile1] [...zipfile#]"
#
# History
#  19.11.2025 v1.0.0 /bs
#    initial release
#
__TRUE=0
__FALSE=1

TMPDIR="/tmp/payload.$$"

PAYLOAD_DUMPER="${PAYLOAD_DUMPER:=$( which payload-dumper-go )}"

ZIP_FILES=""

KEEP_FILES=${__FALSE}

# ---------------------------------------------------------------------

function cleanup {
  trap "" 0
  if [ ${KEEP_FILES} = ${__FALSE} ] ; then
    if [ -d "${TMPDIR}" ] ; then
      \rm -rf "${TMPDIR}"
    fi
  else
    echo "The directory with the temporary files is \"${TMPDIR}\" "  
  fi
  return
}

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

trap cleanup 0

while [ $# -ne 0 ] ; do

  CUR_PARAMETER="$1"
  shift
  
  case ${CUR_PARAMETER} in
  
    -h | --help | help )
      echo "Usage: $0 [-h] [--keep] [zipfile1] [...zipfile#]"
      exit 0
      ;;

    --keep | -k )
      KEEP_FILES=${__TRUE}
      ;;

   -n | --dry-run )
     PREFIX="echo"
     ;;
          
   * )
     ZIP_FILES="${ZIP_FILES} ${CUR_PARAMETER}"
     ;;
  esac
  
done

if [ "${ZIP_FILES}"x != ""x ] ; then
  ${PREFIX} mkdir -p "${TMPDIR}" || die 5 "Can not create the temporary directory \"${TMPDIR}\" "

  [  "${PAYLOAD_DUMPER}"x = ""x ] && die 10 "payload-dumper-go not available via PATH variable"
  
  for CUR_FILE in ${ZIP_FILES} ; do
    LogMsg ""
    LogMsg "Processing the file \"${CUR_FILE}\" ..."
    
    if [ ! -r "${CUR_FILE}" ] ; then
      LogError "The file \"${CUR_FILE}\" does not exist"
      continue
    fi
    ${PREFIX}  rm -rf "${TMPDIR}"/*

    if [ "${PREFIX}"x != ""x  ] ; then
      ${PREFIX}  unzip -p "${CUR_FILE}" '>'"${TMPDIR}/payload.bin"
      ${PREFIX} ${PAYLOAD_DUMPER} -l "${TMPDIR}/payload.bin"
    else
      unzip -p "${CUR_FILE}" payload.bin >"${TMPDIR}/payload.bin"   
      if [ $? -ne 0 -o ! -r "${TMPDIR}/payload.bin" ] ; then
        LogError "Error extracting the file \"payload.bin\" from the ZIP file \"${CUR_FILE}\" "
      else
        ${PAYLOAD_DUMPER} -l "${TMPDIR}/payload.bin"
      fi
    fi
  done
fi

die 0
