#!/bin/bash
#
# get_aosp_patches.sh - add an Android security patch to the local repos with a custom ROM
#
# Usage: get_aosp_patches.sh [new_tag] [yes]
#
# Supported environment variables:
#
#  NEW_TAG	
#    new tag to apply (will be overwritten by the parameter of the script if any)
#    If no new tag is defined in this variable or in the script parameters, the script will ask the user
#
#  YES
#    do not ask the user for confirmation if not empty
#    If this variable is not set and the "yes" parameter not used, the script will ask the user for confirmation before starting the merge.
#
#  VERBOSE
#    print some more messages if this variable is not empty	
#
#  GIT_PARAMETER
#    additional parameter for the command git
#    Do NOT use "-q" here because the script analyzes the messages written by git!
#
#  Documentation
#    https://bnsmb.de#How_to_apply_the_Android_Security_patches_to_a_local_repository
#
#  Author
#    Bernd.Schemmer (bnsmb01 (at) gmail dot com)    
#
#  History
#    17.01.2024 1.0.0.0 /bs
#      initial release
#
#    07.02.2024 1.1.0.0 /bs
#      the script failed to read and process the list of forked repositories from the OmniROM repo - fixed
#      removed the repo "build/make" from the exclude list
#
# ---------------------------------------------------------------------
# Note
# 
# There is an official script to apply an Android Security Patch to the OmniROM repositories available here:
#
# https://github.com/omnirom/android_vendor_omni/blob/android-14.0/utils/aosp-merge.sh
# 
# That script can be used to apply an Android Security Patch to the OmniROM repositories
#
# The list of forked AOSP repositories for the OmniROM is available here:
#
# https://github.com/omnirom/android_vendor_omni/blob/android-14.0/utils/aosp-forked-list
#
# ---------------------------------------------------------------------


#
# constants
#
__TRUE=0
__FALSE=1


SCRIPT_VERSION="1.0.0.0"

SCRIPT_NAME="${0##*/}"

# sitch to english
#
export LANG=C

# default tag to apply (if any is defined)
#
DEFAULT_NEW_TAG=""

# uncomment and change the next line to use a default new tag if neither the variable nor the parameter for the new tag is used
#
#DEFAULT_NEW_TAG="android-14.0.0_r21"

# set VERBOSE to a non-empty value before starting the script for more messages
# VERBOSE=1

# list of repositories to ignore
#
# (entries starting with a hash (#) in the list will be ignored)
#
# may be added to the exclude list:
#
# build/make
#
EXCLUDE_LIST="
device/google/gs101
device/google/gs101-sepolicy
device/google/gs201
device/google/gs201-sepolicy
device/google/gs-common
device/google/pantah
device/google/raviole
external/libdrm
hardware/google/pixel-sepolicy
system/core
system/timezone
packages/modules/Bluetooth
packages/modules/Wifi
"

# remove comments and empty lines from the EXCLUDE_LIST
#
EXCLUDE_LIST="$( echo ${EXCLUDE_LIST} | grep -v "^#" | tr "\n" " " )"

# current branch in the local repositories
#
BRANCH="android-14.0"

NEW_TAG="${NEW_TAG:=${DEFAULT_NEW_TAG}}"

# parameter for the git command
#
GIT_PARAMETER="${GIT_PARAMETER:=}"

# path to the local repositories
#
ROM_PATH="/data/develop/android/OmniROM_14.0"

#
DEFAULT_MANIFEST_FILE="${ROM_PATH}/.repo/manifests/default.xml"

 
# name of the manifest file with the AOSP repositories
#
REPO_XML_FILE_WITH_THE_AOSP_REPOSITORIES="omni-aosp.xml"

# name of the remote repository in the manifest
#
REMOTE_NAME="omnirom"

