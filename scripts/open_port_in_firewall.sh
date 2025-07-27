# /system/bin/sh
#h#
#h# open_port_in_firewall.sh #VERSION# - add or delete firewall rules for the connection to an IP address
#h#
#h# Usage: open_port_in_firewall.sh  [-h|--help] [--in|--out|--both] [--tcp|--udp|--all] [-v|--verbose] [-V] [var=value] [enable|disable|check|status] [vpn_config_file|ip:port]
#h#
#h# "ip:port" is an IP address with a port, e.g:  47.154.109.161:1368
#h# If the binary "dig" is available via PATH, "ip" can also be a hostname
#h#
#H# Known parameter:
#H# 
#H# --in             only process incoming connections
#H# --out            only process outgoing connections
#H# --both           process incoming and outgoing connections
#H# 
#H# --tcp            only process TCP connections
#H# --udp            only process UDP connections
#H# --all            process TCP and UDP connections
#H# 
#H# --verbose -v     print more messages
#H# -V               print the version number and exit the script
#H# 
#H# var=value        set the variable "var" to the value "value"
#H# 
#H# enable or open   open the ip:port in the firewall, "enable_all" is an alias for "enable --both"
#H# disable or close close the ip:port in the firewall, "disable_all" is an alias for "disable --both"
#H# check            print the status of the requested firewall rules for "ip:port", "check_all" is an alias for "check --both"
#H# status           print all firewall rules for "ip:port"
#H# 
#H# vpn_config_file  VPN config file to retrieve the "ip:port" to use
#H# ip:port          use this "ip:port" and ignore the vpn config file
#H#
#h# Use either the parameter "vpn_config_file" or the parameter "ip:port"
#h#
#h# The default direction is "out"
#h# The default protocoll is "tcp"
#h# The default action is "enable"
#h# The default vpn config file is /system/etc/openvpn/vpngate/vpngate.ovpn
#h#
#
# Lines beginning with #h# are printed if the script is executed with the parameter "-h" or "--help"
#
# Lines beginning with #H# are printed if the script is executed with the parameter "-h -v" or "--help --verbose"
#
# Author
#   Bernd Schemmer (bernd dot schemmer at gmx dot de)
#
# History
#   25.07.2025 /bs v1.0.0
#     initial release
#

# ----------------------------------------------------------------------
# define constants
#

__TRUE=0
__FALSE=1

# ---------------------------------------------------------------------
# default values 
#

DEFAULT_VPN_CONFIG_FILE="/system/etc/openvpn/vpngate/vpngate.ovpn"

DEFAULT_DIRECTION="out"

DEFAULT_ACTION="status"

DEFAULT_PROTOCOL="tcp"

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

  if [ "${THISRC}"x = "0"x -o "${THISRC}"x = "1"x ] ; then
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
# check for dry-run mode
#
if [ "${PREFIX}"x != ""x ] ; then
# 
# check mksh (in some mksh versions PREFIX is used for a directory name)
#
  if [ -d "${PREFIX}" ] ; then
    LogWarning "The variable PREFIX contains a directory name: \"${PREFIX}\" -- disabling dry-run mode now"
    PREFIX=""
  else
    LogMsg ""
    LogMsg "*** The variable PREFIX is defined (PREFIX=\"${PREFIX}\") -- running in dry-run mode now"
    LogMsg ""
  fi

fi

# ---------------------------------------------------------------------



