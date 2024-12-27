echo ""
echo "Patch levels in the repositories on this machine :"
echo ""
/data/develop/android/scripts_on_linux/print_security_patch /data/develop/android/OmniROM*  /devpool001/develop/OmniROM_1*  2>/dev/null

ping -W 2 -c 1 192.168.1.126   2>/dev/null 1>/dev/null
if [ $? -eq 0 ] ; then
	echo ""
	echo "Patch levels in the repositories on the DEV machine:"
	echo ""

        ssh 192.168.1.126 /data/develop/android/scripts_on_linux/print_security_patch /data/develop/android/OmniROM* 2>/dev/null
else
	echo ""
	echo "WARNING: The dev machine is not up and running"	
fi
echo ""

