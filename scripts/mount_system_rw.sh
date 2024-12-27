#!/system/bin/sh
#
# mount_system_rw.sh - mount the logical partitions in the Android super partition in read-write mode
#
#h#
#h# Usage: mount_system_rw.sh [var=value] [--verbose|-v] [--help|-h] [--keep|-k]
#h#
#h# Parameter: 
#h#   --verbose | -v  print more mesages
#h#   --help | -h     print this usage help
#h#   --keep | -k     do not delete the input files for dmctl
#h#
#
# The parameter for the slot: 
#
#    active, inactive, next, current, _a, _b, 0, and 1 
#
# are supported but the functionality is not yet implemented
#
# History
#   30.08.2024 1.0.0 /bs
#    initial release
#

__TRUE=0
__FALSE=1


# for debugging
#
#PREFIX="echo"
#PREFIX=""

SCRIPT_VERSION="$( grep -E "^#.*/bs" $0 | tail -1 | awk '{ print $3 }' )"

SCRIPT_NAME="${0##*/}"

SCRIPT_COMMAND="$0"

SCRIPT_PARAMETER="$*"

PRINT_HELP=${__FALSE}

IN_USAGE_HELP=${__FALSE}

ERRORS_FOUND=${__FALSE}

LIST_OF_TEMP_FILES=""

LIST_OF_INPUT_FILES=""

KEEP_INPUT_FILES=${__FALSE}

# ---------------------------------------------------------------------