# ---------------------------------------------------------------------
# read_firewall_rules - read the current firewall rules
#
# Usage: read_firewall_rules [all]
#
# Parameter:
#
# all -- print the firewall rules for all incoming and outgoing connections for UDP and TCP for the current IP:port
#
# returns: ${__TRUE}  - firewall rules found and written to STDOUT
#          ${__FALSE} - no firewall rules found
#
# The function uses the global variable DIRECTION to selcet the type of connections (input, output, or both)
#
function read_firewall_rules {
  typeset THISRC=${__TRUE}
  typeset CUR_OUTPUT=""
  
  typeset CUR_DIRECTION="${DIRECTION}"
  typeset CUR_PROTOCOL="${PROTOCOL}"
  
  if [ "$1"x = "all"x ] ;then
   CUR_DIRECTION="both"
   CUR_PROTOCOL="all"
  fi  
  
  if [ "${CUR_DIRECTION}"x = "out"x ] ; then
    CUR_OUTPUT="$( ${IPTABLES} -L OUTPUT -v -n  | grep "[[:space:]]${CUR_VPN_SERVER_IP}[[:space:]]" | grep ":${CUR_VPN_SERVER_PORT}$" | grep ACCEPT | sort | uniq )"
  elif [ "${CUR_DIRECTION}"x = "in"x ] ; then
    CUR_OUTPUT="$( ${IPTABLES} -L INPUT -v -n  | grep "[[:space:]]${CUR_VPN_SERVER_IP}[[:space:]]" | grep ":${CUR_VPN_SERVER_PORT}$" | grep ACCEPT | sort | uniq )"
  else
    CUR_OUTPUT="$( ${IPTABLES} -L -v -n  | grep "[[:space:]]${CUR_VPN_SERVER_IP}[[:space:]]" | grep ":${CUR_VPN_SERVER_PORT}$" | grep ACCEPT | sort | uniq )"
  fi

  if [ "${CUR_PROTOCOL}"x = "tcp"x ] ;then
    CUR_OUTPUT="$( echo "${CUR_OUTPUT}" | grep "[[:space:]]tcp[[:space:]]" )"
  elif [ "${CUR_PROTOCOL}"x = "udp"x ] ;then
    CUR_OUTPUT="$( echo "${CUR_OUTPUT}" | grep "[[:space:]]udp[[:space:]]" )"
  fi
    
  if [ "${CUR_OUTPUT}"x != ""x ] ; then 
    echo "${CUR_OUTPUT}"
    THISRC=${__TRUE}
  else
    THISRC=${__FALSE}
  fi
  
  return ${THISRC}
}


# ---------------------------------------------------------------------
# main function


# ---------------------------------------------------------------------
# process the script parameter
#

LogInfo "Processing the parameter ..."

LogInfo "The parameter for the script are "  && \
  LogMsg "$*"


VPN_SERVER_CONFIG=""

VPN_CONFIG_FILE=""

ACTION=""

PRINT_USAGE_HELP=${__FALSE}

while [ $# -ne 0 ] ; do
  CUR_PARAMETER="$1"
  shift

  LogInfo "Processing the parameter \"${CUR_PARAMETER}\" ..."

  case  ${CUR_PARAMETER} in
  
    -h | --help | help )
      PRINT_USAGE_HELP=${__TRUE}
      ;;
  
    --in )
      DIRECTION="in"
      ;;

    --out )
      DIRECTION="out"
      ;;

    --both )
      DIRECTION="both"
      ;;

    --tcp )
      PROTOCOL="tcp"
      ;;

    --udp )
      PROTOCOL="udp"
      ;;

    --all )
      PROTOCOL="all"
      ;;

    open | openall | enable | enableall | open_all | enable_all )
      if [ "${ACTION}"x != ""x ] ; then
        die 11 "Duplicate action found (\"${ACTION}\" and \"${CUR_PARAMETER}\")"
      fi
      ACTION="enable"
      [[ ${CUR_PARAMETER} == *all ]] && DIRECTION="both"
      ;;
    
    check | checkall | check_all )
      if [ "${ACTION}"x != ""x ] ; then
        die 11 "Duplicate action found (\"${ACTION}\" and \"${CUR_PARAMETER}\")"
      fi
      ACTION="check"
      [[ ${CUR_PARAMETER} == *all ]] && DIRECTION="both"
      ;;

    status | status_all )
      if [ "${ACTION}"x != ""x ] ; then
        die 11 "Duplicate action found (\"${ACTION}\" and \"${CUR_PARAMETER}\")"
      fi
      ACTION="status"
      ;;
    
    close | closeall | disable | disableall | close_all | disable_all )
      if [ "${ACTION}"x != ""x ] ; then
        die 11 "Duplicate action found (\"${ACTION}\" and \"${CUR_PARAMETER}\")"
      fi
      ACTION="disable"
      [[ ${CUR_PARAMETER} == *all ]] && DIRECTION="both"
      ;;


    *:* )
      if [ "${VPN_SERVER_CONFIG}"x != ""x ] ; then
        die 11 "Duplicate parameter for the IP:port found (\"${VPN_SERVER_CONFIG}\" and \"${CUR_PARAMETER}\")"
      fi
      VPN_SERVER_CONFIG="${CUR_PARAMETER}"
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

    --* )
      die 17 "Unknown option found in the parameter: \"${CUR_PARAMETER}\")"
      ;;

    * )
      if [ "${VPN_CONFIG_FILE}"x != ""x ] ; then
        die 11 "Duplicate parameter for the config file found (\"${VPN_CONFIG_FILE}\" and \"${CUR_PARAMETER}\")"
      fi
      VPN_CONFIG_FILE="${CUR_PARAMETER}"
      ;;

  esac
