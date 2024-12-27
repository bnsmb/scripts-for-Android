#
# reset_usb_port_for_phone.sh - reset the USB port used for an Android OS
#
#h# Usage: reset_usb_port_for_phone [serial_number_of_the_phone] [force] [noreset|view]
#h#
#h# Parameter:
#h#
#h#    serial_number_of_the phone     the serial number of the phone for which the USB port should be reset
#h#                                   the default is the serial number hardcoded in the script
#h#    force                          reset the USB port even if it is not necessary
#h#    noreset|view                   only print the current status; do NOT reset the USB port
#h#                                   Using this parameter the script uses these return codes:
#h#                                   0 - there is a working adb connection to the phone
#h#                                   1 - the phone is in the bootloader 
#h#                                   2 - the phone is in the fastbootd
#h#                                   9 - no phone with the given serial number found
#h#                                >100 - an error occured
#h#
# Note: 
#   The command to reset the phone is executed with sudo
#
# Author
#   Bernd Schemmer (bernd.schemmer (at) gmx.de)
#
# History
#  20.05.2024 v1.0.0  /bs #VERSION
#   inital version
#  21.05.2024 v1.0.1  /bs #VERSION
#   added code to print a message if there is no connection to the phone
#
#

# define some constants
#
__TRUE=0
__FALSE=1

# define global variables
#
  
SCRIPT_VERSION="$( grep "^#" $0 | grep "#VERSION" | grep "v[0-9]" | tail -1 | awk '{ print $3}' )"

SCRIPT_NAME="${0##*/}"

SCRIPT_PATH="${0%/*}"

# default serial number of the phone
#
DEFAULT_SERIAL_NUMBER="M6AIB760D0939LX"

SERIAL_NUMBER=""

FORCE_RESET=${__FALSE}

DO_NOT_RESET_THE_USB_PORT=${__FALSE}

USB_RESET_NECESSARY=${__TRUE}

PHONE_IS_AVAILABLE_VIA_FASTBOOT=${__FALSE}

USB_STATUS="99"

PHONE_IN_EDL_MODE=""

# ----------------------------------------------------------------------
# LogMsg
#
# function: write a message to STDOUT
#
# usage: LogMsg [message]
#
# The function prints nothing if only a status check is requested
#
function LogMsg {
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
# LogWarning
#
# function: write a message prefixed with "WARNING:" to STDERR
#
# usage: LogWarning [message]
#
function LogWarning {
  typeset THISMSG="$*"

  LogMsg "WARNING: ${THISMSG}" >&2
}

# ----------------------------------------------------------------------
# LogInfo
#
# function: write a message prefixed with "INFO:" to STDERR if the variable VERBOSE is ${__TRUE}
#
# usage: LogInfo [message]
#
# The function returns ${__TRUE} if the message was written 
#
function LogInfo {
  typeset THISMSG="$*"

  typeset THISRC=${__FALSE}

  if [ "${VERBOSE}"x = "${__TRUE}"x ] ; then
    LogMsg "INFO: ${THISMSG}" >&2
    THISRC=${__TRUE}
  else
    THISRC=${__FALSE}
  fi
  
  return ${THISRC}
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
      echo "ERROR: ${THISMSG} (RC=${THISRC})" >&2
    else
      echo "${THISMSG}"
    fi
  fi

  exit ${THISRC}
}


# ----------------------------------------------------------------------
# get_usb_device_for_the_phone
#
# function: get the USB device used for the phone
#
# Usage: set_serial_number
#
# returns: 
#
#     ${__TRUE}  - ok, USB device found , PHONE_USB_DEVICE is set
#     ${__FALSE} - error, no USB device found, PHONE_USB_DEVICE is empt
#
# The function searches for an USB device with the serial number ${SERIAL_NUMBER}
# The function stores the USB device found in the global variable PHONE_USB_DEVICE 
# The function stores the USB device name found in the global variable PHONE_IDENTIFIER 
#
function get_usb_device_for_the_phone {
  typeset THISRC=${__FALSE}

  typeset CUR_OUTPUT=""

  typeset CUR_USB_BUS=""
  typeset CUR_USB_DEVICE=""
  typeset CUR_USB_DEVICE_SERIAL=""

  typeset CUR_LINE=""

  typeset TMPFILE="/tmp/${__FUNCTION}.$$.tmp"
  
# init the global variables for the result
#
  PHONE_USB_DEVICE=""
  PHONE_IDENTIFIER=""

  if [ "${SERIAL_NUMBER}"x != ""x ] ; then
  
    LogMsg "Determine the USB port used for the phone ..."
    lsusb >"${TMPFILE}"
    while read CUR_LINE ; do
      [[ ${CUR_LINE} == *QDL\ mode* ]] && PHONE_IN_EDL_MODE="${PHONE_IN_EDL_MODE}
${CUR_LINE}"

      CUR_USB_BUS="$( echo "${CUR_LINE}" | cut -f1 -d ":" | awk '{ print $2 }' )"
      CUR_USB_DEVICE="$( echo "${CUR_LINE}" | cut -f1 -d ":" | awk '{ print $4 }' )"
      
      CUR_USB_DEVICE_SERIAL="$( lsusb -s ${CUR_USB_BUS}:${CUR_USB_DEVICE} -v  2>/dev/null | grep iSerial | awk '{ print $NF }' )"
      if [ "${CUR_USB_DEVICE_SERIAL}"x = "${SERIAL_NUMBER}"x ] ; then
        PHONE_USB_DEVICE="/dev/bus/usb/${CUR_USB_BUS}/${CUR_USB_DEVICE}"
        THISRC=${__TRUE}

        PHONE_IDENTIFIER="$( lsusb -s ${CUR_USB_BUS}:${CUR_USB_DEVICE}  2>/dev/null | cut -f7- -d " " )"
        
        break
      fi
    done < "${TMPFILE}"
    \rm -f "${TMPFILE}"
  else
    LogInfo "S{__FUNCTION}: The variable SERIAL_NUMBER is empty"    
  fi
  
  if [ ${THISRC} = ${__TRUE} ] ; then
    LogMsg "The USB port for the phone with the s/n \"${SERIAL_NUMBER}\" is \"${PHONE_USB_DEVICE}\" (${PHONE_IDENTIFIER})"  
  else
    LogInfo "No attached USB device with the serial number \"${SERIAL_NUMBER}\" found"
  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# process the parameter
#

LogMsg "${SCRIPT_NAME} ${SCRIPT_VERSION}"

while [ $# -ne 0 ] ; do
  
  CUR_PARAMETER="$1"
  shift
   
  case ${CUR_PARAMETER} in

    -h | --help )
      grep "^#h#" $0 | cut -c5-
      die 0
      ;;

    no_reset | view )
      DO_NOT_RESET_THE_USB_PORT=${__TRUE}
      ;;

    force )
      FORCE_RESET=${__TRUE}
      ;;
    * )
     if [ "${SERIAL_NUMBER}"x != ""x ] ; then
       die 105 "Unkown parameter found: ${CUR_PARAMETER}"
     else
       SERIAL_NUMBER="${CUR_PARAMETER}"
     fi
  esac