function cleanup {
  typeset CUR_OUTPUT=""
  
  typeset CUR_TMPFILE=""
  
  typeset CUR_TIMESTAMP="$( date +"%Y-%m-%d %H:%M:%S" )"
  
  typeset SCRIPT_HEADER="#/system/bin/sh
echo
echo \"The DM mapper devices were created ${CUR_TIMESTAMP} with this command: \"
echo
echo \"${SCRIPT_COMMAND} ${SCRIPT_PARAMETER}\"
echo
"

  if [ ${IN_USAGE_HELP} != ${__TRUE} ] ; then
    LogInfo "-"
    LogInfo "-" " ---------------------------------------------------------------------- "
    LogInfo "cleanup running"
  fi

  if [ "${LIST_OF_UMOUNT_COMMANDS}"x != ""x ] ; then
    LogMsg ""
    LogMsg "Creating the script to umount the mount points for the new devices \"${UMOUNT_SCRIPT_NAME}\" ..."

    echo "${SCRIPT_HEADER}

echo \"Umounting the temporary devices for the logical volumes in the super partition for the slot ${SLOT} ... \"
echo
if [ \$# -eq 0 ] ; then
  echo \"Press return to continue or CTRL-C to abort ... \"
  read USERINPUT
fi

${LIST_OF_UMOUNT_COMMANDS}

" >"${UMOUNT_SCRIPT_NAME}"
    if [ $? -eq 0 ] ; then
      chmod 755 "${UMOUNT_SCRIPT_NAME}"
      ls -l "${UMOUNT_SCRIPT_NAME}"
    else
      LogError "Error creating the script to umount the mount points for the new devices"
      LogMsg
      LogMsg "The commands to umount the temporary devices are:"
      LogMsg
      LogMsg "${LIST_OF_UMOUNT_COMMANDS}"
      LogMsg
    fi
  fi

  
  if [ "${LIST_OF_COMMANDS_TO_DELETE_THE_DEVICES}"x != ""x ] ; then
    LogMsg ""
    LogMsg "Creating the script to delete the temporary devices \"${DELETE_SCRIPT_NAME}\" ..."

    
    echo "${SCRIPT_HEADER}

echo \"Deleting the temporary devices for the logical volumes in the super partition for the slot ${SLOT} ... \"
echo
if [ \$# -eq 0 ] ; then
  echo \"Press return to continue or CTRL-C to abort ... \"
  read USERINPUT
fi

${LIST_OF_COMMANDS_TO_DELETE_THE_DEVICES}

if [ \"\${VERBOSE}\"x != \"\"x ] ; then
   echo
   echo \"The DM mapper devices are now\" 
   ${SU_PREFIX} ${DMCTL} list devices
   echo
fi

" >"${DELETE_SCRIPT_NAME}"
    if [ $? -eq 0 ] ; then
      chmod 755 "${DELETE_SCRIPT_NAME}"
      ls -l "${DELETE_SCRIPT_NAME}"
    else
      LogError "Error creating the script to delete the temporary devices"
      LogMsg
      LogMsg "The commands to delete the temporary devices are:"
      LogMsg
      LogMsg "${LIST_OF_COMMANDS_TO_DELETE_THE_DEVICES}"
      LogMsg
    fi
  fi

  if [ -x "${UMOUNT_SCRIPT_NAME}" -a -x "${DELETE_SCRIPT_NAME}" ] ; then
    LogMsg "" 
    LogMsg "Use"
    LogMsg ""
    LogMsg "  ${UMOUNT_SCRIPT_NAME} yes ; ${DELETE_SCRIPT_NAME} yes "
    LogMsg ""
    LogMsg "to umount and delete the temporary devices"
    LogMsg ""
  fi
  
  if [ ${IN_USAGE_HELP} != ${__TRUE} -a ${ERRORS_FOUND} = ${__FALSE} ] ; then
    CUR_OUTPUT="$( df -h | grep "${TEMP_ROOT_DIR}/" )"
    if [ "${CUR_OUTPUT}"x != ""x ] ; then
      LogMsg 
      LogMsg "Mounted logical partitions are:"
      LogMsg 
      LogMsg "${CUR_OUTPUT}"
      LogMsg 
    fi
  fi
  
  if [ "${LIST_OF_INPUT_FILES}"x != ""x ] ; then
    LogMsg ""
    LogMsg "The list of input files used to create the DM mapper devices is:"
    LogMsg
    LogMsg "${LIST_OF_INPUT_FILES}"
    LogMsg
  fi

  if [ "${VERBOSE}"x != ""x -a ${PRINT_HELP} != ${__TRUE} ] ; then
    if [ "${LIST_OF_TEMP_FILES}"x != ""x ] ; then
      LogMsg ""
      LogMsg "Not deleting the temporary files used:"
      LogMsg
      LogMsg "${LIST_OF_TEMP_FILES}"
      LogMsg
    fi
  else
    for CUR_TMPFILE in LIST_OF_TEMP_FILES ; do
      if [ -r "${CUR_TMPFILE}" ] ; then
        \rm -r "${CUR_TMPFILE}"
      fi
    done
  fi  

  LogMsg ""
}

# install a trap handler for house keeping
#
trap "cleanup"  0

function LogMsg {
  echo "$@"
  return ${__TRUE}
}

function LogInfo {
  typeset THISMSG=""

  if [[ "$1"x = "-"x ]] ; then
    shift
    THISMSG="$@" 
  else
    THISMSG="INFO: $@"
  fi
  
  [[ ${VERBOSE} == ${__TRUE} ]] && LogMsg "${THISMSG}" >&2 || return ${__FALSE}
}

function LogError {
  LogMsg "ERROR: $@" >&2
}

function die {
  typeset THISRC=$1

  [ $# -gt 0 ] && shift

  typeset THISMSG="$*"
  
  if [ "${THISRC}"x = "0"x -o "${THISRC}"x = "1"x ] ; then
     [ "${THISMSG}"x != ""x ] && LogMsg "${THISMSG} (RC=${THISRC})"
  else
    ERRORS_FOUND=${__TRUE}
    LogError "${THISMSG} (RC=${THISRC})"
  fi
  exit ${THISRC}
}

# ---------------------------------------------------------------------
# process the parameter 
#
while [ $# -ne 0 ] ; do

  CUR_PARAMETER="$1"
  shift
  
  case ${CUR_PARAMETER} in
  
    inactive | active | current | next | _a | -b | 0 | 1 )
      SLOT=${CUR_PARAMETER}
      ;;

    -k | --keep )
       KEEP_INPUT_FILES=${__TRUE}
       ;;

    -v | --verbose )
      VERBOSE=${__TRUE}
      ;;

    -h | --help )
      PRINT_HELP=${__TRUE}
      ;;
  
    *=* )
      CUR_VAR="${CUR_PARAMETER%%=*}"
      CUR_VALUE="${CUR_PARAMETER#*=}"
      eval ${CUR_VAR}=\"${CUR_VALUE}\"
      ;;

    * )
      die 100 "Unknown parameter found: ${CUR_PARAMETER}"
      ;;
  esac