done

if [ "${VPN_CONFIG_FILE}"x != ""x -a  "${VPN_SERVER_CONFIG}"x != ""x ] ; then
  die 15 "Either use the parameter for a config file (\"${VPN_CONFIG_FILE}\") or the parameter for the IP:PORT (\"${VPN_SERVER_CONFIG}\") - not both"
fi

# use default values if necessary
#
ACTION="${ACTION:=${DEFAULT_ACTION}}"

DIRECTION="${DIRECTION:=${DEFAULT_DIRECTION}}"

PROTOCOL="${PROTOCOL:=${DEFAULT_PROTOCOL}}"

# ---------------------------------------------------------------------

if [ ${PRINT_USAGE_HELP} = ${__TRUE} ] ; then
  grep "^#h#" $0 | cut -c4- | sed \
        -e "s#open_port_in_firewall.sh#$0#g" \
        -e "s#The default vpn config file is .*#The default vpn config file is \"${DEFAULT_VPN_CONFIG_FILE}\"#g" \
        -e "s#The default direction is.*#The default direction is \"${DEFAULT_DIRECTION}\"#g" \
        -e "s#The default action is.*#The default action is \"${DEFAULT_ACTION}\"#g" \
        -e "s#The default protocoll is.*#The default protocoll is \"${DEFAULT_PROTOCOL}\"#g" \
        -e "s/#VERSION#/${SCRIPT_VERSION}/g" 
  if [ ${VERBOSE}x != ""x ] ;then
    grep "^#H#" $0 | cut -c4- 
  else
    echo " Use the parameter \"-h -v\" to print the detailed usage help"
  fi
              
  die 0
fi


# ---------------------------------------------------------------------
# check pre-requisites for the script
#
THIS_USER=$( id -un )
if [ "${THIS_USER}"x != "root"x ] ; then
  die 100 "This script needs root access rights (the current user is \"${THIS_USER}\")"
fi

IPTABLES=$( which iptables )
if [ "${IPTABLES}"x = ""x ] ;then
  die 110 "The executable \"iptables\" does not exist"
fi

#
# the dig executable is only necessary if a hostname instead of an IP address is used
#
DIG="$( which dig )"
NAMESERVER_FOR_DIG="8.8.8.8"

# ---------------------------------------------------------------------

if [ "${VPN_SERVER_CONFIG}"x != ""x ] ; then
#
# use the ip:port found in the parameter
#
  LogMsg "Using the IP and port found in the parameter: ${VPN_SERVER_CONFIG}"
  CUR_VPN_SERVER_IP="${VPN_SERVER_CONFIG%:*}"
  CUR_VPN_SERVER_PORT="${VPN_SERVER_CONFIG#*:}"

  if [ "${CUR_VPN_SERVER_IP}"x = ""x -o "${CUR_VPN_SERVER_PORT}"x = ""x ] ; then
    die 25 "The remote server config found in the parameter is incomplete: \"${VPN_SERVER_CONFIG}\" "
  fi