done

# use the default serial number if no parameter was use
#
SERIAL_NUMBER="${SERIAL_NUMBER:=${DEFAULT_SERIAL_NUMBER}}"

USBRESET="$( which usbreset )"

if [ "${USBRESET}"x = ""x ] ; then
  die 110 "The executable \"usbreset\" is not available via the PATH"
fi

if [ "${SERIAL_NUMBER}"x = ""x ] ; then
  die 115 "No serial number for the phone found"
fi


LogMsg "Resetting the USB port used for the phone whith the serial number \"${SERIAL_NUMBER}\" if necessary ..."

# retrieve the current USB device used for the phone
#
get_usb_device_for_the_phone 
if [ "${PHONE_USB_DEVICE}"x = ""x ] ; then

  LogError "No phone with the serial number \"${SERIAL_NUMBER}\" found in the list of attached USB devices"
  if [ "${PHONE_IN_EDL_MODE}"x != ""x ]  ; then
    LogMsg "But there is a phone in EDL mode attached: ${PHONE_IN_EDL_MODE}"
  fi
  die 9
fi

# check if the phone is in the bootloader
#
CUR_OUTPUT=$( timeout 3 fastboot devices | grep "${SERIAL_NUMBER}" )
if [ $? -eq 0 ] ; then
  LogMsg "The phone with the serial number \"${SERIAL_NUMBER}\" is available via fastboot"
  LogMsg "-"
  LogMsg "${CUR_OUTPUT}"
  LogMsg "-"
  echo "${CUR_OUTPUT}" | grep fastbootd >/dev/null && USB_STATUS="2" ||  USB_STATUS="1"
  USB_RESET_NECESSARY=${__FALSE}
  PHONE_IS_AVAILABLE_VIA_FASTBOOT=${__TRUE}
fi

# check the status of the phone
#
CUR_OUTPUT="$( adb -s "${SERIAL_NUMBER}" devices 2>&1 | grep "${SERIAL_NUMBER}"  )"
if [ $? -eq 0 ] ; then
  LogMsg "The phone with the serial number \"${SERIAL_NUMBER}\" is available via adb; the status is "
  LogMsg ""
  LogMsg "${CUR_OUTPUT}"
  LogMsg ""
  USB_STATUS="0"
  USB_RESET_NECESSARY=${__FALSE}
else
  LogMsg "The phone with the serial number \"${SERIAL_NUMBER}\" is NOT available via adb"
fi

if [ ${DO_NOT_RESET_THE_USB_PORT} = ${__TRUE} ] ; then
  die ${USB_STATUS}
else
  if [  ${USB_RESET_NECESSARY} = ${__FALSE} ] ; then
    if [ ${FORCE_RESET} = ${__TRUE} ] ; then
      LogMsg "A reset of the USB port is not necessary but a forced reset is requested via parameter"
    else
      die 0 "No USB reset necessary"
    fi
  fi


  LogMsg "Now resetting the USB port \"${PHONE_USB_DEVICE}\" used for the phone ..."
  
  sudo ${USBRESET} ${PHONE_USB_DEVICE}
  THISRC=$?
  
  LogMsg "The status of the phone is now:"
  LogMsg ""
  sleep 1
  if [ ${PHONE_IS_AVAILABLE_VIA_FASTBOOT} = ${__TRUE} ] ; then
    timeout 3 fastboot devices | grep "${SERIAL_NUMBER}" 
  else
    adb devices | grep "${SERIAL_NUMBER}"
  fi
  LogMsg ""
  
  if [ ${THISRC} -ne 0 ] ; then
    die 125 "Error resetting the USB port for the phone"
  else
    die 0 "Successfully resetting the USB port for the phone"
  fi
fi



