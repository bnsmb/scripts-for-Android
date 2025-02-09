echo "Checking if Termux is already installed ..."

function adb_root {
	sleep 2
	adb shell su - -c $*
}

adb shell pm path com.termux
if [ $? -eq 0 ] ; then
	echo "Termux is already installed"
else
	
	echo "Installing the Termux App ...."

	/data/develop/android/scripts/install_apk.sh --install_on_phone /data/backup/Android/apps/com.termux_v118.apk 
fi

BACKUP_FILE="$( ls -1tr /data/backup/Android/termux/termux-full-backup-* | tail -1 )"
if [ -z ${BACKUP_FILE} ] ; then
	 echo "WARNING: No data backup file for Termux found"
else
	echo "Testing root access ..."
	adb_root id
	if [ $? -ne 0 ] ; then
		echo "ERROR: No root access via adb"
	else
   		echo "Restoring the backup from the file \"${BACKUP_FILE}\" ...."
		if [[ ${BACKUP_FILE} == *.gz ]] ; then
			TAR_OPTIONS="-xzf"
		else
			TAR_OPTIONS="-xf"
		fi
		export TAR_OPTIONS

		adb_root "mkdir -p /data/data/com.termux/files"
                sleep 2
		adb push ${BACKUP_FILE} /sdcard/Download/ && adb shell "su - -c 'cd /data/data/com.termux/files/ && tar ${TAR_OPTIONS} /sdcard/Download/${BACKUP_FILE##*/}  '"

#		cat ${BACKUP_FILE} | adb shell "su - -c 'cd /data/data/com.termux/files/ && tar ${TAR_OPTIONS} - '"

		echo "Correcting the permissions for the data files ..."

		CUR_USER="$( adb_root 'ls -ld /data/data/com.termux' | cut -f3 -d " " )"
		CUR_GROUP="$( adb_root 'ls -ld /data/data/com.termux' | cut -f4 -d " " )"

		adb_root "chown -R ${CUR_USER}:${CUR_GROUP}" /data/data/com.termux/files
		adb_root '/data/adb/magisk/busybox chcon --reference /data/data/com.termux  -R -h /data/data/com.termux/files '

		echo "Enable permissions for the app ..."
		adb_root "pm grant com.termux android.permission.POST_NOTIFICATIONS"
                adb_root "pm grant com.termux android.permission.READ_EXTERNAL_STORAGE"
		adb_root "pm grant com.termux android.permission.WRITE_EXTERNAL_STORAGE"
		adb_root "pm grant com.termux android.permission.READ_MEDIA_AUDIO"
                adb_root "pm grant com.termux android.permission.READ_MEDIA_VIDEO"
                adb_root "pm grant com.termux android.permission.ACCESS_MEDIA_LOCATION"
                adb_root "pm grant com.termux android.permission.READ_MEDIA_IMAGES"

# this permission can not be granted via pm command		
#                adb_root "pm grant com.termux android.permission.FOREGROUND_SERVICE"
#
                adb_root "test -f /data/adb/service.d/start_sshd_from_termux"
                if [ $? -eq 0 ] ; then
		       echo "The init script to start Termux already exists"
		else
			echo "Creating the Magisk init script to start Termux ..."
			echo '
if ! tty -s ; then
  exec >"/data/cache/${0##*/}.log" 2>&1
fi

TIMEOUT=60
i=0

echo "Waiting up to ${TIMEOUT} seconds for /data/data/com.termux  ..."
while [ $i -lt ${TIMEOUT} ] ; do
  ls -ld /data/data/com.termux 2>/dev/null && break
  sleep 1
  let  i=i+1
  printf "."
done
printf "\n"
echo "Wait time: $i seconds "

set -x
ls -lZ /data/data/com.termux

#
# start the Termux App to init the environment

  am start com.termux/.app.TermuxActivity

# the sshd must be started from within the Termux app -> add the start command for the sshd to the file ~/.profile for the Termux User
#

# check that the sshd is running
sleep 3
ps -ef | grep sshd

' | adb shell "su - -c tee -a /data/adb/service.d/start_sshd_from_termux" >/dev/null
 			adb_root "chmod 755 /data/adb/service.d/start_sshd_from_termux"

       fi
    fi
fi


 