else
#
# read ip:port from the VPN config file
#
  VPN_CONFIG_FILE="${VPN_CONFIG_FILE:=${DEFAULT_VPN_CONFIG_FILE}}"
    
  echo "Using the VPN config file \"${VPN_CONFIG_FILE}\" "
  if [ ! -r "${VPN_CONFIG_FILE}" ] ; then
    die 30 "The file \"${VPN_CONFIG_FILE}\" does not exist or is not readable"
  fi
  
  VPN_SERVER_CONFIG="$( grep "^remote" "${VPN_CONFIG_FILE}" | tr -d "\r" )"
  if [ "${VPN_SERVER_CONFIG}"x = ""x ] ; then
    die 35 "No remote server found in the file \"${VPN_CONFIG_FILE}\" "
  fi
   
  set -- ${VPN_SERVER_CONFIG}

  CUR_VPN_SERVER_IP="$2"
  CUR_VPN_SERVER_PORT="$3"
  
  if [ "${CUR_VPN_SERVER_IP}"x = ""x -o "${CUR_VPN_SERVER_PORT}"x = ""x ] ; then
    die 40 "The remote server config in the file \"${VPN_CONFIG_FILE}\" is incomplete: \"${VPN_SERVER_CONFIG}\" "
  fi
  
fi

# ---------------------------------------------------------------------
# check if ip:port is a hostname
#
if [[ ${CUR_VPN_SERVER_IP} != [0-9]* ]] ; then
  if [ "${DIG}"x = ""x ] ; then
    die 50  "${CUR_VPN_SERVER_IP} is not an IP address and the executable \"dig\" is not available."
  else 
    LogMsg "${CUR_VPN_SERVER_IP} is not an IP address  -- trying to resolve it via DNS server ..."
    TEST_IP="$( ${DIG} "${CUR_VPN_SERVER_IP}" +short @${NAMESERVER_FOR_DIG} )"

    if [ "${TEST_IP}"x = ""x ] ; then
      die 45 "Can not resolve \"${CUR_VPN_SERVER_IP}\" to an IP addresss"
    else
      LogMsg "The IP address for \"${CUR_VPN_SERVER_IP}\" is : \"${TEST_IP}\" "
      CUR_VPN_SERVER_IP="${TEST_IP}"
    fi
  fi
fi

# ---------------------------------------------------------------------

LogMsg ""
if [ "${DIRECTION}"x = "out"x ] ; then
  LogMsg "*** Processing only outgoing connections"
elif [ "${DIRECTION}"x = "in"x ] ; then
  LogMsg "*** Processing only incoming connections"
else
  LogMsg "*** Processing incoming and outgoing connections"
fi
LogMsg ""

if [ "${PROTOCOL}"x = "tcp"x ] ; then
  LogMsg "*** Processing only TCP connections"
elif [ "${PROTOCOL}"x = "udp"x ] ; then
  LogMsg "*** Processing only UDP connections"
else
  LogMsg "*** Processing TCP and UDP connections"
fi
LogMsg ""

# ---------------------------------------------------------------------

if [ "${ACTION}"x = "status"x ] ; then

# status -> show all connections TCP, UDP, incoming, outgoing

  DIRECTION="both"
  PROTOCOL="all"
  
  ACTION="check"
fi

# ---------------------------------------------------------------------

CUR_OUTPUT="$( read_firewall_rules )"

# ---------------------------------------------------------------------

if [ "${ACTION}"x = "check"x ] ; then

  LogMsg "Only retrieving the current firewall rules ..."

  if [ "${CUR_OUTPUT}"x != ""x ] ; then
      
    LogMsg "The active firewall rules for the IP ${CUR_VPN_SERVER_IP}, Port ${CUR_VPN_SERVER_PORT} in the firewall are:"
  
    LogMsg ""
    LogMsg "${CUR_OUTPUT}"
    LogMsg ""
    die 0
  else
    die 1 "There are no firewall rules for the IP ${CUR_VPN_SERVER_IP}, Port ${CUR_VPN_SERVER_PORT} in place"  
  fi