# AOSP repository URLs
#
# note: no trailing slash (/) for these URLs
#
AOSP_REPOSITORY_URL="https://android.googlesource.com"
AOSP_PLATFORM_REPOSITORY_URL="${AOSP_REPOSITORY_URL}/platform"
AOSP_GENERAL_REPOSITORY_URL="${AOSP_REPOSITORY_URL}"

# OmniROM repository specific URLs
#
OMNIROM_AOSP_FORKED_LIST_URL="https://raw.githubusercontent.com/omnirom/android_vendor_omni/android-14.0/utils/aosp-forked-list"


# variables for the summary messages
#
REPOS_MERGED=""
NO_OF_REPOS_MERGED=0

REPOS_FAILED=""
NO_OF_REPOS_FAILED=0

REPOS_UNCHANGED=""
NO_OF_REPOS_UNCHANGED=0

REPOS_NOT_FOUND=""
NO_OF_REPOS_NOT_FOUND=0

AOSP_REPOS_NOT_FOUND=""
AOSP_NO_OF_REPOS_NOT_FOUND=0

# Colors
#
red=$'\e[1;31m'
grn=$'\e[1;32m'
blu=$'\e[1;34m'
end=$'\e[0m'


# ---------------------------------------------------------------------

function LogMsg {
  [ "$1"x = "-"x ] && shift 

  typeset THISMSG="$*"

  echo "${THISMSG}"	
}

function LogError {
  typeset THISMSG="$*"
  LogMsg "ERROR: ${THISMSG}" >&2
}

function LogWarning {
  typeset THISMSG="$*"
  LogMsg "WARNING: ${THISMSG}"
}
  
function LogInfo {
  typeset THISMSG="$*"
  if [ "${VERBOSE}"x != ""x ] ; then
    LogMsg "INFO: ${THISMSG}" 
  fi
}