done

# ---------------------------------------------------------------------
# environment variables used
#
BASEDIR="${BASEDIR:=/data/local/tmp}"

LPDUMP="${LPDUMP:=$( which lpdump )}"
GETPROP="$( which getprop )"
DMCTL="${DMCTL:=$( which dmctl )}"

TMPDIR="${TMPDIR:=/data/local/tmp}"

TMPFILE1="${TMPDIR}/${SCRIPT_NAME}.1.tmp"
LIST_OF_TEMP_FILES="${TMPFILE1}"

LIST_OF_COMMANDS_TO_DELETE_THE_DEVICES=""

LIST_OF_UMOUNT_COMMANDS=""


CURRENT_ACTIVE_SLOT=$( getprop ro.boot.slot_suffix 2>/dev/null )

SLOT="${SLOT:=${CURRENT_ACTIVE_SLOT}}"

case ${SLOT} in

  0 )
    SLOT="_a"
    ;;

  1 )
    SLOT="_b"
    ;;
  
  active | current )
    SLOT=${CURRENT_ACTIVE_SLOT}
    ;;

  inactive | next )
    [ ${CURRENT_ACTIVE_SLOT} = "_a" ] && SLOT="_b" || SLOT="_a"
    ;;

esac


DELETE_SCRIPT_NAME="${DELETE_SCRIPT_NAME:=/data/local/tmp/delete_dm_devices${SLOT}.$$.sh}"

UMOUNT_SCRIPT_NAME="${UMOUNT_SCRIPT_NAME:=/data/local/tmp/umount_dm_devices${SLOT}.$$.sh}"

DEVICE_NAME_PREFIX="${DEVICE_NAME_PREFIX:=dm-${SLOT#*_}-}"

IN_USAGE_HELP=${__FALSE}

ERRORS_FOUND=${__FALSE}


# ---------------------------------------------------------------------



# ---------------------------------------------------------------------

LogMsg ""
LogMsg "${SCRIPT_NAME} ${SCRIPT_VERSION} - mount the logical partitions in the super partition in read/write mode"

if [ ${PRINT_HELP} = ${__TRUE} ] ; then
  grep "^#h#" $0 | cut -c4-
      
  if [ "${VERBOSE}"x != ""x ] ; then
    CUR_ENV_VARS=$( grep -v "^#" $0 | grep ":=" | cut -f1 -d"=" | grep -v CUR_ENV_VARS )
    if  [ "${CUR_ENV_VARS}"x != ""x ] ; then
      echo 
      echo "The environment variables supported by this script are:"
      echo 
      for CUR_VAR in ${CUR_ENV_VARS} ; do
        eval CUR_VALUE="\"\$${CUR_VAR}\""
        echo "${CUR_VAR}; the current value is \"${CUR_VALUE}\" "
      done
      echo
    fi
  else
    echo "Use the parameter \"-v -h\" to also print the list of supported environment variables"
  fi
  
  IN_USAGE_HELP=${__TRUE}
  exit 1 

fi


# ---------------------------------------------------------------------

ERRORS_FOUND=${__FALSE}