# ---------------------------------------------------------------------

elif [ "${ACTION}"x = "enable"x ] ; then

  LogMsg "Enabling connections for the IP ${CUR_VPN_SERVER_IP}, Port ${CUR_VPN_SERVER_PORT} in the firewall ..."

  if [ "${CUR_OUTPUT}"x != ""x ] ; then
    LogMsg "There are already firewall rules for this IP/Port in place:"
    LogMsg ""
    LogMsg "${CUR_OUTPUT}"
    LogMsg ""
  fi

    NEW_RULE_ADDED=${__FALSE}

    if [ "${DIRECTION}"x = "out"x -o "${DIRECTION}"x = "both"x ] ; then
# OUTGOING – from the device to  ${CUR_VPN_SERVER_IP}:${CUR_VPN_SERVER_PORT}

#      LogMsg "Enabling outgoing connections to the IP ${CUR_VPN_SERVER_IP}, Port ${CUR_VPN_SERVER_PORT} in the firewall ...."

        if [ "${PROTOCOL}"x = "tcp"x -o "${PROTOCOL}"x = "all"x ] ;then
                    ${IPTABLES} -C OUTPUT -p tcp -d ${CUR_VPN_SERVER_IP} --dport ${CUR_VPN_SERVER_PORT} -j ACCEPT 2>/dev/null 
          if [ $? -ne 0 ] ; then                  
            LogMsg "Enabling outgoing TCP connections to the IP ${CUR_VPN_SERVER_IP}, Port ${CUR_VPN_SERVER_PORT} in the firewall ...."

            ${PREFIX} ${IPTABLES} -A OUTPUT -p tcp -d ${CUR_VPN_SERVER_IP} --dport ${CUR_VPN_SERVER_PORT} -j ACCEPT  && NEW_RULE_ADDED=${__TRUE} 
          fi
        fi

       
        if [ "${PROTOCOL}"x = "udp"x -o "${PROTOCOL}"x = "all"x ] ;then
                    ${IPTABLES} -C OUTPUT -p udp -d ${CUR_VPN_SERVER_IP} --dport ${CUR_VPN_SERVER_PORT} -j ACCEPT 2>/dev/null
          if [ $? -ne 0 ] ; then                  
            LogMsg "Enabling outgoing UDP connections to the IP ${CUR_VPN_SERVER_IP}, Port ${CUR_VPN_SERVER_PORT} in the firewall ...."

            ${PREFIX} ${IPTABLES} -A OUTPUT -p udp -d ${CUR_VPN_SERVER_IP} --dport ${CUR_VPN_SERVER_PORT} -j ACCEPT && NEW_RULE_ADDED=${__TRUE} 
          fi
        fi
    fi
    
    if [ "${DIRECTION}"x = "in"x -o "${DIRECTION}"x = "both"x ] ; then