function die {
  typeset THISRC=${1:=0}

  typeset THISMSG=""
  if [ $# -gt 1 ] ; then
    shift
    THISMSG="$*"
    if [ ${THISRC} = 0 ] ; then
      LogMsg "${THISMSG}"
    else
      LogError "${THISMSG}"
    fi
  fi
  exit ${THISRC}
}

# ---------------------------------------------------------------------

function retrieve_repository_data {
  PLATFORM_SECURITY_PATCH="$( grep "^[[:space:]]*PLATFORM_SECURITY_PATCH[[:space:]]*:=" ${ROM_PATH}/build/make/core/version_defaults.mk | cut -f2 -d "="  | tr -d " " )"
  PLATFORM_VERSION_LAST_STABLE="$( grep "^[[:space:]]*PLATFORM_VERSION_LAST_STABLE[[:space:]]*:=" ${ROM_PATH}/build/make/core/version_defaults.mk | cut -f2 -d "="  | tr -d " " )"
  BUILD_ID="$( grep ^BUILD_ID ${ROM_PATH}/build/make/core/build_id.mk | cut -f2 -d "=" )"
  DEFAULT_REVISION="$( grep "default revision=" "${DEFAULT_MANIFEST_FILE}" | cut -f2 -d '"' )"
  DEFAULT_REVISION="${DEFAULT_REVISION##*/}"
#
# save the initial repository config
#
  INITIAL_PLATFORM_SECURITY_PATCH="${INITIAL_PLATFORM_SECURITY_PATCH:=${PLATFORM_SECURITY_PATCH}}"
  INITIAL_PLATFORM_VERSION_LAST_STABLE="${INITIAL_PLATFORM_VERSION_LAST_STABLE:=${PLATFORM_VERSION_LAST_STABLE}}"
  INITIAL_BUILD_ID="${INITIAL_BUILD_ID:=${BUILD_ID}}"
  INITIAL_DEFAULT_REVISION="${INITIAL_DEFAULT_REVISION:=${DEFAULT_REVISION}}"
}

function print_repository_data {
  LogMsg ""
  LogMsg "The Android version used is \"${PLATFORM_VERSION_LAST_STABLE}\""
  LogMsg "The platform security patch is now \"${PLATFORM_SECURITY_PATCH}\" "
  LogMsg "The BUILD_ID is now \"${BUILD_ID}\" "
  LogMsg "The Default Revision is now \"${DEFAULT_REVISION}\" "
  LogMsg ""
}

function print_initial_repository_data {
  LogMsg ""
  LogMsg "The initial Android version used is \"${INITIAL_PLATFORM_VERSION_LAST_STABLE}\""
  LogMsg "The initial platform security patch is now \"${INITIAL_PLATFORM_SECURITY_PATCH}\" "
  LogMsg "The initial BUILD_ID is now \"${INITIAL_BUILD_ID}\" "
  LogMsg "The initial Default Revision is now \"${INITIAL_DEFAULT_REVISION}\" "
  LogMsg ""
}


# ---------------------------------------------------------------------

LogMsg ""
LogMsg "${SCRIPT_NAME} ${SCRIPT_VERSION} - add an Android security patch to the local repos with a custom ROM"
LogMsg ""
LogMsg "Updating the repositories in the directory \"${ROM_PATH}\" ..."
LogMsg "-"

# ---------------------------------------------------------------------
# process the parameter
#

if [[ " ${GIT_PARAMETER} " == *\ -q\ * ]] ; then
  die 20 "The script will not work with the git parameter \"-q\" "
fi

if [ "$1"x = "-h"x -o "$1"x = "--help"x ] ; then
  die 0 "Usage: ${SCRIPT_NAME} [new_tag] [yes]"
fi

if [ $# -gt 2 ] ; then
  die 15 "Unknown parameter found: \"$*\" "  
fi

if [ "$2"x = "yes"x ] ; then
  YES=${__TRUE}
elif [ "$2"x != ""x ] ; then
  die 15 "Unknown parameter found: \"$2\" "  
fi
  
if [ "$1"x != ""x ] ; then
  NEW_TAG="$1"
else
  NEW_TAG="${NEW_TAG:=${DEFAULT_NEW_TAG}}"
fi

# ---------------------------------------------------------------------

LogMsg "Retrieving the current repo config ..."

retrieve_repository_data

# ---------------------------------------------------------------------
# create or update the temporary repository to list the availabe tags for Security patches
#
LogMsg "Retrieving the list of available git tags for the security patches ..."

if [ -d "${ROM_PATH}/manifest" ] ; then 
  if [ -d "${ROM_PATH}/manifest/.git" ] ; then
    LogMsg "Updating the temporary repo \"${ROM_PATH}/manifest\" ...."
    cd "${ROM_PATH}/manifest" && \
      git pull
    THISRC=$?
  else
    die 251 "The directory \"${ROM_PATH}/manifest\" exists but is not a git repository -- please delete the directory or fix it"
  fi
else  
  LogMsg "Creating the temporary repo \"${ROM_PATH}/manifest\" ...."
  mkdir -p "${ROM_PATH}/manifest" && \
    git clone ${AOSP_REPOSITORY_URL}/platform/manifest "${ROM_PATH}/manifest"
  THISRC=$?
fi

if [ ${THISRC} != 0 ] ; then
  LogWarning "Can not create/update the temporary repo \"${ROM_PATH}/manifest\" "
  AVAILABLE_TAGS=""
  NEWEST_TAG=""
else
  AVAILABLE_TAGS="$( cd "${ROM_PATH}/manifest" && git tag -l --sort="v:refname" "android-${PLATFORM_VERSION_LAST_STABLE}*" )"

  if [ "${AVAILABLE_TAGS}"x = ""x ] ; then
     LogWarning "Something went wrong retrieving the list of git tags available in the temporary repo \"${ROM_PATH}/manifest\" "
     NEWEST_TAG=""
  else
     NEWEST_TAG="$( echo  "${AVAILABLE_TAGS}" | tail -1 )"
  fi   
fi

if [ "${AVAILABLE_TAGS}"x != ""x ] ; then
  TAG_STRING=" $( echo "${AVAILABLE_TAGS}" | tr "\n" " " ) "
else
  TAG_STRING=""
fi


# ---------------------------------------------------------------------

if [ "${NEW_TAG}"x = "last"x ] ; then
  NEW_TAG="${NEWEST_TAG}"
fi

if [ "${NEW_TAG}"x = ""x  ] ; then
  USER_INPUT_OK=${__FALSE}

  LIST_AVAILABLE_TAGS=${__TRUE}
  
  while [ ${USER_INPUT_OK} = ${__FALSE} ] ; do

    if [ ${LIST_AVAILABLE_TAGS} = ${__TRUE} ] ; then

      LogMsg "The current config of the local repository is:"
  
      print_repository_data

      if [ "${AVAILABLE_TAGS}"x != ""x ] ; then
        LogMsg "The available tags are:" 
        LogMsg ""
        LogMsg "${AVAILABLE_TAGS}"
        LogMsg ""

      else 
        LogWarning "Could not retrieve the list of avaible git tags"
      fi
      LIST_AVAILABLE_TAGS=${__FALSE}
    fi
    
    printf "Please enter the tag that should be merged (enter \"list\" to view the tags available in the repository) : "
    read USER_INPUT
    [ "${USER_INPUT}"x = ""x ] && continue

    if [ "${USER_INPUT}"x = "list"x -o  "${USER_INPUT}"x = "l"x ] ; then
      LIST_AVAILABLE_TAGS=${__TRUE}
      continue
    fi

    if [ "${USER_INPUT}"x = "quit"x -o  "${USER_INPUT}"x = "q"x ] ; then
      die 10 "Script aborted by the user"
    fi
# merge the newest tag
#
    if [ "${USER_INPUT}"x = "last"x  ] ; then
      if [ "${AVAILABLE_TAGS}"x != ""x ] ; then
        NEW_TAG="${NEWEST_TAG}"
        USER_INPUT_OK=${__TRUE}
        break
      else
        LogWarning "No list of available tags available"
      fi
    fi      

# don't test the input if we did not get the list of available tags    
    [ "${TAG_STRING}"x = ""x ] && break
    
    if [[  "${TAG_STRING}" == *\ ${USER_INPUT}\ * ]] ; then
      NEW_TAG="${USER_INPUT}"
      USER_INPUT_OK=${__TRUE}
    else
      echo "The input \"${USER_INPUT}\" is invalid - please try again"
    fi
  done
  
else
  LogInfo "The available tags are:" && \
    LogMsg "${AVAILABLE_TAGS}"
fi
LogMsg ""

# ---------------------------------------------------------------------

LIST_OF_FORKED_AOSP_REPOSITORIES=""

if [ ${REMOTE_NAME} = "omnirom" ] ; then
  LogMsg "This is an update for the OmniROM -- trying to fetch the list of forked AOSP repositories from the official OmniROM repositories ..."
  TMPFILE="/tmp/forked_list.$$"
  
  wget "${OMNIROM_AOSP_FORKED_LIST_URL}" -O "${TMPFILE}"
  if [ $? -eq 0 -a ! -z "${TMPFILE}" ] ; then
    LIST_OF_FORKED_AOSP_REPOSITORIES="$( cat "${TMPFILE}" | tr "\n" " " )"
  else  
    LogError "Error retrieving the list of forked AOSP repositories -- will use the hardecoded exclude list only"
  fi
fi

# ---------------------------------------------------------------------

LogMsg "-"
LogMsg "Merging the tag \"${NEW_TAG}\" into the branch \"${BRANCH}\" "
LogMsg "-"
LogMsg "Updating the repositories in the directory \"${ROM_PATH}\" "
LogMsg "-"
LogMsg "The used AOSP repositories are:"
LogMsg "  ${AOSP_PLATFORM_REPOSITORY_URL}"
LogMsg "  ${AOSP_GENERAL_REPOSITORY_URL}"
LogMsg "-"
LogMsg "The default remote repository is : \"${REMOTE_NAME}\" "
LogMsg "-"
LogMsg "The used git parameter are: \"${GIT_PARAMETER}\" "
LogMsg "-"

# ---------------------------------------------------------------------


# ---------------------------------------------------------------------

if [ "${YES}"x = ""x ] ; then
  LogMsg "-"
  printf "Enter <return> to continue with the merge: "
  read USER_INPUT
  [ "${USER_INPUT}"x = "q"x -o "${USER_INPUT}"x = "Q"x -o "${USER_INPUT}"x = "quit"x ] && die 250 "Script aborted by the user"
  LogMsg "-"
fi

# ---------------------------------------------------------------------

CUR_MANIFEST="${ROM_PATH}/.repo/manifests/${REPO_XML_FILE_WITH_THE_AOSP_REPOSITORIES}"

LogMsg "-"
LogMsg "Processing the repositories listed in the manifest \"${CUR_MANIFEST}\" with the remote repo \"${REMOTE_NAME}\" ..."

for CUR_REPO in $( \grep "remote=\"${REMOTE_NAME}\"" "${CUR_MANIFEST}"  | awk '{print $2}' | awk -F '"' '{print $2}' ) ; do 
  LogMsg ""
  echo "----------------------------------------------------------------- "
  
  LogMsg "Processing the repository \"${CUR_REPO}\" ..."
  
  if [ "${LIST_OF_FORKED_AOSP_REPOSITORIES}"x != ""x ] ; then
    [ "${CUR_REPO}"x = "build/make"x ] && AOSP_REPO="build"
     
    if [[ " ${LIST_OF_FORKED_AOSP_REPOSITORIES} " != *\ ${AOSP_REPO}\ * ]] ; then
      LogMsg "+++ The repository \"${AOSP_REPO}\" is in not in the list of forked ASOP repositories for the OmniROM - skipping this repo"
      continue
    fi
  fi
  
  if [[ " ${EXCLUDE_LIST} " == *\ ${CUR_REPO}\ * ]] ; then
    LogMsg "+++ The repository \"${CUR_REPO}\" is in the exclude list - skipping this repo"
    continue
  fi
  
  CUR_REPO_DIRECTORY="${ROM_PATH}/${CUR_REPO}"
  
  if [ ! -d "${CUR_REPO_DIRECTORY}" ] ; then
    LogError "The repo directory \"${CUR_REPO_DIRECTORY}\" does not exist - skipping this repo"

    REPOS_NOT_FOUND="${REPOS_NOT_FOUND}
${CUR_REPO}"
    (( NO_OF_REPOS_NOT_FOUND = NO_OF_REPOS_NOT_FOUND +1 ))

    continue
  fi
  
  cd "${CUR_REPO_DIRECTORY}"
  if [ $? -ne 0 ] ; then
    LogError "Can not change working directory to the repo directory \"${CUR_REPO_DIRECTORY}\" - skipping this repo"

    REPOS_NOT_FOUND="${REPOS_NOT_FOUND}
${CUR_REPO}"
    (( NO_OF_REPOS_NOT_FOUND = NO_OF_REPOS_NOT_FOUND +1 ))

    continue
  fi

  LogMsg "Checking if the AOSP repository for \"${CUR_REPO}\" exists ...."

# fyi
#
#  AOSP_PLATFORM_REPOSITORY_URL="${AOSP_REPOSITORY_URL}/platform"
#  AOSP_GENERAL_REPOSITORY_URL="${AOSP_REPOSITORY_URL}"
#
  
  if [[ "${CUR_REPO}" = "build/make" ]] ; then
    CUR_AOSP_REPOSITORY="${AOSP_PLATFORM_REPOSITORY_URL}/build"
  else

    CUR_AOSP_REPOSITORY="${AOSP_PLATFORM_REPOSITORY_URL}/${CUR_REPO}"

    wget ${WGET_PARAMETER} -q --spider "${CUR_AOSP_REPOSITORY}"
    if [ $? -ne 0 ] ; then
      CUR_AOSP_REPOSITORY="${AOSP_GENERAL_REPOSITORY_URL}/${CUR_REPO}"

      wget ${WGET_PARAMETER} -q --spider "${CUR_AOSP_REPOSITORY}"
      if [ $? -ne 0 ] ; then
        LogWarning "The AOSP repository for \"${CUR_AOSP_REPOSITORY}\" does not exist"

        AOSP_REPOS_NOT_FOUND="${AOSP_REPOS_NOT_FOUND}
${CUR_REPO}"
        (( AOSP_NO_OF_REPOS_NOT_FOUND = AOSP_NO_OF_REPOS_NOT_FOUND +1 ))

        continue
      fi
    fi
  fi  

  LogMsg "Using the AOSP repository \"${CUR_AOSP_REPOSITORY}\" for the local repository \"${CUR_REPO}\" "

# get the remote repo for this repo 
# if there are more then one remote repos configured for a repo we use the 1st one only
#
  CUR_REMOTE_NAME="$( git remote | head -1 )"
  if [ "${CUR_REMOTE_NAME}"x = ""x ] ; then
    LogWarning "Can not detect the remote repository for \"${CUR_REPO}\" will try with \"${REMOTE_NAME}\" now"
    CUR_REMOTE_NAME="${REMOTE_NAME}"
  else
    LogMsg "The remote repository for this repo is \"${CUR_REMOTE_NAME}\" "
  fi

  LogMsg "Cleanup the repository ..."
  ${PREFIX} git merge --abort
  THISRC=$?
  LogMsg "The RC is ${THISRC}"
  
  LogMsg "Fetching the tag \"${NEW_TAG}\" from the AOSP repository \"${CUR_AOSP_REPOSITORY}\" ..."  
  ${PREFIX} git fetch "${CUR_AOSP_REPOSITORY}" "${NEW_TAG}"
  THISRC=$?
  LogMsg "The RC is ${THISRC}"

  if [ ${THISRC} = 0 ] ; then
    LogMsg "Merging the tag \"${NEW_TAG}\" into the branch \"${CUR_BRANCH}\" ..."

    CUR_OUTPUT="$( ${PREFIX} git merge  FETCH_HEAD ${GIT_PARAMETER} -m "${NEW_TAG}" 2>&1 )"
    THISRC=$?
   
    LogMsg "${CUR_OUTPUT}"
    LogMsg ""
    LogMsg "The RC is ${THISRC}"
    LogMsg ""   

    if [[ "${CUR_OUTPUT}" == *CONFLICT* ]] ; then
      LogMsg "Conflicts found -- new tag not merged"

      REPOS_FAILED="${REPOS_FAILED}
${CUR_REPO}"
      (( NO_OF_REPOS_FAILED = NO_OF_REPOS_FAILED +1 ))
      
    elif [[ "${CUR_OUTPUT}" == *"Merging is not possible"* ]] ; then

      LogMsg "Merging is not possible -- new tag not merged"

      REPOS_FAILED="${REPOS_FAILED}
${CUR_REPO}"
      (( NO_OF_REPOS_FAILED = NO_OF_REPOS_FAILED +1 ))

    elif [[ "${CUR_OUTPUT}" == *"Merge made"* ]] ; then
      LogMsg "New tag successfully merged"

      REPOS_MERGED="${REPOS_MERGED}
${CUR_REPO}"
      (( NO_OF_REPOS_MERGED = NO_OF_REPOS_MERGED +1 ))

    elif [[ "${CUR_OUTPUT}" == *"Already up to date"* ]] ; then

      LogMsg "The repository is already up to date"
#      ${PREFIX} git reset ${GIT_PARAMETER} --hard 
#      THISRC=$?
#      LogMsg "The RC is ${THISRC}"

      REPOS_UNCHANGED="${REPOS_UNCHANGED}
${CUR_REPO}"
      (( NO_OF_REPOS_UNCHANGED = NO_OF_REPOS_UNCHANGED +1 ))
    else
      LogMsg "Merging status unknown -- please check the git messages manually"

      REPOS_FAILED="${REPOS_FAILED}
${CUR_REPO}"
      (( NO_OF_REPOS_FAILED = NO_OF_REPOS_FAILED +1 ))

    fi

  else
    LogWarning "No Tag \"${NEW_TAG}\" found for the repository \"${CUR_AOSP_REPOSITORY}\" "
    REPOS_FAILED="${REPOS_FAILED}
${CUR_REPO}"
    (( NO_OF_REPOS_FAILED = NO_OF_REPOS_FAILED +1 ))
  fi

done

LogMsg ""
LogMsg " ... all repositories processed".

# ---------------------------------------------------------------------

LogMsg "----------------------------------------------------------------- "

LogMsg ""
LogMsg "Updating the manifest file \"${DEFAULT_MANIFEST_FILE}\" ..."

cp "${DEFAULT_MANIFEST_FILE}" "${DEFAULT_MANIFEST_FILE}".backup.$$

sed -i  \
    -e "s#${DEFAULT_REVISION}#${NEW_TAG}#g" \
    -e "/superproject/ s#revision=\".*\"#revision=\"${NEW_TAG}\"#g" \
    "${DEFAULT_MANIFEST_FILE}" 

LogInfo "Result: " && \
  diff "${DEFAULT_MANIFEST_FILE}" "${DEFAULT_MANIFEST_FILE}".backup.$$

# ---------------------------------------------------------------------

LogMsg ""
LogMsg "----------------------------------------------------------------- "
LogMsg "--- Summary ---"
LogMsg ""

if [ ${NO_OF_REPOS_MERGED} != 0 ] ; then
  LogMsg ""
  LogMsg "${NO_OF_REPOS_MERGED} repo(s) merged: "
  LogMsg "${REPOS_MERGED}"
fi

if [ ${NO_OF_REPOS_FAILED} != 0 ] ; then
  LogMsg ""
  LogMsg "${NO_OF_REPOS_FAILED} repo(s) failed: "
  LogMsg "${REPOS_FAILED}"
fi

if [ ${NO_OF_REPOS_UNCHANGED} != 0 ] ; then
  LogMsg ""
  LogMsg "${NO_OF_REPOS_UNCHANGED} repo(s) already up to date: "
  LogMsg "${REPOS_UNCHANGED}"
fi

if [ ${NO_OF_REPOS_NOT_FOUND} != 0 ] ; then
  LogMsg ""
  LogMsg "${NO_OF_REPOS_NOT_FOUND} repo(s) not found: "
  LogMsg "${REPOS_NOT_FOUND}"
fi

if [ ${AOSP_NO_OF_REPOS_NOT_FOUND} != 0 ] ; then
  LogMsg ""
  LogMsg "${AOSP_NO_OF_REPOS_NOT_FOUND} AOSP repo(s) not found: "
  LogMsg "${AOSP_REPOS_NOT_FOUND}"
fi


LogMsg "----------------------------------------------------------------- "

retrieve_repository_data

LogMsg ""
LogMsg "The repository config before starting this script was:"
print_initial_repository_data
LogMsg ""
LogMsg "The repository config now is:"
print_repository_data
LogMsg "----------------------------------------------------------------- "
echo ""

LogMsg "----------------------------------------------------------------- "

# ---------------------------------------------------------------------

die 0

# ---------------------------------------------------------------------