if [ "${CURRENT_ACTIVE_SLOT}"x != "${SLOT}"x ] ; then
  LogError "Mount the inactive slot is currently not yet supported"
  ERRORS_FOUND=${__TRUE}
fi

# check if we do have root access on the phone

SU_PREFIX=""

CUR_ID="$( id -un )"
if [ "${CUR_ID}"x = "root"x ] ; then
  LogInfo "root access without any prefix works"
else
  CUR_ID="$( su - -c id -un )"
  if [ "${CUR_ID}"x = "root"x ] ; then
    SU_PREFIX="su - -c "
    LogInfo "Using the prefix \"${SU_PREFIX}\" for root access"
  else
    LogError " root access to the phone does not work"
    ERRORS_FOUND=${__TRUE}
  fi
fi

# check that the necessary executables exist

if [ "${LPDUMP}"x = ""x ] ; then
  echo "ERROR: Executable \"lpdump\" not found"
  ERRORS_FOUND=${__TRUE}
elif ! ${SU_PREFIX} test -x "${LPDUMP}" ; then
  echo "ERROR: The file \"${LPDUMP}\" is not an executable"
  ERRORS_FOUND=${__TRUE}
fi

if [ "${DMCTL}"x = ""x ] ; then
  echo "ERROR: Executable \"dmctl\" not found"
  ERRORS_FOUND=${__TRUE}
elif ! ${SU_PREFIX} test -x "${DMCTL}"  ; then
  echo "ERROR: The file \"${DMCTL}\" is not an executable"
  ERRORS_FOUND=${__TRUE}
fi

if [ "${GETPROP}"x = ""x ] ; then
  echo "ERROR: Executable \"getprop\" not found"
  ERRORS_FOUND=${__TRUE}
elif [ ! -x "${GETPROP}" ] ; then
  echo "ERROR: The file \"${GETPROP}\" is not an executable"
  ERRORS_FOUND=${__TRUE}
fi

if [ ! -d "${BASEDIR}" ] ; then
  echo "ERROR: The directory \"${BASEDIR}\" does not exist"
  ERRORS_FOUND=${__TRUE}
fi


[ ${ERRORS_FOUND} = ${__TRUE} ] && die 10 "One or more errors found"

# ---------------------------------------------------------------------

TEMP_ROOT_DIR="${BASEDIR}/${SLOT#_*}" 

BASEDIR_DEV="$( df -h "${BASEDIR}"| tail -1 | cut -f1 -d " " )"

LogMsg "Retrieving the list of logical partitions for the slot \"${SLOT}\" in the super partition ..."

LIST_OF_EXISTING_DM_DEVICES="$(  ${SU_PREFIX} ${DMCTL} list devices | awk '{ print $1 }' | grep -v Available )"

LogInfo "The list of existing devices is:" && \
  LogMsg "${LIST_OF_EXISTING_DM_DEVICES}"
  
LIST_OF_LOGICAL_PARTITIONS="$( ${SU_PREFIX} ${LPDUMP} -s "${SLOT}" /dev/block/by-name/super  | grep "^super:" )"

LogInfo "The list of logical partitions is:" && \
  LogMsg "${LIST_OF_LOGICAL_PARTITIONS}"

[ "${LIST_OF_LOGICAL_PARTITIONS}"x = ""x ]  && die 20 "Error etrieving the list of logical partitions for the slot \"${SLOT}\" in the super partition ."

LOGICAL_PARTITIONS_IN_SUPER="$( echo "${LIST_OF_LOGICAL_PARTITIONS}" | awk '{ print $5 }' | egrep -v -- "-cow" | sort | uniq | tr "\n" " " )"

if [ "${LOGICAL_PARTITIONS_IN_SUPER}"x = ""x ]  ; then
  LogMsg 
  LogMsg "The format of the output of the lpdump command is not as expected:"
  LogMsg
  LogMsg "${LIST_OF_LOGICAL_PARTITIONS}"
  LogMsg

  die 25 "Unknown output format of the lpdump command"
