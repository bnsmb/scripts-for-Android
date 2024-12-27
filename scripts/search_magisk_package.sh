#!/system/bin/sh
#
# search_magisk_package.sh - quick and dirty script to search the package name for the hiddne Magisk App
#
# Usage:  search_magisk_package.sh
#
# History
#   05.12.2024/bs
#     initial release
#
#
function die {
  typeset THISRC=$1
  [ $# -ne 0 ] && shift
  typeset THISMSG="$*"
  
  echo "ERROR: ${THISMSG}"
  
  exit ${THISRC}
}

echo "Searching a hidden Magisk app ..."


MAGISK_PACKAGE_NAME="$( pm list packages | grep magisk | cut -f2 -d":" )"
if [ "${MAGISK_PACKAGE_NAME}"x != ""x ] ; then
  echo "
Magisk is not hidden

Use the command

am start -n com.topjohnwu.magisk/.ui.MainActivity

to start the Magisk App in a shell
"
  exit 0
fi

LIST_OF_PACKAGES="$( pm list packages | cut -f2- -d":" | grep -E -v "^com." )"
if [ "${LIST_OF_PACKAGES}"x = ""x ] ; then
  die 5 "Can not retrieve the list of installed packages"
fi

for CUR_PACKAGE in ${LIST_OF_PACKAGES} ; do
  echo "Checking the package \"${CUR_PACKAGE}\" ..."
  CURRENT_APK="$( dumpsys package "${CUR_PACKAGE}" | grep current.apk | tr -d "\t " )"

  su - -c unzip -t  "${CURRENT_APK}"  2>/dev/null | grep libmagiskboot.so >/dev/null
  if [ $? -eq 0 ] ; then
    echo "
The package name for Magisk is \"${CUR_PACKAGE}\" 

To start the Magisk App in a shell use this command: 

monkey -p ${CUR_PACKAGE} -c android.intent.category.LAUNCHER 1    

"
    exit 0
  fi
done
echo " .. all installed packages checked- there is no Magisk installed"
exit 1