# INCOMING – from ${CUR_VPN_SERVER_IP}:${CUR_VPN_SERVER_PORT} to the device

      LogMsg "Enabling incoming connections from the IP ${CUR_VPN_SERVER_IP}, Port ${CUR_VPN_SERVER_PORT} in the firewall ...."

        if [ "${PROTOCOL}"x = "tcp"x -o "${PROTOCOL}"x = "all"x ] ;then
                    ${IPTABLES} -C INPUT -p tcp -s ${CUR_VPN_SERVER_IP} --sport ${CUR_VPN_SERVER_PORT} -j ACCEPT 2>/dev/null 
          if [ $? -ne 0 ] ; then                            
            LogMsg "Enabling incoming TCP connections from the IP ${CUR_VPN_SERVER_IP}, Port ${CUR_VPN_SERVER_PORT} in the firewall ...."

            ${PREFIX} ${IPTABLES} -A INPUT -p tcp -s ${CUR_VPN_SERVER_IP} --sport ${CUR_VPN_SERVER_PORT} -j ACCEPT && NEW_RULE_ADDED=${__TRUE}
          fi
        fi
          
        if [ "${PROTOCOL}"x = "udp"x -o "${PROTOCOL}"x = "all"x ] ;then
                      ${IPTABLES} -C INPUT -p udp -s ${CUR_VPN_SERVER_IP} --sport ${CUR_VPN_SERVER_PORT} -j ACCEPT 2>/dev/null
          if [ $? -ne 0 ] ; then                  

           LogMsg "Enabling incoming TCP connections from the IP ${CUR_VPN_SERVER_IP}, Port ${CUR_VPN_SERVER_PORT} in the firewall ...."
            ${PREFIX} ${IPTABLES} -A INPUT -p udp -s ${CUR_VPN_SERVER_IP} --sport ${CUR_VPN_SERVER_PORT} -j ACCEPT && NEW_RULE_ADDED=${__TRUE}
         fi
       fi
    fi

    if [ ${NEW_RULE_ADDED} = ${__TRUE} ] ; then
      LogMsg "One or more missing rules added"
    else
      LogMsg "All rules were already in place"
    fi

# ---------------------------------------------------------------------

else

  LogMsg "Disabling connections for the IP ${CUR_VPN_SERVER_IP}, Port ${CUR_VPN_SERVER_PORT} in the firewall ..."

  if [ "${CUR_OUTPUT}"x = ""x ] ; then
    die 0 "There are no firewall rules for this IP/Port in place"
  else

    RULES_DELETED=${__FALSE}

#    echo "Disabling connections to the IP ${CUR_VPN_SERVER_IP}, Port ${CUR_VPN_SERVER_PORT} in the firewall ...."

#
# there are different tables for input and output connections -> separate commands to delete rules are necessary
#
    if  [ "${DIRECTION}"x = "in"x -o "${DIRECTION}"x = "both"x ] ; then

      RULES_TO_DELETE=""
      CUR_FIREWALL_RULES="$( ${IPTABLES} -L INPUT --line-numbers -n | grep "[[:space:]]${CUR_VPN_SERVER_IP}[[:space:]]" | grep ":${CUR_VPN_SERVER_PORT}$" )"
         
      if [ "${PROTOCOL}"x = "udp"x -o "${PROTOCOL}"x = "all"x ] ;then
        RULES_TO_DELETE="${RULES_TO_DELETE}
$( echo "${CUR_FIREWALL_RULES}" | grep "[[:space:]]udp[[:space:]]" )"
      fi

      if [ "${PROTOCOL}"x = "tcp"x -o "${PROTOCOL}"x = "all"x ] ;then
        RULES_TO_DELETE="${RULES_TO_DELETE}
$( echo "${CUR_FIREWALL_RULES}" | grep "[[:space:]]tcp[[:space:]]" )"
      fi

      LogMsg "Removing these firewall rules for incoming connections:"
      LogMsg ""
      LogMsg "${RULES_TO_DELETE}"
      LogMsg ""
      
      RULES_TO_DELETE="$( echo "${RULES_TO_DELETE}" | tr "\t" " " | cut -f1 -d" " | grep -v -E "^$" | sort -n -r )"
      
      for CUR_RULE in ${RULES_TO_DELETE} ; do
        ${PREFIX} ${IPTABLES} -D INPUT ${CUR_RULE} && RULES_DELETED=${__TRUE}
      done

    fi
    
    if  [ "${DIRECTION}"x = "out"x -o "${DIRECTION}"x = "both"x ] ; then

      RULES_TO_DELETE=""
      CUR_FIREWALL_RULES="$( ${IPTABLES} -L OUTPUT --line-numbers -n | grep "[[:space:]]${CUR_VPN_SERVER_IP}[[:space:]]" | grep ":${CUR_VPN_SERVER_PORT}$" )"
         
      if [ "${PROTOCOL}"x = "udp"x -o "${PROTOCOL}"x = "all"x ] ;then
        RULES_TO_DELETE="${RULES_TO_DELETE}