fi

LogMsg "The logical partitions for the slot \"${SLOT}\" in the super partition are:"
LogMsg
LogMsg "${LOGICAL_PARTITIONS_IN_SUPER}"
LogMsg

LogMsg "Mounting the volumes in the super partition for the slot \"${SLOT}\" read-write to sub directories in the directory \"${TEMP_ROOT_DIR}\"  ..."

mkdir -p "${TEMP_ROOT_DIR}" || die 30 "Error creating the directory \"${TEMP_ROOT_DIR}\" "

for CUR_LOGICAL_PARTITION in ${LOGICAL_PARTITIONS_IN_SUPER} ; do
  LogMsg
  
  LogMsg "# Processing the logical partition \"${CUR_LOGICAL_PARTITION}\" ..."

  CUR_MOUNT_POINT="${TEMP_ROOT_DIR}/${CUR_LOGICAL_PARTITION}"
  LogMsg "The mount point for the logical partition \"${CUR_LOGICAL_PARTITION}\" is \"${CUR_MOUNT_POINT}\" "

  if [ -d "${CUR_MOUNT_POINT}" ] ; then
    CURDIR_DEV="$( df -h "${CUR_MOUNT_POINT}"| tail -1 | cut -f1 -d " " )"
    if [ "${CURDIR_DEV}"x != "${BASEDIR_DEV}"x ] ; then

      CUR_DEVICE_MAPPER_DEV="$(  ls -l /dev/block/mapper | grep -e "${CURDIR_DEV}$" | awk '{ print $8 }')"

      LogMsg "The directory \"${CUR_MOUNT_POINT}\" is already mounted on the device \"${CURDIR_DEV}\" (= \"${CUR_DEVICE_MAPPER_DEV}\" )"
      continue
    fi
  else
    ${SU_PREFIX} mkdir -p "${CUR_MOUNT_POINT}"
    if [ $? -ne 0 ] ; then
      LogError "Error creating the mountpoint \"${CUR_MOUNT_POINT}\" for the logical partition \"${CUR_LOGICAL_PARTITION}\" "
      continue
    fi 
  fi

  PARTITION_START_SECTOR="$( echo "${LIST_OF_LOGICAL_PARTITIONS}" | grep " ${CUR_LOGICAL_PARTITION} " | awk '{ print $2 }'   )"
  PARTITION_SIZE="$(         echo "${LIST_OF_LOGICAL_PARTITIONS}" | grep " ${CUR_LOGICAL_PARTITION} " | awk '{ print $6 }'  | tr -d "()"  )"

  CUR_DEVICE_NAME="${DEVICE_NAME_PREFIX}${CUR_LOGICAL_PARTITION}"


  echo "${LIST_OF_EXISTING_DM_DEVICES}" | grep -e "^${CUR_DEVICE_NAME}$" >/dev/null
  if [ $? -eq 0 ] ; then
    LogMsg "The DM mapper device \"${CUR_DEVICE_NAME}\" already exists"

  else  

    NO_OF_PARTITION_PARTS=$( echo "${PARTITION_START_SECTOR}" | wc -l )

    if [ ${NO_OF_PARTITION_PARTS} -gt 1 ] ; then
      LogInfo "${CUR_LOGICAL_PARTITION} uses ${NO_OF_PARTITION_PARTS} extends - -that is currently not supported by this script"  
    fi

    CUR_INPUT_FILE="${TMPDIR}/${CUR_LOGICAL_PARTITION}.input"
  
    LIST_OF_TEMP_FILES="${LIST_OF_TEMP_FILES} ${CUR_INPUT_FILE}"

    echo "${LIST_OF_LOGICAL_PARTITIONS}" | grep " ${CUR_LOGICAL_PARTITION} " >"${TMPFILE1}"
  
    DMCTL_COMMANDS="create ${CUR_DEVICE_NAME}"
 
    LOGICAL_START_SECTOR="0"
  
    while read CUR_LINE ; do

      PARTITION_START_SECTOR="$( echo "${CUR_LINE}" | awk '{ print $2 }'   )"
      PARTITION_END_SECTOR="$( echo "${CUR_LINE}" | awk '{ print $4 }'   )"
      PARTITION_SIZE="$(         echo "${CUR_LINE}" | awk '{ print $6 }'  | tr -d "()"  )"
  
      DMCTL_COMMANDS="${DMCTL_COMMANDS}    
