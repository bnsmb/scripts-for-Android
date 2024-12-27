#!/bin/bash
#
# simple script to sign an apk file with the keys of my self compiled custom rom
#
# History
#   
#   28.08.2024 1.0.0 /bs
#     initial public release
#     added coed to make the script more general 
#     print more messages
#

__TRUE=0
__FALSE=1

# executable used in this script
ä
APKSIGNER="/data/develop/android/Sdk/build-tools/33.0.0/lib/apksigner.jar"
ZIPALIGN="/data/develop/android/otatools/bin/zipalign"
ZIP="/usr/bin/zip"

# certificate used to sign the apk file
#
KEY_DIRECTORY="/data/develop/android/security"

PK8_FILE="${KEY_DIRECTORY}/platform.pk8"
PEM_FILE="${KEY_DIRECTORY}/platform.x509.pem"

# more global variables

TMP_AKP_FILE=""


if [ $# -eq 0 -o "$1"x = "-h"x -o "$1"x = "--help"x ] ; then
  echo "Usage: $0 [apk_to_sign] [signed_apk]"
  exit 1
fi

ERRORS_FOUND=${__FALSE}

if [ ! -r "${APKSIGNER}" ] ; then
  echo "ERROR: ${APKSIGNER} not found"
  ERRORS_FOUND=${__TRUE}
fi

if [ ! -x "${ZIP}" ] ; then
  echo "ERROR: ${ZIP} not found or not executable"
  ERRORS_FOUND=${__TRUE}
fi
  
if [ ! -x "${ZIPALIGN}" ] ; then
  echo "ERROR: ${ZIPALIGN} not found or not executable"
  ERRORS_FOUND=${__TRUE}
fi

if [ ! -r "${PK8_FILE}" ] ; then
  echo "ERROR: ${PK8_FILE} not found"
  ERRORS_FOUND=${__TRUE}
fi

if [ ! -r "${PEM_FILE}" ] ; then
  echo "ERROR: ${PEM_FILE} not found"
  ERRORS_FOUND=${__TRUE}
fi

if [ $# -gt 2 ] ; then
  echo "ERROR: Too many parameter: $*"
  ERRORS_FOUND=${__TRUE}
fi

if [ ${ERRORS_FOUND} = ${__TRUE} ] ; then
  echo "ERROR: One or more errors found"
  exit 10
fi

APK_FILE="$1"
if [ $# -eq 2 ] ; then
  NEW_APK_FILE="$2"
else
  NEW_APK_FILE="$1.signed"
fi

echo ""
echo "Signing the apk file \"${APK_FILE}\" with the Certificate \"${PEM_FILE}\"; the name for the signed apk file is \"${NEW_APK_FILE}\" "

echo ""
echo "The certificate \"${PEM_FILE}\" is:"
echo
openssl x509 -in "${PEM_FILE}" -text -noout | head -11
echo "..."
echo 

CUR_APK_CERTIFICATE="$( unzip -p "${APK_FILE}" "META-INF/*.RSA" | keytool -printcert )"
if [ $? -eq 0 ] ; then
  echo ""
  echo "The apk \"${APK_FILE}\" is signed with this certificate:"
  echo ""
  echo "${CUR_APK_CERTIFICATE}" | head -7
  echo
else
  echo "WARNING: Can not read the certificate used for the apk file \"${APK_FILE}\" "
fi

if [ ! -r "${APK_FILE}" ]; then
  echo "ERROR: apk file \"${APK_FILE}\" not found"
  exit 15
fi

if [ -r "${NEW_APK_FILE}" ]; then
  echo "ERROR: The new apk file \"${NEW_APK_FILE}\" already exists"
  exit 17
fi

if [ "${APK_FILE}"x = "${NEW_APK_FILE}"x ] ; then
  echo "ERROR: The names of the existing and the new apk file must be different"
  exit 19
fi

APK_FILE_TYPE="$( file "${APK_FILE}" )"
if [[ ${APK_FILE_TYPE} != *Java\ archive\ data* ]] ; then
 
  unzip -t "${APK_FILE}" AndroidManifest.xml 2>/dev/null 1>/dev/null
  if [ $? -ne 0 ] ; then
    echo "ERROR: The file \"${APK_FILE}\" is not an apk file"
    exit 20
  fi
fi

TMP_AKP_FILE="${APK_FILE}.$$"

echo "Creating a temporary copy of the apk file in \"${TMP_AKP_FILE}\" ..."

cp  "${APK_FILE}" "${TMP_AKP_FILE}" 
if [ $? -ne 0 ] ; then
  echo "ERROR: Error creating a temporary copy of the apk file in \"${TMP_AKP_FILE}\" "
  exit 21
fi

APK_FILE="${TMP_AKP_FILE}" 

echo "Removing the existing certificate files from the apk file \"${APK_FILE}\" ...."

${ZIP} -d "${APK_FILE}" "META-INF/*.SF" "META-INF/*.RSA"

echo "Doing a zip align for the apk file \"${APK_FILE}\" ..."
${ZIPALIGN} 4 "${APK_FILE}" "${NEW_APK_FILE}"

echo "Checking the result of the zip align ..."

CUR_OUTPUT="$( ${ZIPALIGN} -c 4  "${NEW_APK_FILE}" 2>&1 )"
if [ "${CUR_OUTPUT}"x != ""x ] ; then
  echo "${CUR_OUTPUT}"
  echo "WARNING: zipalign seems to have failed for the file \"${NEW_APK_FILE}\" "
fi

echo "Now signing the apk file  \"${NEW_APK_FILE}\" with the certificate \"${PEM_FILE}\" ..."

java -jar "${APKSIGNER}" sign --key "${PK8_FILE}"  --cert "${PEM_FILE}"  "${NEW_APK_FILE}"
if [ $? -ne 0 ] ; then
  echo "WARNING: Signing the apk file e \"${NEW_APK_FILE}\"  probably failed"
  exit 100
else
 
  NEW_APK_CERTIFICATE="$( unzip -p "${NEW_APK_FILE}" "META-INF/*.RSA" | keytool -printcert )"  
  if [ $? -eq 0 ] ; then
    echo "... all done"
    echo
    echo "The apk is \"${NEW_APK_FILE}\" signed with this certificate:"
    echo ""
    echo "${NEW_APK_CERTIFICATE}" | head -7 
    echo
  else
    echo "WARNING: Can not read the certificate used for the apk file \"${NEW_APK_FILE}\" "
  fi

  \rm -f "${TMP_AKP_FILE}" 
 
fi