$( echo "${CUR_FIREWALL_RULES}" | grep "[[:space:]]udp[[:space:]]" )"
      fi

      if [ "${PROTOCOL}"x = "tcp"x -o "${PROTOCOL}"x = "all"x ] ;then
        RULES_TO_DELETE="${RULES_TO_DELETE}
$( echo "${CUR_FIREWALL_RULES}" | grep "[[:space:]]tcp[[:space:]]" )"
      fi

      LogMsg "Removing these firewall rules for outgoing connections:"
      LogMsg ""
      LogMsg "${RULES_TO_DELETE}"
      LogMsg ""
      
      RULES_TO_DELETE="$( echo "${RULES_TO_DELETE}" | tr "\t" " " | cut -f1 -d" " | grep -v -E "^$" | sort -n -r )"
      
      for CUR_RULE in ${RULES_TO_DELETE} ; do
        ${PREFIX} ${IPTABLES} -D OUTPUT ${CUR_RULE} && RULES_DELETED=${__TRUE}
      done

    fi

    if [ ${RULES_DELETED} = ${__TRUE} ] ; then
      LogMsg "One or more rules deleted"
    else
      LogMsg "All rules are already deleted"
    fi

# OUTGOING – from the device to  ${CUR_VPN_SERVER_IP}:${CUR_VPN_SERVER_PORT}
#    ${PREFIX} ${IPTABLES} -D OUTPUT -p tcp -d ${CUR_VPN_SERVER_IP} --dport ${CUR_VPN_SERVER_PORT} -j ACCEPT
#    ${PREFIX} ${IPTABLES} -D OUTPUT -p udp -d ${CUR_VPN_SERVER_IP} --dport ${CUR_VPN_SERVER_PORT} -j ACCEPT

# INCOMING – from ${CUR_VPN_SERVER_IP}:${CUR_VPN_SERVER_PORT} to the device
#    ${PREFIX} ${IPTABLES} -D INPUT -p tcp -s ${CUR_VPN_SERVER_IP} --sport ${CUR_VPN_SERVER_PORT} -j ACCEPT
#    ${PREFIX} ${IPTABLES} -D INPUT -p udp -s ${CUR_VPN_SERVER_IP} --sport ${CUR_VPN_SERVER_PORT} -j ACCEPT

  fi
fi

echo ""

CUR_OUTPUT="$( read_firewall_rules )"

# script return code
#
THISRC=0

if [ "${ACTION}"x = "enable"x ] ; then

  LogMsg "The firewall rules in place are now:"
  
  LogMsg "${CUR_OUTPUT}"

  LogMsg "Checking the result ..."

  TEST_OUTPUT="$( echo "${CUR_OUTPUT}" | grep ACCEPT )"
  if [ "${TEST_OUTPUT}"x = ""x ] ; then
    LogError "Seems like something went wrong adding the firewall rules"

    LogMsg ""
    CUR_OUTPUT="$( read_firewall_rules all )"
    LogMsg "${CUR_OUTPUT}"
    LogMsg ""

    THISRC=250
  else
    LogMsg "OK; the new firewall rules are now in place"
  fi
else
  LogMsg "${CUR_OUTPUT}"

  LogMsg "Checking the result ..."

  TEST_OUTPUT="$( echo "${CUR_OUTPUT}" | grep  ACCEPT )"
  if [ "${TEST_OUTPUT}"x != ""x ] ; then
    LogError "Seems like something went wrong removing the firewall rules:"

    LogMsg ""
    CUR_OUTPUT="$( read_firewall_rules all )"
    LogMsg "${CUR_OUTPUT}"
    LogMsg ""

    THISRC=251
  else
    LogMsg "OK; the firewall rules are not active anymore"
  fi
fi  

die ${THISRC}