linear ${LOGICAL_START_SECTOR} ${PARTITION_SIZE} /dev/block/by-name/super ${PARTITION_START_SECTOR}"

      (( LOGICAL_START_SECTOR = LOGICAL_START_SECTOR + PARTITION_SIZE ))

    done <"${TMPFILE1}"
   
    echo "${DMCTL_COMMANDS}" >"${CUR_INPUT_FILE}"
    if [ $? -ne 0 ] ; then
      LogError "Error creating the file with the commands for dmctl \"${CUR_INPUT_FILE}\" - can not create the temporary DM mapper device for the dynamic partition \"${CUR_LOGICAL_PARTITION}\" "
      continue
    fi
  
    if [ ${KEEP_INPUT_FILES} = ${__FALSE} ] ; then
      LIST_OF_TEMP_FILES="${LIST_OF_TEMP_FILES} ${CUR_INPUT_FILE}"
    else
      LIST_OF_INPUT_FILES="${LIST_OF_INPUT_FILES} ${CUR_INPUT_FILE}"
    fi

    LogInfo "The commands for dmctl in the file \"${CUR_INPUT_FILE}\" to create the device \"\" are: " && \
      LogMsg "" && \
      cat "${CUR_INPUT_FILE}" && \
      LogMsg ""
 
    LogMsg "Creating the DM mapper device \"${CUR_DEVICE_NAME}\" for the logical partition \"${CUR_LOGICAL_PARTITION}\" ..."
    ${SU_PREFIX} ${DMCTL} -f "${CUR_INPUT_FILE}" 
    if [ $? -ne 0 ] ; then
      LogError "Error creating the DM mapper device \"${CUR_DEVICE_NAME}\" for the logical partition \"${CUR_LOGICAL_PARTITION}\" "
      continue
    else
      LIST_OF_COMMANDS_TO_DELETE_THE_DEVICES="${LIST_OF_COMMANDS_TO_DELETE_THE_DEVICES}
\${PREFIX} ${SU_PREFIX} ${DMCTL} info \"${CUR_DEVICE_NAME}\"  2>/dev/null >/dev/null && \${PREFIX} ${SU_PREFIX} ${DMCTL} delete \"${CUR_DEVICE_NAME}\" 
"
    fi
  fi
  
  CUR_DEVICE_PATH="$(  ${SU_PREFIX} ${DMCTL} getpath "${CUR_DEVICE_NAME}" )"
  if [ $? -ne 0 -o "${CUR_DEVICE_PATH}"x = ""x ] ; then
    LogError "Can not get the DM mapper device for the logical partition \"${CUR_LOGICAL_PARTITION}\" "
    continue
  fi
  
  ${SU_PREFIX} mount "${CUR_DEVICE_PATH}" "${CUR_MOUNT_POINT}"
  if [ $? -ne 0 ] ; then
    LogError "Can not mount the DM mapper device for the logical partition \"${CUR_LOGICAL_PARTITION}\" to \"${CUR_MOUNT_POINT}\" "
    continue
  else

    LIST_OF_UMOUNT_COMMANDS="${LIST_OF_UMOUNT_COMMANDS}
\${PREFIX} ${SU_PREFIX} umount  \"${CUR_MOUNT_POINT}\" 
"

  fi
done

die 0

