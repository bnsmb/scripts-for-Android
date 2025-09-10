#!/bin/ksh
#
# Linux shell script to boot an Android phone from an TWRP (or TWRP compatible) image
# The script can also be used to only print the current status of the Android phone
#
# The script can be used as include file or as standalone script
#

#S# ---------------------------------------------------------------------
#S# To use the script as include file add the statement
#S#
#S# . ./boot_phone_from_twrp.sh
#S#
#S# to your file
#S#
#S# Set the variable EXECUTE_BOOT_PHONE_FROM_TWRP_INIT to 1 to disable the initialization code in this script .
#S#
#S# If used as include file the script
#S#
#S# - defines these constants if not already defined:
#S#
#S#   __TRUE
#S#   __FALSE
#S#
#S# - defines these functions if not already defined:
#S#
#S#   LogMsg
#S#   LogError
#S#   LogInfo
#S#   LogWarning
#S#   isNumber
#S#   wait_some_seconds
#S#
#S# - defines these functions (overwriting existing functions with the same name):
#S#
#S#   check_prereqs_for_boot_phone_from_twrp
#S#   init_global_vars_for_boot_phone_from_twrp
#S#
#S#   set_serial_number
#S#
#S#   retrieve_phone_status
#S#   print_phone_status
#S#   convert_phone_status_into_status_string
#S#
#S#   boot_phone_from_the_TWRP_image
#S#   reboot_phone
#S#
#S#   wait_for_phone_to_be_in_the_bootloader
#S#   wait_for_phone_with_a_working_adb_connection 
#S#   wait_for_the_adb_daemon
#S#   wait_until_an_android_service_is_ready
#S#   wait_until_data_is_mounted
#S#   check_access_via_adb
#S#
#S#   decrypt_data
#S#   umount_data
#S#   format_data
#S#   wipe_cache
#S#   wipe_data
#S#   wipe_dalvik
#S#   format_metadata
#S#
#S#   upload_file_to_the_phone
#S#   download_file_from_the_phone
#S#   copy_file_on_the_phone
#S#
#S#   start_adb_daemon
#S#   kill_adb_daemon
#S#   restart_adb_daemon
#S#
#S#   get_usb_device_for_the_phone
#S#   reset_usb_port
#S#   reset_the_usb_port_for_the_phone
#S#   reset_the_usb_port_for_the_phone_if_necessary
#S#   online_adb_connection
#S#
#S#   print_global_variables
#S#   list_running_adb_daemons
#S#
#S#   enable_safe_mode
#S#
#S#   boot_phone_from_twrp_die
#S#
#S#   check_android_boot_image
#S#   get_twrp_image_for_the_installed_OS
#S#   select_twrp_image_for_install_image
#S#
#S#
#S# The script using this script as an include file can optional define these variables before
#S# including this script (see the source code below for the meaning of these variables):
#S#
#S#    EXECUTE_BOOT_PHONE_FROM_TWRP_INIT
#S#
#S#    SUDO_PREFIX
#S#    CUR_USER
#S#
#S#    FORCE_BOOT_INTO_TWRP_IMAGE 
#S#    FORCE_REBOOT_INTO_TWRP_IMAGE
#S#
#S#    TWRP_IMAGE
#S#    SERIAL_NUMBER
#S#
#S#    ADB_DAEMON_WAIT_TIME
#S#    FASTBOOT_WAIT_TIME
#S#    ADB_BOOT_WAIT_TIME
#S#    DECRYPT_DATA_WAIT_TIME
#S#    ADB_SERVICE_WAIT_TIME
#S#    FASTBOOT_TIMEOUT
#S#    FASTBOOT_OPTIONS
#S#    ADB_OPTIONS
#S#    ADB_PORT
#S#    RESTART_BOOT_LOADER
#S#
#S#    CHECK_ONLY
#S#    PRINT_STATUS
#S#
#S#    RESET_THE_USB_PORT
#S#
#S#    USER_PASSWORD
#S#
#S#    ADB
#S#    FASTBOOT
#S#    TIMEOUT
#S#    USBRESEST
#S#
#S#
#S# The global variables listed above are defined in any case after including this script.
#S#
#S# The variable USER_PASSWORD is only used if the phone is protected by a pin or something similar
#S#   
#S# The global variables listed below are set by the functions in this file:
#S#
#S#    Variable Name                         Contents                                                              set by the function
#S#    ----------------------------------------------------------------------------------------------------------------------------------------
#S#
#S#    TEMP_TWRP_IMAGE_TO_USE                TWRP image that should be used for the installed OS                   get_twrp_image_for_the_installed_OS, select_twrp_image_for_install_image
#S#    CURRENT_INSTALLED_ROM                 Installed ROM on the phone                                            get_twrp_image_for_the_installed_OS
#S#    CURRENT_INSTALLED_ROM_VERSION         version of the installed ROM                                          get_twrp_image_for_the_installed_OS
#S#
#S#    PHONE_STATUS                          current status of the phone                                           retrieve_phone_status
#S#    PHONE_STATUS_OUTPUT                   the last error message regarding the status of the phone              retrieve_phone_status
#S#    PROP_RO_TWRP_BOOT                     the value of the property.ro.twrp.boot                                retrieve_phone_status
#S#    PROP_RO_BOOTMODE                      the value of the property ro.bootmode                                 retrieve_phone_status
#S#    PROP_RO_BUILD_DESCRIPTION             the value of the property property ro.build.description               retrieve_phone_status
#S#    PROP_RO_PRODUCT_BUILD_VERSION_RELEASE the value of the property ro.product.build.version.release            retrieve_phone_status
#S#    BOOT_SLOT                             the current boot slot : either _a or _b or empty                      retrieve_phone_status
#S#    INACTIVE_SLOT                         the inactive slot : either _a or _b or empty                          retrieve_phone_status
#S#    RUNNING_IN_AN_ADB_SESSIION            is ${__TRUE} if the script is running in an adb session               retrieve_phone_status
#S#    ROM_NAME                              name of the OS running on the phone                                   retrieve_phone_status
#S#    PHONE_IN_EDL_MODE                     lsusb entry for phones in EDL mode                                    retrieve_phone_status
#S#    PHONE_USB_DEVICE                      path to the USB port used for the phone                               retrieve_phone_status
#S#    PHONE_BOOT_ERROR                      contains the error code if booting the phone fails                    boot_phone_from_the_TWRP_image
#S#    OS_BUILD_TYPE                         contains the build of the installed OS (eng, userdebug, or user)      retrieve_phone_status
#S#    OS_PATCH_LEVEL                        contains the patch level of the installed OS                          retrieve_phone_status
#S#    PROP_RO_SECURE                        the value of the property ro.secure                                   retrieve_phone_status
#S#    PROP_RO_DEBUGGABLE                    the value of the property ro.debuggable                               retrieve_phone_status
#S#    PROP_RO_MODVERSION                    the value of the property ro.modversion                               retrieve_phone_status
#S#    ORANGE_FOX_SYSTEM_RELEASE             the value of the property orangefox.system.release                    retrieve_phone_status
#S#    TWRP_COMPATIBLE                       this variable is "0" if the running recovery is compatible to TWRP    retrieve_phone_status
#S#
#S# Note: OrangeFox is treaded as TWRP; check the variable ORANGE_FOX_SYSTEM_RELEASE to distinguish between TWRP and OrangeFox
#S#       (the variable ORANGE_FOX_SYSTEM_RELEASE is empty if not using the OrangeFox recovery)
#S#
#S# ------------------------------------------------------------------------------------------------------------------------------ 
#S# The ROMs known by the function "select_twrp_image_for_install_image" are read from the variable TWRP_IMAGES_FOR_IMAGE_FILES
#S# 
#S# The format of the entries in the variable TWRP_IMAGES_FOR_IMAGE_FILES is:
#S# 
#S# each line must contain these fields (the field separator is a colon ":"; lines starting with a hash "#" are ignored) :
#S#
#S# regex for the image file : TWRP image to use : Name of the ROM : description
#S#
#S# The fields for the name of the ROM and the description are optional
#S#
#S# The regex can only contain the joker characters "?" and "*"
#S# 
#S#
#S# ------------------------------------------------------------------------------------------------------------------------------ 
#S# The ROMs known by the function "get_twrp_image_for_the_installed_OS" is read from the variable TWRP_IMAGES_FOR_THE_RUNNING_OS
#S#
#S# The format of the entries in the variable TWRP_IMAGES_FOR_THE_RUNNING_OS is:
#S#
#S# each line must contain these fields (the field separator is a colon ":"; lines starting with a hash "#" are ignored) :
#S#
#S# property : value : TWRP image to use : Name of the ROM : description
#S#
#S# Use "*" for the field "value" if the property must be defined but the value is meaningless
#S#
#S# The fields for the name of the ROM and the description are optional
#S#
#S# See below for examples.
#S#    
#S# Note: The function "get_twrp_image_for_the_installed_OS" is used to get the TWRP image to use if the script is called without a 
#S#       parameter for the TWRP image to use.
#S#       If the function does not find a TWRP image for the running OS, the TWRP image defined in the variable TWRP_IMAGE is used.
#S#       The default value for the variable TWRP_IMAGE is the value of the variable DEFAULT_TWRP_IMAGE hardcoded in the script
#S#
#S# ------------------------------------------------------------------------------------------------------------------------------ 
#S# The ROMs known by the function "retrieve_phone_status" script are:
#S#
#S#    ASUS Android
#S#    OmniROM
#S#    LineageOS
#S#    StatiXOS
#S#    LMODroid
#S#    /e/
#S#
#S# 
#S# ------------------------------------------------------------------------------------------------------------------------------ 
#S#
#S# The status of the phone is stored in the global variable PHONE_STATUS:
#S#
#S#     1 - the phone is already booted from the TWRP image (or a known TWRP compatible image)
#S#     2 - the phone is booted from TWRP installed in the boot or recovery partition (or known TWRP compatible recvovery)
#S#     3 - the phone is booted into the Android OS
#S#     4 - the phone is booted into bootloader 
#S#     5 - the phone is booted into the fastbootd
#S#     6 - the phone is booted into the safe mode of the Android OS
#S#     7 - the phone is booted into the a non-TWRP recovery installed in the boot or recovery partition
#S#     8 - the phone is booted into sideload mode
#S#     9 - the phone is booted into a recovery without working adb shell
#S#
#S#    10 - error retrieving the status of the attached phone (or no phone connected)
#S#    11 - the phone is attached but without permissions to access via fastboot or adb
#S#    12 - the phone seems to be in EDL mode
#S#

# ---------------------------------------------------------------------
# The usage if used as standalone script is:
#
#H# Usage
#H#
#h#    boot_phone_from_twrp.sh [-h|help|-H] [serial=#sn|s=#sn] [wait=n] [password=password] [decrypt] [usb_reset|no_usb_reset] 
#h#                            [force|noforce] [reboot|noreboot] [checkonly|check] [reset_usb_only] [restart_bootloader] [status]
#h#                            [twrp|Android|android|recovery|bootloader|sideload|fastboot|safemode|twrp_image_file] 
#h#
#H# All parameter are optional;  without a parameter the script boots the phone from the TWRP image.
#H#
#H# Use the parameter "help" or "-H" to print the detailed usage help; use the parameter "-h" to print only the short usage help
#H#
#H# Use the parameter "restart_bootloader" to restart the bootloader before booting the phone from the TWRP image
#H# 
#H# Use the parameter "serial=#sn" to define the serialnumber of the phone to process. This parameter is only necessary if there
#H# are more then one phones connected via USB and the environment variable SERIAL_NUMBER is not set.
#H#
#H# The value for the parameter "wait" is the maximum number of seconds to wait after booting from the TWRP image until
#H# the adb deamon is ready to use. The default value is 10 seconds.
#H#
#H# Use the parameter "password=passwd" to define the password used for the data partition on the phone.
#H#
#H# Use the parameter "force" to reboot the phone from the TWRP image even if it's booted from a TWRP installed in 
#H# the boot or recovery partition.
#H#
#H# Use the parameter "noforce" to disable rebooting the phone from the TWRP image if it's booted from a TWRP installed in 
#H# the boot or recovery partition. This is the default setting.
#H#
#H# Use the parameter "reboot" to reboot the phone from the TWRP image even if it's already booted from an TWRP image.
#H#
#H# Use the parameter "noreboot" to disable rebooting the phone from the TWRP image if it's already booted from an TWRP image
#H# This is the default setting.
#H#
#H# Use the parameter "checkonly" or "check" to only retrieve the current boot mode of the phone; the script returns
#H# the current status via return code and writes no messages; see below for the list of defined return codes.
#H#
#H# Use the parameter "status" to only print the current boot mode of the phone; the script also returns
#H# the current status via return code; see below for the list of defined return codes.
#H#
#H# Use the parameter "decrypt" to only decrypt the data partition.
#H#
#H# Use the parameter "no_usb_reset" to disable the reset of the USB port; the default is to reset the USB port if necessary if the executable usbreset is 
#H# available via PATH
#H#
#H# Use the parameter "usb_reset" to force a reset of the USB port used for the phone if there is no access to the phone 
#H#   The reset of the USB port can only be done if executable "usbreset" is available via PATH variable
#H#
#H# Use the parameter "reset_usb_only" to only reset the USB port ussed for the phone
#H#
#H# The parameter "recovery", "bootloader", "sideload", and "fastboot" can be used to boot the phone in the specified mode.
#H# The parameter "Android" or "android" can be used to boot the phone into the Android OS installed on the phone.
#H# The parameter "safemode" can be used to boot the Android OS on the phone into the "safe mode". Note that this only works if the phone is 
#H# already booted into the Android OS.
#H#
#H# The parameter "twrp_image_file" can be used to define the TWRP image to be used (every parameter that is not in the list of known parameter above is
#H# treated as TWRP image file)
#H#
#H# Environment variables overwrite the values defined in the script; script parameter overwrite the values defined in environment variables.
#H#
#H#
#H# The order used by the script to select the TWRP image to use is as follows:
#H# 
#H# 1. If there is TRWP image in the parameter for the script, this TWRP image is used
#H# 
#H# 2. If there is a TWRP image defined in the variable TWRP_IMAGE, this TWRP image is used
#H# 
#H# 3. If the script can access the phone via adb; it tries to find the TWRP image necessary for the running OS
#H# 
#H# 4. If there is still no TWRP image to use found, the TWRP image defined in the variable DEFAULT_TWRP_IMAGE hardcoded in the script will be used
#H#    The TWPR image defined in the variable DEFAULT_TWRP_IMAGE is the TWRP image for the ASUS Zenfone 8 running the ASUS Android OS
#H#
#H#
#H# Returncodes:
#H#
#H#     0 - the phone was successfully booted from the TWRP image (or a known TWRP compatible image)
#H#
#H#     1 - the phone is already booted from the TWRP image (or known TWRP compatible image)
#H#     2 - the phone is booted from TWRP installed in the boot or recovery partition (or known TWRP compatible recvovery)
#H#     3 - the phone is booted into the Android OS
#H#     4 - the phone is booted into bootloader 
#H#     5 - the phone is booted into the fastbootd
#H#     6 - the phone is booted into the safe mode of the Android OS
#H#     7 - the phone is booted into the a non-TWRP recovery installed in the boot or recovery partition
#H#     8 - the phone is booted into sideload mode
#H#     9 - the phone is booted into a recovery without working adb shell
#H#
#H#
#H#   100 - invalid parameter found
#H#   101 - TWRP image not found
#H#   102 - booting the phone into the bootloader failed
#H#   103 - booting the phone into the TWRP failed
#H#   104 - Booting into safemode is only possible if the phone is booted into the Android OS
#H#   105 - Decyrptig the phone is only possible if the phone is booted from TWRP
#H#   108 - Booting the phone into the requested mode failed
#H#   109 - too many phones connected
#H#   110 - usage help printed and exited
#H#   111 - found no TWRP image for the running OS
#H#   112 - One or more errors in the prereq found
#H#   113 - Booting the phone into the safe mode requires root access to the phone
#H#   114 - no known boot method for the current status of the phone
#H#
#H#
#H#   252 - access to the phone failed 
#H#   253 - requirement check failed (e.g. one or more required executables not found, etc)
#H#   254 - unknown error
#H#    
#H#
#H# The phone to boot must be attached via USB.
#H# The phone can be either in fastboot mode, in normal mode with enabled adb access, in the boot loader, already booted from an installed TWRP or an TWRP image,
#H# or booted into another recovery like the LineageOS recovery with enabled adb access. 
#H# Phones in EDL mode are also detected; but the script can nothing do with a phone in EDL mode.
#H# 
#H#
#H# To change some of the values used by the script you can set environment variables before starting the script:
#H#
#H#   Set the environment variable TWRP_IMAGE to the name of the TWRP image file that should be used (the parameter of the script overwrites the variable)
#H#
#H#   Set the environment variable SERIAL_NUMBER to the serial number of the phone to patch if there is more then one phone connected via USB
#H#
#H#   Set the environment variable ADB_OPTIONS to the options to be used with the adb command
#H#   Set the environment variable FASTBOOT_OPTIONS to the options to be used with the fastboot command
#H#
#H#   Set the environment variable FASTBOOT_TIMEOUT to the maximum number of seconds to wait for a fastboot command to finish (default are 3 seconds)
#H#   Set the environment variable FASTBOOT_WAIT_TIME to the maximum number of seconds to wait after booting the phone from the bootloader (default are 60 seconds)
#H#   Set the environment variable ADB_BOOT_WAIT_TIME to the maximum number of seconds to wait after booting the phone until there is a working adb connection (default are 120 seconds)
#H#   Set the environment variable ADB_DAEMON_WAIT_TIME to the maximum number of seconds to wait for the restart of the adb daemon after booting into TWRP 
#H#   Set the environment variable DECRYPT_DATA_WAIT_TIME to the maximum number of seconds to wait after booting the phone until /data is decrypted (default are 150 seconds)
#H#   Set the environment variable ADB_SERVICE_WAIT_TIME to the maximum number of seconds to wait for the Android service "package" got ready after booting into the Android OS (default are 30 seconds)
#H# 
#H#   Set the environment variable ADB to the adb executable that should be used; default: search adb in the PATH
#H#   Set the environment variable FASTBOOT to the fastboot executable that should be used; default: search fastboot in the PATH
#H#   Set the environment variable TIMEOUT to the timeout executable that should be used; default: search timeout in the PATH
#H#   Set the environment variable USBRESET to the usbreset executable that should be used if the parameter usb_reset is used; default: search timeout in the PATH
#H#
#H#   Set the environment variable CHECK_ONLY to 0 (= ${__TRUE}) to only check the status of the phone
#H#   Set the environment variable PRINT_STATUS and also the variable CHECK_ONLY to 0 = ${__TRUE} to only print the status of the phone
#H#   Set the environment variable RESET_THE_USB_PORT to 0 = ${__TRUE} to force a reset of the USB port used by the phone if the access is not working
#H#
#H#   Set the environment variable USER_PASSWORD to the password used for the data partition
#H#     (see here: https://twrp.me/faq/openrecoveryscript.html for the format of the password)
#H#

#
# History
#   05.11.2022 v1.0.0.0 /bs  #VERSION
#     inital release
#
#   01.12.2022 v2.0.0.0 /bs  #VERSION
#     script rewritten using functions
#     added the parameter --serial=#sn
#
#   07.12.2022 v2.1.0.0 /bs #VERSION
#     added a check for the Android OS safe mode
#     missing shift command in the code to process the parameter for the serial number -- fixed
#
#   17.12.2022 v2.2.0.0 /bs #VERSION
#     added support for the LineageOS recovery 
#     use the command timeout for "su -" commands on the phone
#
#   01.01.2023 v2.3.0.0 /bs #VERSION
#     added support for a parameter for the TWRP image file to use for the function "boot_phone_from_the_TWRP_image"
#     added support for the parameter "force" to the function "reboot_phone"
#     added support for the phone mode "sideload"
#     function "reboot_phone" rewritten from sratch
#     the script now first checks for phones connected via adb and then for phones connected via fastboot
#     the check for safe mode now also works without root access
#     the script now ends with return code 110 instead of 10 if executed with the parameter "-h"
#     the script now also prints the current boot slot if executed with the parameter "status"
#
#   04.01.2023 v2.3.1.0 /bs #VERSION
#     the function reboot_phone now uses fastboot to check if the boot into the bootloader was successfull 
#     function reboot_phone: replaced "adb wait-for..." commands with other commands ; these "adb wait-for.." commands are not reliable
#     added the returncode "9 - the phone is booted into a recovery without working adb shell" to the function to check the phone status
#
#   08.01.2023 v2.3.1.1 /bs #VERSION
#     the script now also supports the parameter with leading "--"
#
#   14.01.2023 v2.3.1.2 /bs #VERSION
#     increased the timeout to wait for booting into the TWRP image from 60 to 120 seconds
#     increased the timeout to wait for the adb to be ready after booting into TWRP from 10 to 30 seconds
#
#   16.01.2023 v2.3.2.0 /bs #VERSION
#     added a parameter for the time to wait for booting the phone to the function reboot_phone
#
#   18.01.2023 v2.3.2.1 /bs #VERSION
#     fixed a minor issue in the messages written by the function wait_for_the_adb_daemon
#
#   20.01.2023 v2.3.2.2 /bs #VERSION
#     the script ignored the values of the envionment variables ADB_OPTIONS and FASTBOOT_OPTIONS (these variables were deleted in the function set_serial_number ) -- fixed
#
#   28.01.2023 v2.3.2.3 /bs #VERSION
#     the code to process the parameter s=# was wrong -- fixed
#
#   23.04.2023 v2.4.0.0 /bs #VERSION
#     added the function decrypt_data to decrypt an encrypted data partition
#     added the parameter password=passwd
#     added the support for the global variable USER_PASSWORD
#     added the parameter Android, android, recovery, bootloader, sideload, fastboot, and safemode
#     added the function copy_file_on_the_phone
#     added the function download_file_from_the_phone
#     added the function upload_file_to_the_phone
#
#   01.05.2023 v2.5.0.0 /bs #VERSION
#     the function reboot_phone did not work if called without a parameter for the boot target -- fixed
#     the function decrypt_data now uses the Android command "input" to "decrypt" the data parition if booted into the Android OS
#     added the function wipe_cache
#     added the function wipe_dalvik
#     added the function umount_data
#     added the function format_data
#     added the function wipe_data
#     added the function format_metadata
#     added the function kill_adb_daemon
#
#   10.05.2023 v2.5.1.0 /bs #VERSION
#     fixed syntax errors in the function wait_until_data_is_mounted
#     the function for booting the phone now returns an error if decrypting the /data partition failed
#     the function for booting the phone now returns an error if decrypting the /data partition failed
#
#   02.07.2023 v2.5.2.0 /bs #VERSION
#     the variable DEFAULT_PASSWORD can be used to define the default password for file encyrption in Android
#     the function decrypt_data now uses the default password decrypting files if no user password was set
#
#   22.11.2023 v2.5.3.0 /bs #VERSION
#     the default password for decyrpting the /datas partition was never used due to a wrong if clause in the function decrypt_data -- fixed
#
#   27.12.2023 v2.5.3.1 /bs #VERSION
#     egrep replaced with "grep -E"
#
#   27.04.2024 v2.5.3.2 /bs #VERSION
#     increase the timeout for waiting for decryption in the function decrypt_data from 15 to 150 seconds
#
#   28.04.2024 v2.5.3.3 /bs #VERSION
#      the function wait_until_data_is_mounted always returned ${__TRUE} because of a typo -- fixed
# 
#   29.04.2024 v2.5.4.0 /bs #VERSION
#      the parameter for the TWRP image file did not work if the environment variable TWRP_IMAGE was already set before starting the script -- fixed
#      improved the message about the source for the TWRP image used
# 
#   30.04.2024 v2.6.0.0 /bs #VERSION
#      the script does not try to decrypt a not initialized /data partition anymore
#      added the function get_twrp_image_for_the_installed_OS and the global variables TEMP_TWRP_IMAGE_TO_USE and CURRENT_INSTALLED_ROM
#      added the function online_adb_connection
#      added more comments with details for the usage of this file
#      added the alias check for the parameter checkonly
#      the function format_data did not work as expected due to a invalid twrp command used - fixed
#
#   03.05.2024 v2.6.1.0 /bs #VERSION
#      the script does not check the phone status when starting anymore if the variable CHECK_THE_PHONE_STATUS is set to ${__FALSE}
#      (the variable CHECK_THE_PHONE_STATUS is used prepare_phone.include)
#      added the function restart_adb_daemon      
#      the functions start_adb_daemon and restart_adb_daemon now support the parameter "root" to start/restart the daemon via sudo
#      changed the grep command to check if the adb daemon is running in all functions to  ' grep " adb " '
#
#   05.05.2024 v2.6.2.0 /bs #VERSION
#      added support for /e/
#      the function reboot_phone ended with a syntax error for unknown phone states -- fixed
#
#   05.05.2024 v2.6.3.0 /bs #VERSION
#      the function get_twrp_image_for_the_installed_OS now uses the definitions from the variable TWRP_IMAGES_FOR_THE_RUNNING_OS
#
#   07.05.2024 v2.6.4.0 /bs #VERSION
#      added the functions select_twrp_image_for_install_image, check_android_boot_image, LogInfo, and LogWarning
#      added the funcdtion convert_phone_status_into_status_string
#
#   08.05.2024 v2.7.0.0 /bs #VERSION
#      added the global variables ROM_NAME, PROP_RO_BUILD_DESCRIPTION, PROP_RO_PRODUCT_BUILD_VERSION_RELEASE
#      retrieve_phone_status re-written, PHONE_STATUS=7 is now for a phone booted into the non-TWRP recovery on the phone 
#        the global variable ROM_NAME contains the name of the running OS on the phone
#
#   15.05.2024 v2.8.0.0 /bs #VERSION
#      added code to check for phones in EDL mode
#      added the PHONE_STATUS 12 for phones that seems to be in EDL mode
#
#   22.05.2024 v3.0.0.0 /bs #VERSION
#      added code to retrieve the USB port used for the phone
#      added the parameter usb_reset to force a reset of the USB Device if access to the phone is not working
#      added the functions reset_the_usb_port_for_the_phone and reset_the_usb_port_for_the_phone_if_necessary
#      added the global variables USBRESET, RESET_THE_USB_PORT, PHONE_USB_IDENTIFIER, and PHONE_USB_DEVICE
#      renamed the variable CHECKONLY to CHECK_ONLY
#      PRINT_STATUS is now a global variable that can be set before starting the script
#      LogInfo was wrong implemented -- fixed
#      fixed some errors in the function to detect the phone
#      added more debug messages -- set the variable VERBOSE to any value before calling the script to print debug messages
#      the script prints now no message anymore if the parameter "check" is used 
#      added the environment variable EXECUTE_BOOT_PHONE_FROM_TWRP_INIT
#      the script now boots the TWRP image that is necessary for the running OS if the access via adb is working and the running OS is known by the script
#      the script now reset the usb port while waiting for an adb connection if necessary and the parameter "reset_usb" is used
#      there was a typo so that the script did not detect that the phone was already booted from the recovery -- fixed
#      fixed various other minor errors
#      function wait_for_phone_with_a_working_adb_connection rewritten from sratch
#      added the function wait_until_an_android_service_is_ready
#      the script now also detects the ASUS Android Beta versions
#
#   25.05.2024 v3.0.1.0 /bs #VERSION
#      added support for /e/ 2.0
#      removed the use of the not defined function LogErrorMsg
#      added the environment variable ADB_PORT for the port used by the running adb daemon
#      the function restart_adb_daemon now restarts the adb daemon via systemd if it was started using systemd
#
#   26.06.2024 v3.0.2.0 /bs #VERSION
#      added the global variable INACTIVE_SLOT
#      the function get_twrp_image_for_the_installed_OS now also works if the phone is boot into TWRP or a recovery with enable adb access
#
#   03.07.2024 v3.0.3.0 /bs #VERSION
#      added the global variables PROP_RO_MODVERSION, OS_BUILD_TYPE, OS_PATCH_LEVEL, PROP_RO_SECURE, and PROP_RO_DEBUGGABLE, 
#
#   21.07.2024 v3.1.0.0 /bs #VERSION
#      the code to select the TWRP image to be used for a running OS was buggy again --fixed
#
#   22.07.2024 v3.1.1.0 /bs #VERSION
#      the function get_twrp_image_for_the_installed_OS now sets the global variable TEMP_TWRP_IMAGE_TO_USE to an empty string
#        if no twrp image for the running OS was found and the global variable TWRP_IMAGE is already set
#
#   03.08.2024 v3.1.2.0 /bs #VERSION
#      added an additional check to handle the automatic restart of the adbd in TWRP (this check was already there in old version but seems to get lost in the last versions)
#
#   06.09.2024 v3.1.3.0 /bs #VERSION
#      some recoveries return "fastboot" instead of "fastbootd" when in fastboot mode ; the script now detects this
#
#   10.09.2024 v3.1.4.0 /bs #VERSION
#      change from 06.09.2024 reverted
#
#   11.09.2024 v3.1.5.0 /bs #VERSION
#      the script now sets the global variable ORANGE_FOX_SYSTEM_RELEASE if the phone is booted from the OrangeFox recovery (the status of the phone is still 7 in that case)
#        if executed with the parameter status the phone also prints a message about the used recovery
#      the script now sets the global variable TWRP_COMPATIBLE to 0 if a TWRP compatible recovery was detected
#
#   13.09.2024 v3.1.6.0 /bs #VERSION
#      selecting the correct TWRP image for the OS running on the phone did not work if there where "*" in the definitions for the TWRP images -- fixed
#
#   22.11.2024 v3.2.0.0 /bs #VERSION
#      enhanced the support for the OrangeFox recovery
#
#   22.12.2024 v3.2.1.0 /bs #VERSION
#      added support for /e/ 2.6.3-t
#      the script now also prints the TWRP image that should be used for the running OS
#
#   25.02.2025 v3.2.2.0 /bs #VERSION
#      added support for /e/ 2.7-t
#      added support for LineageOS 22.x
#
#   26.02.2025 v3.2.3.0 /bs #VERSION
#      the function format_data now checks the output of the command "twrp format" for error messages starting with "E:" and returns an error if there is an error message
#
#   01.03.2025 v3.2.3.0 /bs #VERSION
#      added support for /e/ 2.8-t
#
#   12.03.2025 v3.2.4.0 /bs #VERSION
#      added support for /e/ 2.9-t
#
#   22.03.2025 v3.2.5.0 /bs #VERSION
#      added support for self compiled LineageOS 22.x images
#
#   19.04.2025 v3.2.6.0 /bs #VERSION
#      added support for the official build for /e/ 2.9-t
#
#   06.06.2025 v3.2.7.0 /bs #VERSION
#      added support for the official build for /e/ 3.0-t
#
#   13.07.2025 v3.2.8.0 /bs #VERSION
#      added support for the official build for /e/ 3.0.1-t and /e/ 3.0.4-t
#
#   23.07.2025 v3.2.9.0 /bs #VERSION
#      added the parameter "restart_bootloader"
#      added the variable RESTART_BOOT_LOADER
#      added support for the official build for /e/ 3.0.4-a15 (= Android 15)
#      added support for LineageOS 22.2 (= Android 15)
#
#   01.08.2025 v3.2.9.1 /bs #VERSION
#      the check value for ro.build.description for /e/ based on Android 15 now uses a better regex
#      added support for self-compiled LineageOS 22.2 images (lineage-22*UNOFFICIAL*)
#
#   03.08.2025 v3.2.9.2 /bs #VERSION
#      added support for DrDroid 11.7
#
#   04.08.2025 v3.2.9.3 /bs #VERSION
#      added support for EvolutionX 10.7 (= Android 15)
#
#   05.08.2025 v3.2.9.4 /bs #VERSION
#      added support for EvolutionX 10.7 without GMS
#
#   08.08.2025 v3.2.9.5 /bs #VERSION
#      the function wait_for_the_adb_daemon now checks for the property "sys.usb.config" ( the property "sys.usb.state" seems not to exist in all CustomROMs)
#
#   21.08.2025 v3.2.9.6 /bs #VERSION
#      the check value for /e/ 3.0.1-t is now more relaxed
#
# Author
#   Bernd.Schemmer (at) gmx.de
#   Homepage: http://bnsmb.de
#
#
# Prerequisites
#   a computer running Linux with working adb and fastboot binaries available via PATH variable
#   for resetting the USB port an executable called usbreset must be available via PATH variable
#      (see https://askubuntu.com/questions/645/how-do-you-reset-a-usb-device-from-the-command-line for the source code for a usbreset binary)
#   a phone with unlocked boot loader
#   a working TWRP recovery image 
#
# Test Environment  
#
#   Tested on an ASUS Zenfone 8 and with
#     - TWRP 3.7.0.12
#     - TWRP 3.6.1.12
#     - TWRP 3.7.0.12-0
#     - TWRP 3.7.0.12-1
#     - OrangeFox (orangefox.system.release=14)
#     - OrangeFox R11.3
#
#  Tested with these ROMS for the ASUS Zenfone 8:
#
#    ROM                    Version
#    --------------------------------------------------------
#    ASUS Android           12, 13 
#    OmniROM                12, 13, 14, 15, 16 (the OmniROM version is also the Android version)
#    /e/                    1.21, 2.0-t, 2.4.1-t, 2.5-t, 2.6.3-t, 2.7-t, 2.8-t, 2.9-t, 3.0-t (2.x and 3.0-t = Android 13)
#    /e/                    3.0.4-a15  (= Android 15)
#    StatixXOS              7,x (Android 14)
#    LineageOS              20 (Android 13), 21 (Android 14), 22 (Android 15)
#    LMODroid               4.2 (Android 13)
#    EvolutionX             15.0 (Android 15)
#    crDroid                11.7 (Android 15)
#
#
# Details
#
#   see source code
#
# Trouble Shooting
#
#   - If the adb connection dies and there are error messages like this
#
#       adb: insufficient permissions for device
#
#     restart the adb server using
#
#       adb kill-server
#
#     if that does not work disconnect and reconnect the USB cable
#

# Script return code
#
# BOOT_PHONE_FROM_TWRP_RC=254

# define constants if not already defined
#
[ "${__TRUE}"x = ""x ]  &&  __TRUE=0
[ "${__FALSE}"x = ""x ] && __FALSE=1

# check if the script was called as standalone script
#
if [[ $0 == *boot_phone_from_twrp.sh* ]] ; then
#
# the script is running as standalone script
#
  RUNNING_AS_STANDALONE_SCRIPT=${__TRUE}

# read the script version from the comments in this file
#
  SCRIPT_VERSION="$( grep "^#" $0 | grep "#VERSION" | grep "v[0-9]" | tail -1 | awk '{ print $3}' )"

  SCRIPT_NAME="${0##*/}"

else  
#
# the script is used as include file
#
  RUNNING_AS_STANDALONE_SCRIPT=${__FALSE}
fi

# ---------------------------------------------------------------------
# init some global variables
#

# default password used for the file encrytion in Android
#
DEFAULT_PASSWORD="${DEFAULT_PASSWORD:=default_password}"

# default TWRP image to use
#
DEFAULT_TWRP_IMAGE="/data/backup/ASUS_ZENFONE8/twrp/current_twrp.img"

# default timeout for fastboot commadns
#
DEFAULT_FASTBOOT_TIMEOUT=3

# default max number of seconds to wait until the adb daemon gets ready
#
DEFAULT_ADB_DAEMON_WAIT_TIME=60

# default max number of seconds to wait after booting into the bootloader
#
DEFAULT_FASTBOOT_WAIT_TIME=60

# default max number of seconds to wait after booting into the TWRP imaage
#
DEFAULT_ADB_BOOT_WAIT_TIME=120

# default max number of seconds to wait until decrypting the /data partition is done
#
DEFAULT_DECRYPT_DATA_WAIT_TIME=150

# default max number of seconds to wait until the Android service "package" should be ready after a reboot
#
DEFAULT_ADB_SERVICE_WAIT_TIME=30

# reboot into the TWRP image even if already booted from an TWRP installed on the phone; default for the parameter force/noforce
#
FORCE_BOOT_INTO_TWRP_IMAGE=${FORCE_BOOT_INTO_TWRP_IMAGE:=${__FALSE}}

# reboot into the TWRP image even if already booted from an TWRP image; default for the parameter reboot/noreboot
#
FORCE_REBOOT_INTO_TWRP_IMAGE=${FORCE_REBOOT_INTO_TWRP_IMAGE:=${__FALSE}}

# reboot the bootloader before booting from the TWRP image
#
RESTART_BOOT_LOADER=${__FALSE}

# only check the current status of the phone if set to ${__TRUE} (parameter checkonly or check)
#
CHECK_ONLY=${CHECK_ONLY:=${__FALSE}}

# only check and print the current status of the phone if set to ${__TRUE} (parameter status)
#
PRINT_STATUS=${PRINT_STATUS:=${__FALSE}}

# only reset the USB port
#
ONLY_RESET_THE_USB_PORT=${__FALSE}


# general options for the adb command; -d : only use devices connected via USB
#
ADB_OPTIONS="${ADB_OPTIONS:=-d}"

# general options for the fastboot command
#
FASTBOOT_OPTIONS="${FASTBOOT_OPTIONS:=}"

# default port used by the adb
#
DEFAULT_ADB_PORT="5037"

# executables used
#
ADB="${ADB:=$( which adb )}"
FASTBOOT="${FASTBOOT:=$( which fastboot )}"
TIMEOUT="${TIMEOUT:=$( which timeout )}"
USBRESET="${USBRESET:=$( which usbreset )}"

#
# use "grep -E" instead of "egrep" if supported (this is OS independent)
#
if [ "${EGREP}"x = ""x ] ; then
  echo test | grep -E test 2>/dev/null >/dev/null && EGREP="grep -E " || EGREP="egrep"
fi


# default max number of seconds to wait after booting into the bootloader
#
FASTBOOT_WAIT_TIME="${FASTBOOT_WAIT_TIME:=${DEFAULT_FASTBOOT_WAIT_TIME}}"

# default max number of seconds to wait after booting into the TWRP imaage
#
ADB_BOOT_WAIT_TIME="${ADB_BOOT_WAIT_TIME:=${DEFAULT_ADB_BOOT_WAIT_TIME}}"

# default max number of seconds to wait until the adb daemon gets ready
#
ADB_DAEMON_WAIT_TIME="${ADB_DAEMON_WAIT_TIME:=${DEFAULT_ADB_DAEMON_WAIT_TIME}}"

# default max number of seconds to wait until decrypting the /data partition is done
#
DECRYPT_DATA_WAIT_TIME="${DECRYPT_DATA_WAIT_TIME:=${DEFAULT_DECRYPT_DATA_WAIT_TIME}}"

# timeout for fastboot check command
#
FASTBOOT_TIMEOUT="${FASTBOOT_TIMEOUT:=${DEFAULT_FASTBOOT_TIMEOUT}}"

# timeout until the Android service "package" should be ready after a reboot
#
ADB_SERVICE_WAIT_TIME="${ADB_SERVICE_WAIT_TIME:=${DEFAULT_ADB_SERVICE_WAIT_TIME}}"



# only decrypt the data partition if this variable is true
#
DECRYPT_ONLY=${__FALSE}

# reset the USB port if there is no working connection to the phone while to retrieve the status of the phone
#
if [ "${USBRESET}"x  != ""x ] ; then
  RESET_THE_USB_PORT=${RESET_THE_USB_PORT:=${__TRUE}}
else
  RESET_THE_USB_PORT=${RESET_THE_USB_PORT:=${__FALSE}}
fi

# identifier of the phone is the output of the command lsusb
#
PHONE_USB_IDENTIFIER=""

# this variable is true if there is a TWRP image defined in the environment or in the parameter for the script
#
NO_TWRP_IMAGE_AUTO_SELECT=${__FALSE}

# list of global variables
#
GLOBAL_VARS="
SUDO_PREFIX
CUR_USER
FORCE_BOOT_INTO_TWRP_IMAGE 
FORCE_REBOOT_INTO_TWRP_IMAGE
TWRP_IMAGE
SERIAL_NUMBER
ADB_DAEMON_WAIT_TIME
FASTBOOT_WAIT_TIME
ADB_BOOT_WAIT_TIME
DECRYPT_DATA_WAIT_TIME
FASTBOOT_OPTIONS
ADB_OPTIONS
ADB
FASTBOOT
TIMEOUT
CHECK_ONLY
PRINT_STATUS
PHONE_USB_IDENTIFIER
RESET_THE_USB_PORT
USER_PASSWORD
TEMP_TWRP_IMAGE_TO_USE
CURRENT_INSTALLED_ROM 
CURRENT_INSTALLED_ROM_VERSION
PHONE_STATUS
PHONE_STATUS_OUTPUT
PROP_RO_TWRP_BOOT
PROP_RO_BOOTMODE
PROP_RO_BUILD_DESCRIPTION
PROP_RO_PRODUCT_BUILD_VERSION_RELEASE
BOOT_SLOT
INACTIVE_SLOT
RUNNING_IN_AN_ADB_SESSIION
ROM_NAME
PHONE_IN_EDL_MODE
PHONE_USB_DEVICE
PHONE_BOOT_ERROR
USER_PASSWORD
OS_BUILD_TYPE
OS_PATCH_LEVEL
PROP_RO_SECURE
PROP_RO_DEBUGGABLE
PROP_RO_MODVERSION
ORANGE_FOX_SYSTEM_RELEASE
TWRP_COMPATIBLE
"

# ------------------
# TWRP images for specific ROM image files
# 
# each line must contain these fields (the field separator is a colon ":"; lines starting with a hash "#" are ignored) :
#
# regex for the image file : TWRP image to use : Name of the ROM : description
#
# The fields for the name of the ROM and the description are optional
#
# The regex can only contain the joker characters "?" and "*"
# 

if [ "${TWRP_IMAGES_FOR_IMAGE_FILES}"x = ""x ] ; then
  TWRP_IMAGES_FOR_IMAGE_FILES="
#
UL-ASUS* :  ${DEFAULT_TWRP_IMAGE} :  ASUS Android 
#
LMODroid* : /data/backup/ASUS_ZENFONE8/LMODroid/twrp_LMODroid-4.2-20240429-RELEASE-sake.img : LMODroid :
#
e-2.8-UNOFFICIAL* : /data/backup/ASUS_ZENFONE8/e_local/twr_e-2.8-current.img : /e/ 2.8 unofficial
e-2.9-UNOFFICIAL* : /data/backup/ASUS_ZENFONE8/e_local/twrp_e-2.9-current.img : /e/ 2.9 unofficial
#
e-1.21*      : /data/backup/ASUS_ZENFONE8/e/e-1.21t/twrp_recovery-e-1.21-t-20240325389105-dev-sake.img : /e/ 1.21
e-2.0*       : /data/backup/ASUS_ZENFONE8/e/e-2.0t/twrp_recovery-e-2.0-t-20240514401453-dev-sake.img : /e/ 2.0
e-2.5*       : /data/backup/ASUS_ZENFONE8/e/e-2.5/twrp-e-2.5-t-20241108446630-community-sake.img : /e/ 2.5
e-2.6*       : /data/backup/ASUS_ZENFONE8/e/e-2.6.3/twrp-e-2.6.3-t-20241217455572-community-sake.img : /e/ 2.6
e-2.7*       : /data/backup/ASUS_ZENFONE8/e/e-2.7/twrp-e-2.7-t-20250112460975-community-sake.img : /e/ 2.7
e-2.8*       : /data/backup/ASUS_ZENFONE8/e/e-2.8/twrp-e-2.8-t-20250219470166-community-sake.img : /e/ 2.8
e-2.9*       : /data/backup/ASUS_ZENFONE8/e/e-2.9/twrp-e-2.9-t-20250322478412-community-sake.img : /e/ 2.9
#
e-3.0.1*     : /data/backup/ASUS_ZENFONE8/e/e-3.0.1/twrp-e-3.0.1-t-20250607498934-community-sake.img : /e/ 3.0.1
#
e-3.0.4-a15* : /data/backup/ASUS_ZENFONE8/e/e-3.0.4-a15/orangefox_e-3.0.4-a15-20250712508365-community-sake.img :  /e/ 3.0.4-a15
#
e-3.0.4*     : /data/backup/ASUS_ZENFONE8/e/e-3.0.4/twrp_e-3.0.4-t-20250710507809-community-sake.img : /e/ 3.0.4
#
e-3.0*       : /data/backup/ASUS_ZENFONE8/e/e-3.0/twrp-e-3.0-t-20250529496537-community-sake.img : /e/ 3.0
#
#
lineage-20.0-20240716-nightly-sake-signed.zip : /data/backup/ASUS_ZENFONE8/Lineage-20/2024-07-16/twrp_lineage-20.0-20240716-nightly-sake-signed.img : LineageOS 20.0
lineage-20* : /data/backup/ASUS_ZENFONE8/Lineage-20/twrp_lineage-20.0-20240528-nightly-sake-signed.img : LineageOS 20.x
lineage-21* : /data/backup/ASUS_ZENFONE8/Lineage-21/twrp_3.7.0_12-1-I006D_for_lineageOS21-20240220-sake.img : LineageOS 21.x
#
lineage-22.2-2025*-UNOFFICIAL-sake.zio : /data/backup/ASUS_ZENFONE8/Lineage-22-original-local/orangefox_lineage-22.2-20250801-UNOFFICIAL-sake.img : LineagaeOS 22.2 self compiled
lineage-22* : /data/backup/ASUS_ZENFONE8/Lineage-22-original/2025-07-15/orangefox_lineage-22.2-20250715-nightly-sake-signed.img : LineageOS 22.x
#
sake-* : /data/backup/ASUS_ZENFONE8/Lineage-21/twrp_3.7.0_12-1-I006D_for_lineageOS21-20240220-sake.img : LineageOS 21.x
#
statix_sake-20240106-14-v7.1-UPSIDEDOWNCAKE.zip : /data/backup/ASUS_ZENFONE8/Statix/20240106/twrp_statix_sake-20240106-14-v7.1-UPSIDEDOWNCAKE.img : StatixOS
statix_sake-20231224-14-v7.1-UPSIDEDOWNCAKE.zip : /data/backup/ASUS_ZENFONE8/Statix/20231229/twrp_statix_sake-20231224-14-v7.1-UPSIDEDOWNCAKE.img : StatixOS
statix_sake-20240712-14-v7.10-UNOFFICIAL.zip : /data/backup/ASUS_ZENFONE8/Statix/20240712/twrp_statix_sake-20240712-14-v7.10-UNOFFICIAL.zip : StatiXOS
#
omni* : ${DEFAULT_TWRP_IMAGE} : OmniROM
#
crDroidAndroid-15.0-2025*-sake-v11.7*.zip : /data/backup/ASUS_ZENFONE8/crdroid/orangefox_crDroidAndroid-15.0-20250803-sake-v11.7.img : crDroid 11.7
#
EvolutionX-15.0-*-sake-10.7-*Unofficial*.zip : /data/backup/ASUS_ZENFONE8/evolutionX/orangefox_EvolutionX-15.0-20250804-sake-10.7-Unofficial.img : EvolutionX 15.0
"
fi

# ------------------
# TWRP images for specific ROMs currently running on the phone
#
# each line must contain these fields (the field separator is a colon ":"; lines starting with a hash "#" are ignored) :
#
# property : value : TWRP image to use : Name of the ROM : description
#
# Use "*" for the field "value" if the property must be defined but the value is meaningless
#
# The fields for the name of the ROM and the description are optional
#
#
if [ "${TWRP_IMAGES_FOR_THE_RUNNING_OS}"x = ""x ] ; then
  TWRP_IMAGES_FOR_THE_RUNNING_OS="
#
vendor.asus.build.ext.version : * : ${DEFAULT_TWRP_IMAGE} :  ASUS Android
#
#
ro.lineage.build.version : 20.0 : /data/backup/ASUS_ZENFONE8/Lineage-20/2024-07-16/twrp_lineage-20.0-20240716-nightly-sake-signed.img : LineageOS 
ro.lineage.build.version : 20* : /data/backup/ASUS_ZENFONE8/Lineage-20/twrp_lineage-20.0-20240528-nightly-sake-signed.img : LineageOS 
ro.lineage.build.version : 21* : /data/backup/ASUS_ZENFONE8/Lineage-21/twrp_3.7.0_12-1-I006D_for_lineageOS21-20240220-sake.img : LineageOS 

ro.lineage.version : 22.2-2025*-UNOFFICIAL-sake : /data/backup/ASUS_ZENFONE8/Lineage-22-original-local/orangefox_lineage-22.2-20250801-UNOFFICIAL-sake.img : LineagaeOS 22.2 self compiled
ro.lineage.version : 22.*-UNOFFICIAL-sake : /data/backup/ASUS_ZENFONE8/Lineage-22-local/twrp_lineage-22.2-20250408-UNOFFICIAL-sake.img : LineageOS 22.2 (local)

ro.lineage.build.version : 22.2 : /data/backup/ASUS_ZENFONE8/Lineage-22-original/2025-07-15/orangefox_lineage-22.2-20250715-nightly-sake-signed.img  : LineageOS 22.x
#
ro.statix.version : v7.1-*-20240106 : /data/backup/ASUS_ZENFONE8/Statix/20240106/twrp_statix_sake-20240106-14-v7.1-UPSIDEDOWNCAKE.img : StatixOS 
ro.statix.version : v7.10-*-20240712 : /data/backup/ASUS_ZENFONE8/Statix/20240712/twrp_statix_sake-20240712-14-v7.10-UNOFFICIAL.zip : StatixOS
ro.statix.version : * : /data/backup/ASUS_ZENFONE8/Statix/20240712/twrp_statix_sake-20240712-14-v7.10-UNOFFICIAL.zip : StatixOS
#
ro.lmodroid.build_name : LMODroid-4.2-20240429-RELEASE-sake : /data/backup/ASUS_ZENFONE8/LMODroid/twrp_LMODroid-4.2-20240429-RELEASE-sake.img : LMODroid
ro.omni.version : * : ${DEFAULT_TWRP_IMAGE} : OmniROM
#
ro.modversion : 2.8-t-202503*-UNOFFICIAL-sake : /data/backup/ASUS_ZENFONE8/e_local/twrp_e-2.8-current.img : /e/ 2.8 unofficial
ro.modversion : 2.9-t-202503*-UNOFFICIAL-sake : /data/backup/ASUS_ZENFONE8/e_local/twrp_e-2.9-current.img : /e/ 2.9 unofficial
#
ro.build.description : e_sake-user 13 TQ3A.230901.001 eng.root.20240325.220445* : /data/backup/ASUS_ZENFONE8/e/e-1.21t/twrp_recovery-e-1.21-t-20240325389105-dev-sake.img : /e/ 1.21
ro.build.description : e_sake-user 13 TQ3A.230901.001 eng.root.20240514.193325* : /data/backup/ASUS_ZENFONE8/e/e-2.0t/twrp_recovery-e-2.0-t-20240514401453-dev-sake.img : /e/ 2.0
ro.build.description : e_sake-user 13 TQ3A.230901.001 eng.root.20241108.113816 release-keys : /data/backup/ASUS_ZENFONE8/e/e-2.5/twrp-e-2.5-t-20241108446630-community-sake.img : /e/ 2.5
ro.build.description : e_sake-user 13 TQ3A.230901.001 eng.root.20241217.174531 release-keys : /data/backup/ASUS_ZENFONE8/e/e-2.6.3/twrp-e-2.6.3-t-20241217455572-community-sake.img : /e/ 2.6
ro.build.description : e_sake-user 13 TQ3A.230901.001 eng.root.20250112.044158 release-keys : /data/backup/ASUS_ZENFONE8/e/e-2.7/twrp-e-2.7-t-20250112460975-community-sake.img : /e/ 2.7
ro.build.description : e_sake-user 13 TQ3A.230901.001 eng.root.20250219.225052 release-keys : /data/backup/ASUS_ZENFONE8/e/e-2.8/twrp-e-2.8-t-20250219470166-community-sake.img : /e/ 2.8
ro.build.description : e_sake-user 13 TQ3A.230901.001 eng.root.20250322.023704 release-keys : /data/backup/ASUS_ZENFONE8/e/e-2.9/twrp-e-2.9-t-20250322478412-community-sake.img : /e/ 2.9
ro.build.description : e_sake-user 13 TQ3A.230901.001 eng.root.202506* release-keys : /data/backup/ASUS_ZENFONE8/e/e-3.0.1/twrp-e-3.0.1-t-20250607498934-community-sake.img : /e/ 3.0.1
ro.build.description : e_sake-user 13 TQ3A.230901.001 eng.root.20250710* release-keys : /data/backup/ASUS_ZENFONE8/e/e-3.0.4/twrp-e-3.0.4-t-20250710507809-community-sake.img : /e/ 3.0.4
ro.build.description : e_sake-user 13 TQ3A.230901.001 eng.root.20250529* release-keys : /data/backup/ASUS_ZENFONE8/e/e-3.0/twrp-e-3.0-t-20250529496537-community-sake.img : /e/ 3.0
ro.build.description : e_sake-user 15 BP1A.250505.005 eng.* : /data/backup/ASUS_ZENFONE8/e/e-3.0.4-a15/orangefox_e-3.0.4-a15-20250712508365-community-sake.img :  /e/ 3.0.4-a15
#
ro.crdroid.build.version : 11.7  : /data/backup/ASUS_ZENFONE8/crdroid/orangefox_crDroidAndroid-15.0-20250803-sake-v11.7.img : crDroid 11.7
#
ro.evolution.build.version : EvolutionX-15.0-*-sake-10.7-*Unofficial : /data/backup/ASUS_ZENFONE8/evolutionX/orangefox_EvolutionX-15.0-20250804-sake-10.7-Unofficial.img : EvolutionX 15.0
#
"
fi



# ---------------------------------------------------------------------
# functions that are only defined if not already defined
#

# ----------------------------------------------------------------------
# LogMsg
#
# function: write a message to STDOUT
#
# usage: LogMsg [message]
#
# The function prints nothing if only a status check is requested
#
typeset -f LogMsg >/dev/null || function LogMsg {

# dummy -- a leading "-" is used in my other LogMsg functions for special purposes
#
  [ "$1"x = "-"x ] && shift

  if [ ${CHECK_ONLY} != ${__TRUE} -o ${PRINT_STATUS} = ${__TRUE} ] ;then
    echo "$*"
  fi
}

# ----------------------------------------------------------------------
# LogError
#
# function: write a message prefixed with "ERROR:" to STDERR
#
# usage: LogError [message]
#
typeset -f LogError >/dev/null || function LogError {
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
typeset -f LogWarning >/dev/null || function LogWarning {
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
typeset -f LogInfo >/dev/null || function LogInfo {
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
# isNumber
#
# function: check if a value is an integer
#
# usage: isNumber testValue
#
# returns: ${__TRUE} - testValue is a number else not
#
typeset -f isNumber >/dev/null || function isNumber {
  typeset THISRC=${__FALSE}

  [[ $1 == +([0-9]) ]] && THISRC=${__TRUE} || THISRC=${__FALSE}

  return ${THISRC}
}


# ----------------------------------------------------------------------
# wait_some_seconds
#
# function: wait n seconds
#
# usage: wait_some_seconds [number_of_seconds]
#
# returns: ${__TRUE}  - waited n seconds
#          ${__FALSE} - no parameter found, to many parameter found,
#                       or the parameter is not a number
#
typeset -f wait_some_seconds >/dev/null || function wait_some_seconds {
  typeset THISRC=${__FALSE}

  typeset WAIT_TIME_IN_SECONDS="$1"
  typeset i=0
  
  if [ $# -eq 1 ] ; then
    if isNumber ${WAIT_TIME_IN_SECONDS} ; then
      LogMsg " Waiting now ${WAIT_TIME_IN_SECONDS} seconds ($( date "+%Y.%m.%d %H:%M:%S")) ..."
     
      while [ $i -lt ${WAIT_TIME_IN_SECONDS} ] ; do
        (( i = i + 1 ))
        printf "."
        sleep 1
      done
      printf "\n"
      THISRC=${__TRUE}
    fi
  fi

  return ${THISRC}
}


# ---------------------------------------------------------------------
# functions that overwrite existing functions with the same name
#

# ----------------------------------------------------------------------
# print_global_variables
#
# function: print the value of all global variables if VERBOSE is not empty
#
# usage: print_global_variables 
#
# returns: ${__TRUE}  - ok
#          ${__FALSE} - n/a
#
function print_global_variables {
  typeset __FUNCTION="print_global_variables"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}  
  typeset THISRC=${__TRUE}

  typeset CUR_OUTPUT=""

  for CUR_VAR in ${GLOBAL_VARS} ;do
    eval CUR_VAL="\$${CUR_VAR}"
    LogInfo "The value of the variable \"${CUR_VAR}\" is \"${CUR_VAL}\" "
  done
  return ${THISRC}
}


# ----------------------------------------------------------------------
# online_adb_connection
#
# function: execute "adb reconnect" if the current adb connection is "offline"
#
# usage: online_adb_connections 
#
# returns: ${__TRUE}  - found a phone with an offline adb connection
#          ${__FALSE} - no phone with offline adb connection found
#
function online_adb_connection {
  typeset __FUNCTION="online_adb_connection"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}  
  typeset THISRC=${__FALSE}

  typeset CUR_OUTPUT=""

  CUR_OUTPUT="$( adb ${ADB_OPTIONS} devices 2>&1 )"
  if [[ ${CUR_OUTPUT} == *offline* ]] ;then
    THISRC=${__TRUE}
    
    LogMsg "The current status of the adb connection is:"
    LogMsg "" 
    LogMsg "${CUR_OUTPUT}"
    LogMsg "" 

    LogMsg "Reconnecting now ...."

    CUR_OUTPUT="$( adb ${ADB_OPTIONS} reconnect 2>&1 )"

    LogMsg "" 
    LogMsg  "${CUR_OUTPUT}"
    LogMsg "" 
  fi
      
  return ${THISRC}
}


# ----------------------------------------------------------------------
# boot_phone_from_twrp_die
#
# function: if runnning as standalone script : print a message and end the script
#
#           if running as include file : end the script via the function die (if defined) if the RC is greater then 100 else do nothing
#
# usage: boot_phone_from_twrp_die [script_exit_code] [message]
#
# the parameter "message" is optional; the script adds a leading "ERROR: "
# to the message if the script_exit_code is 10 or greater
#
# returns: n/a
#
function boot_phone_from_twrp_die  {
  typeset __FUNCTION="boot_phone_from_twrp_die"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=$1
  [ $# -ne 0 ] && shift
  typeset THISMSG="$*"

  [ "${THISRC}"x = ""x ] && THISRC=0
 
  if [ ${RUNNING_AS_STANDALONE_SCRIPT} = ${__TRUE} ] ; then

#    LogMsg "The returncode is ${THISRC}"

    if [ "${THISMSG}"x != ""x ] ; then
      if [ ${THISRC} -ge 10 ] ; then
        LogError "${THISMSG} (RC=${THISRC})" >&2
      else
        LogMsg "${THISMSG}"
      fi
    fi

    exit ${THISRC}

  else    
    if [ ${THISRC} -gt 100 ] ; then
#
# end the script using the function die if that function is defined
#
      typeset -f die >/dev/null && die ${THISRC} "${THISMSG}"

#
#  this code is only executed if the function die is not defined in the script including this script
#
      RUNNING_AS_STANDALONE_SCRIPT=${__TRUE}
      boot_phone_from_twrp_die ${THISRC} "${THISMSG}"
    fi
  fi
}

# ----------------------------------------------------------------------
# wait_for_phone_to_be_in_the_bootloader
#
# function: wait up to n seconds for a phone with in the boot loader
#
# usage: wait_for_phone_to_be_in_the_bootloader [timeout_value_in_seconds]
#
# returns: ${__TRUE}  - phone booted into the bootloader
#          ${__FALSE} - phone not booted into the bootloader
#
function wait_for_phone_to_be_in_the_bootloader {
  typeset __FUNCTION="wait_for_phone_to_be_in_the_bootloader"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

#
# the values below are seconds
#
  typeset MAX_WAIT_TIME="${FASTBOOT_WAIT_TIME}"

  typeset CUR_FASTBOOT_VARIABLE=""
  
  typeset THISRC=${__FALSE}

  typeset START_TIME=""
  typeset END_TIME=""
  
  if [ "$1"x != ""x ] ;then
    isNumber $1 && MAX_WAIT_TIME=$1
  fi

  LogMsg "Waiting up to ${MAX_WAIT_TIME} seconds for the boot into the fastboot mode ..."

#  LogMsg "[$( date "+%Y.%m.%d %H:%M:%S")] "
  
  START_TIME="$( date +%s )"
  
  CUR_FASTBOOT_VARIABLE="$( ${SUDO_PREFIX} ${TIMEOUT} ${MAX_WAIT_TIME} sudo fastboot getvar version-bootloader 2>&1 )"
  if [ $? -eq 0 ] ; then
    CUR_FASTBOOT_VARIABLE="$( echo "${CUR_FASTBOOT_VARIABLE}" | ${EGREP} "version-bootloader" )"
    if [ "${CUR_FASTBOOT_VARIABLE}"x != "version-bootloader: unknown"x ] ; then
      THISRC=${__TRUE}
    fi
  fi
  
  END_TIME="$( date +%s )"
  
  LogMsg " The phone is booted into the fastboot mode after $(( END_TIME - START_TIME )) second(s)"
  
#  LogMsg "[$( date "+%Y.%m.%d %H:%M:%S")] "

  return ${THISRC}
}

# ----------------------------------------------------------------------
# check_access_via_adb
#
# function: check if the access via adb works
#
# usage:check_access_via_adb
#
# returns: ${__TRUE}  - access via adb works
#          ${__FALSE} - access via adb does not work
#
function check_access_via_adb {
  typeset __FUNCTION="check_access_via_adb"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
  
  typeset THISRC=${__FALSE}

  typeset CUR_OUTPUT=""
  typeset CUR_PHONE_PROPERTIES=""

  CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} devices 2>&1 | grep -v "List of" )"
  if [ "${CUR_OUTPUT}"x != ""x ] ; then
    online_adb_connection

    CUR_PHONE_PROPERTIES="$( ${ADB} ${ADB_OPTIONS} shell getprop 2>&1 )"    
    if [ $? -eq 0 ] ; then
      THISRC=${__TRUE}
    fi
  fi

  return ${THISRC}
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
  typeset __FUNCTION="get_usb_device_for_the_phone"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

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
# reset_the_usb_port_for_the_phone
#
# function: reset the USB port used for the phone
#
# usage: reset_the_usb_port_for_the_phone
#
# returns:  ${__TRUE}  - USB port reset done
#           ${__FALSE} - the USB port of the phone is not defined or the executable usbreset is not available via PATH, no reset done
#
# The global variable PHONE_USB_DEVICE must contain the USB port used for the phone 
#
function reset_the_usb_port_for_the_phone {
  typeset __FUNCTION="reset_the_usb_port_for_the_phone"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC="${__FALSE}"

  typeset CUR_OUTPUT=""

  typeset i=0
      
# the current USB device used for the phone may have changed after a reboot of the phone
#
  get_usb_device_for_the_phone
  if [ "${PHONE_USB_DEVICE}"x != ""x ] ; then
  
    for i in 1 2 ; do
       get_usb_device_for_the_phone

      if [ "${PHONE_USB_DEVICE}"x != ""x ] ; then
        reset_usb_port "${PHONE_USB_DEVICE}"
        THISRC=$?
        LogMsg "USB reset RC=${THISRC}"
    
        [ ${THISRC} = 0 ] && break
      fi
      sleep 2
    done

#    wait_some_seconds 3

    LogInfo "The output of \"adb devices\" is now : " && \
      LogMsg "$( adb devices )"

    get_usb_device_for_the_phone
  else
    LogWarning "${__FUNC} : Can not detect the USB port used for the phone"
  fi

  return ${THISRC}
}
  
# ----------------------------------------------------------------------
# wait_for_phone_with_a_working_adb_connection
#
# function: wait up to n seconds for a phone with a working adb connection
#
# usage: wait_for_phone_with_a_working_adb_connection [timeout_value_in_seconds]
#
# returns: ${__TRUE}  - found a phone with a working adb connection
#          ${__FALSE} - no phone with working adb connection found
#
function wait_for_phone_with_a_working_adb_connection {
  typeset __FUNCTION="wait_for_phone_with_a_working_adb_connection"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

#
# the values below are seconds
# 
  typeset MAX_WAIT_TIME=${ADB_BOOT_WAIT_TIME}
  typeset MIN_WAIT_TIME=0
  
  typeset START_RESET_TIME=30
  typeset FIRST_RESET_DONE=${__FALSE}
  
  typeset CUR_WAIT_TIME=0
  typeset INTERVALL=10
    
  typeset THISRC=${__FALSE}

  typeset CUR_OUTPUT=""
  
  typeset i=0
  if [ "$1"x != ""x ] ;then
    isNumber $1 && MAX_WAIT_TIME=$1
  fi

  (( MIN_WAIT_TIME = INTERVALL * 2 ))

  if [ ${MAX_WAIT_TIME} -lt ${INTERVALL} ] ; then
    LogWarning "The timeout value for waiting for the access via adb must be at least ${MIN_WAIT_TIME} ..."
    LogWarning "Using the the timeout value ${MIN_WAIT_TIME} now "
    MAX_WAIT_TIME="${MIN_WAIT_TIME}"
  fi
  
  LogMsg "Waiting up to ${MAX_WAIT_TIME} second(s) for a working adb connection "

  while [ ${CUR_WAIT_TIME} -lt ${MAX_WAIT_TIME} ] ; do

    check_access_via_adb 
    if [ $? -eq 0 ] ; then
      printf "\n"
      LogMsg "The connections via adb seems to work ... wait now for 10 seconds and try again to handle the adbd restart in TWRP ..."
      i=0
      while [ $i -lt 10 ] ; do
        (( i = i + 1 ))
        printf "."
        sleep 1
      done
      printf "\n"
      
      check_access_via_adb 
      if [ $? -eq 0 ] ; then
        THISRC=${__TRUE}
        break
      fi
    fi

    printf "."
    sleep ${INTERVALL}

    (( CUR_WAIT_TIME = CUR_WAIT_TIME + INTERVALL ))
    
    if [ ${CUR_WAIT_TIME} -gt ${START_RESET_TIME} -a ${FIRST_RESET_DONE} = ${__FALSE} ] ; then
      FIRST_RESET_DONE=${__TRUE}
      
      get_usb_device_for_the_phone  >/dev/null
      if [ "${PHONE_USB_DEVICE}"x != ""x ] ;then
      printf "\n"
        LogMsg "The USB device for the phone is now \"${PHONE_USB_DEVICE}\"     "
        if [ ${RESET_THE_USB_PORT} = ${__TRUE} ] ; then  
          reset_the_usb_port_for_the_phone
          wait_some_seconds 3
        fi
      fi
    fi
  done
  printf "\n"
#
# the connection does not yet work -- reset the USB port and check again
#
  if [ ${THISRC} != ${__TRUE} ] ; then
    get_usb_device_for_the_phone 
    if [ "${PHONE_USB_DEVICE}"x != ""x ] ;then
      LogMsg "The USB device for the phone is now \"${PHONE_USB_DEVICE}\"     "
      if [ ${RESET_THE_USB_PORT} = ${__TRUE} ] ; then  
        reset_the_usb_port_for_the_phone
        wait_some_seconds 3
      fi
    fi

    check_access_via_adb 
    if [ $? -eq 0 ] ; then
      THISRC=${__TRUE}
      break
    fi
  fi
  
  if [ ${THISRC} = ${__TRUE} ] ; then
    LogMsg "The adb connection is ready again after ${CUR_WAIT_TIME} seconds "
  else
    LogError "The adb connection does NOT work after waiting ${CUR_WAIT_TIME} second(s)"
    LogMsg "-" "$( adb devices )"
  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# wait_for_the_adb_daemon
#
# function: wait up to n seconds for the adb daemon to be usable
#
# usage: wait_for_the_adb_daemon [timeout_value_in_seconds]
#
# returns: ${__TRUE}  - ok, adb daemon is running and usable
#          ${__FALSE} - the adb daemon is not usable
#
function wait_for_the_adb_daemon {
  typeset __FUNCTION="wait_for_the_adb_daemon"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

#
#
# the values below are seconds
#
  typeset MAX_WAIT_TIME="${ADB_DAEMON_WAIT_TIME}"
  typeset CUR_WAIT_TIME=0
  typeset INTERVALL=1

  typeset USB_READY_STATE=""
  
  typeset THISRC=${__TRUE}

  if [ "$1"x != ""x ] ;then
    isNumber $1 && MAX_WAIT_TIME=$1
  fi

#  LogMsg "[$( date "+%Y.%m.%d %H:%M:%S")] "

  printf "Waiting up to ${MAX_WAIT_TIME} seconds for the adb daemon to get ready  "

  while [ ${CUR_WAIT_TIME} -lt ${MAX_WAIT_TIME} ] ; do

#    USB_READY_STATE="$( ${ADB} ${ADB_OPTIONS} shell getprop sys.usb.ffs.mtp.ready 2>/dev/null )"

# ???    USB_READY_STATE="$( ${ADB} ${ADB_OPTIONS} shell getprop sys.usb.state 2>/dev/null )"
    
    USB_READY_STATE="$( ${ADB} ${ADB_OPTIONS} shell getprop sys.usb.config 2>/dev/null )"
    if [ "${USB_READY_STATE}"x = ""x ] ; then
      sleep ${INTERVALL}
      printf "."
    else
      printf "\n"
      LogMsg "... the adb daemon is ready after ${CUR_WAIT_TIME} second(s)"
      break
    fi

    (( CUR_WAIT_TIME = CUR_WAIT_TIME + INTERVALL ))
  done
  printf "\n"

  if [ "${USB_READY_STATE}"x != ""x ] ; then
#    LogMsg "The adb connection is ready after ${CUR_WAIT_TIME} second(s)"

    BUILD_PRODUCT="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.build.product )"
    if [ "${BUILD_PRODUCT}"x = ""x ] ; then
      THISRC=${__FALSE}
    fi
  else
    LogError "The adb connection does NOT ready after after waiting ${CUR_WAIT_TIME} second(s)"
    LogMsg "-" "$( adb devices )"
  fi


#  LogMsg "[$( date "+%Y.%m.%d %H:%M:%S")] "

  return ${THISRC}
}


# ----------------------------------------------------------------------
# wait_until_an_android_service_is_ready
#
# function: wait until an Android service is ready for use
#
# usage: wait_until_an_android_service_is_ready [android_service] [timeout_value]
#
# returns: ${__TRUE}  - ok, the service is ready now
#          ${__FALSE} - the service is not ready now
#
function wait_until_an_android_service_is_ready {
  typeset __FUNCTION="wait_until_an_android_service_is_ready"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

#
#
# the values below are seconds
#
  typeset MAX_WAIT_TIME="${ADB_SERVICE_WAIT_TIME:=30}"
  typeset CUR_WAIT_TIME=0
  typeset INTERVALL=5

  typeset CUR_SERVICE=""
  typeset SERVICE_STATUS=""
  
  typeset THISRC=${__FALSE}

  if [ "$1"x = ""x ] ; then
    LogError "The parameter for the function \"${__FUNCTION}\" is missing"
    THISRC=${__FALSE}
  else
    CUR_SERVICE="$1"
    shift

    if [ "$1"x != ""x ] ;then
      isNumber $1 && MAX_WAIT_TIME=$1
    fi

    LogMsg "Waiting up to ${MAX_WAIT_TIME} seconds for Android service \"${CUR_SERVICE}\"  to get ready  "

    while [ ${CUR_WAIT_TIME} -lt ${MAX_WAIT_TIME} ] ; do
      SERVICE_STATUS="$( ${ADB} ${ADB_OPTIONS} shell service check ${CUR_SERVICE} 2>/dev/null  )"
      SERVICE_STATUS="$( echo "${SERVICE_STATUS}" | cut -f2 -d ":" )"
      if [ "${SERVICE_STATUS}"x != " found"x ] ; then
        sleep ${INTERVALL}
        printf "."
        (( CUR_WAIT_TIME = CUR_WAIT_TIME + INTERVALL ))

      else
        printf "\n"
        LogMsg "... the Android service \"${CUR_SERVICE}\" is ready after ${CUR_WAIT_TIME} second(s)"
        THISRC=${__TRUE}
        break
      fi
    done

    printf "\n"
    
    if [ ${THISRC} != ${__TRUE} ] ; then
      LogError "The Android service \"${CUR_SERVICE}\" is NOT ready after ${CUR_WAIT_TIME} second(s)" 
    fi
    
  fi

  return ${THISRC}
}

# ----------------------------------------------------------------------
# reset_usb_port
#
# function: reset an USB port
#
# usage: reset_usb_port [usb_port] [...]
#
# returns:  ${__TRUE}  - USB port reset done
#           ${__FALSE} - there was an error resetting at least one USB device or the executable usbreset is not available via PATH
#
# The format for the parameter is:
#
#   /dev/bus/usb/[usb_bus]/[usb_port]
#
# Example:
#
#   /dev/bus/usb/003/027
#
function reset_usb_port {
  typeset __FUNCTION="reset_usb_port"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC="${__TRUE}"
 
  typeset CUR_USB_DEVICES_TO_RESET="$*"
  typeset CUR_USB_DEVICE=""

  if [ "${USBRESET}"x = ""x ] ; then
     LogError "The executable \"usbreset\" is not available via PATH"
     THISRC=${__FALSE}
  else
    for CUR_USB_DEVICE in ${CUR_USB_DEVICES_TO_RESET} ; do
      LogMsg "Resetting the USB port \"${CUR_USB_DEVICE}\" ..."
      ( set -x ; ${SUDO_PREFIX} ${USBRESET} "${CUR_USB_DEVICE}" )
      [ $? -ne 0 ] && THISRC=${__FALSE}
    done
  fi

  return ${THISRC}
}

# ----------------------------------------------------------------------
# reset_the_usb_port_for_the_phone_if_necessary
#
# function: reset the USB port used for the phone if there is no working access to the phone
#
# usage: reset_the_usb_port_for_the_phone_if_necessary
#
# returns:  ${__TRUE}  - USB port reset done
#           ${__FALSE} - USB port not reset
#
# The global variable PHONE_USB_DEVICE must contain the USB port used for the phone 
# The USB port reset is only done if the PHONE_STATUS is 10
#
# The function also sets the global variable SERIAL_NUMBER if not already set.
#
function reset_the_usb_port_for_the_phone_if_necessary {
  typeset __FUNCTION="reset_the_usb_port_for_the_phone_if_necessary"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC="${__FALSE}"

  case ${PHONE_STATUS} in 

    10 )
      LogMsg "The status of the phone is unknown -- now resetting the USB port used by the phone ..."
      reset_the_usb_port_for_the_phone
      THISRC=$?
#
# read the serial number of the attached phone if the variable SERIAL_NUMBER is not already set
#
      set_serial_number
      ;;

     *  )
      LogMsg "The status of the phone is ${PHONE_STATUS} - a reset of the USB port is not necessary or usefull"
      ;;

  esac
  
  return ${THISRC}
}
 
 
# ----------------------------------------------------------------------
# __retrieve_phone_status
#
# function: internal function to check the status of the attached phone
#
# usage: __retrieve_phone_status
#
# returns:  ${__TRUE}  - phone status detected
#           ${__FALSE} - can not find an attached phone with working access
#
# The status of the phone is stored in the global variable PHONE_STATUS:
#
#     1 - the phone is already booted from the TWRP image
#     2 - the phone is booted from TWRP installed in the boot or recovery partition
#     3 - the phone is booted into the Android OS
#     4 - the phone is booted into bootloader 
#     5 - the phone is booted into the fastbootd
#     6 - the phone is booted into the safe mode of the Android OS
#     7 - the phone is booted into the a non-TWRP recovery installed in the boot or recovery partition
#     8 - the phone is booted into sideload mode
#     9 - the phone is booted into a recovery without working adb shell
#
#    10 - error retrieving the status of the attached phone (or no phone connected)
#    11 - the phone is attached but without permissions to access via fastboot or adb
#    12 - the phone seenms to be in EDL mode
#
#    The global variable PHONE_STATUS_OUTPUT contains the last error message regarding the status of the phone
#
#    The global variable PROP_RO_TWRP_BOOT contains the value of the property.ro.twrp.boot
#
#    The global variable PROP_RO_BOOTMODE contains the value of the property ro.bootmode
#
#    The global variable PROP_RO_BUILD_DESCRIPTION contains the value of the property ro.build.description
#
#    The global variable PROP_RO_PRODUCT_BUILD_VERSION_RELEASE contains the value of the property ro.product.build.version.release
#
#    The global variable PROP_RO_SECURE contains the value of the property ro.secure
#
#    The global variable PROP_RO_DEBUGGABLE contains the value of the property ro.debuggable
#
#    The global variable BOOT_SLOT contains the current boot slot : either _a or _b or empty if the phone does not have two slots
#
#    The global variable INACTIVE_SLOT contains the inactive slot : either _a or _b or empty if the phone does not have two slots
#
#    The global variable RUNNING_IN_AN_ADB_SESSIION is ${__TRUE} if the script is running in an adb session
#
#    The global variable PHONE_IN_EDL_MODE contains the lsusb entry for an phone in EDL mode if found
#
#    The global variable OS_BUILD_TYPE contains the build type: eng, userdebug, or user
#
#    The global variable OS_PATCH_LEVEL contains the patch level of the installed OS
#
function __retrieve_phone_status  {
  typeset __FUNCTION="__retrieve_phone_status"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}


# set -x
 
  typeset THISRC=${__TRUE}
#
# init the global variables
#
  PHONE_STATUS="99"
  PHONE_STATUS_OUTPUT=""

  BOOT_SLOT=""
  INACTIVE_SLOT=""
  
  PROP_RO_TWRP_BOOT=""
  PROP_RO_BOOTMODE=""
  PROP_RO_BUILD_DESCRIPTION=""
  PROP_RO_PRODUCT_BUILD_VERSION_RELEASE=""
  
  RO_SYS_SAFEMODE=""
  
  ROM_NAME=""
  PHONE_IN_EDL_MODE=""

  OS_PATCH_LEVEL=""
  OS_BUILD_TYPE=""

  PROP_RO_SECURE=""
  PROP_RO_DEBUGGABLE=""
  
  PROP_RO_MODVERSION=""

  ORANGE_FOX_SYSTEM_RELEASE=""

  TWRP_COMPATIBLE=""
  
# 
# init local variables
#
  typeset CUR_BOOTMODE=
  typeset CUR_OUTPUT=""

  typeset TEMPRC=""

  typeset ACCESS_VIA_ADB_IS_ENABLED=${__FALSE}
  typeset MSAFE_MODE=""
  #

  LogInfo "${__FUNCTION}: PHONE_STATUS is now \"${PHONE_STATUS}\""
  
  if [ "${SERIAL_NUMBER}"x = ""x ] ; then
    LogError "The variable SERIAL_NUMBER is NOT set - can not detect the status of the phone"
    PHONE_STATUS=10
    THISRC=${__FALSE}
 
# ---------------------------------------------------------------------
#
# first check for a connected phone via adb (adb is faster then fastboot if no phone is connected)
#
  elif [ ${THISRC} = ${__TRUE} -a ${PHONE_STATUS} = 99 ] ; then
    
    PHONE_STATUS_OUTPUT="$( adb devices 2>&1 )"
     
    LogInfo "The output of \"adb devices\" is " && \
      LogMsg "${PHONE_STATUS_OUTPUT}"

    PHONE_STATUS_OUTPUT="$( echo "${PHONE_STATUS_OUTPUT}"  | ${EGREP} "^${SERIAL_NUMBER}[[:space:]]" | sed "s/;.*//g" | cut -f2- )"

    LogInfo "The status of the phones attached via adb is " && \
      LogMsg "${PHONE_STATUS_OUTPUT}"

    if [ "${PHONE_STATUS_OUTPUT}"x = "no permissions"x -o "${PHONE_STATUS_OUTPUT}"x = "unauthorized"x ] ; then
#
# the phone is connected via adb but we do not have access
# 
      PHONE_STATUS=11
    elif [ "${PHONE_STATUS_OUTPUT}"x = ""x ] ; then
#
# no device attached via adb found
#
      LogInfo "${__FUNCTION}: no device attached via adb found"
    elif [ "${PHONE_STATUS_OUTPUT}"x = "device"x ] ; then
#
# the phone is booted into the Android OS
#
      ACCESS_VIA_ADB_IS_ENABLED=${__TRUE}

      PROP_RO_BUILD_DESCRIPTION="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.build.description )"
      PROP_RO_PRODUCT_BUILD_VERSION_RELEASE="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.product.build.version.release )"

      
      PROP_RO_SECURE="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.secure )"
      PROP_RO_DEBUGGABLE="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.debuggable )"

      PROP_RO_MODVERSION="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.modversion )"

      if [ "${PROP_RO_SECURE}"x = "0"x -a "${PROP_RO_DEBUGGABLE}"x = "1"x ] ; then
        OS_BUILD_TYPE="eng"
      elif [ "${PROP_RO_SECURE}"x = "1"x -a "${PROP_RO_DEBUGGABLE}"x = "1"x ] ; then
        OS_BUILD_TYPE="userdebug"
      elif [ "${PROP_RO_SECURE}"x = "1"x -a "${PROP_RO_DEBUGGABLE}"x = "0"x ] ; then
        OS_BUILD_TYPE="user"
      fi

      OS_PATCH_LEVEL="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.build.version.security_patch )"

      PHONE_STATUS_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell uname -a 2>&1 )"
      if [ $? -ne 0 ] ; then
#
# a phone is connected via adb but we do not have a working access
#
        PHONE_STATUS=11

        LogInfo "The result of \"${ADB} ${ADB_OPTIONS}\" shell uname -a\" is (PHONE_STATUS is no ${PHONE_STATUS}) " && \
          LogMsg "${PHONE_STATUS_OUTPUT}"

      else

#
# the phone is booted into the Android OS : Check if it'S booted into the normal mode or the safe mode
#  
        RO_SYS_SAFEMODE="$( ${TIMEOUT} 5 ${ADB} ${ADB_OPTIONS} shell su - -c "getprop ro.sys.safemode" 2>/dev/null )"
        if [ "${RO_SYS_SAFEMODE}"x = "1"x ] ; then
#
# the phone is booted into save mode of the Android OS
#
          PHONE_STATUS=6

        else

#
# do another check for safemode (this does also work for non-root users)
#
          MSAFE_MODE="$( ${ADB} ${ADB_OPTIONS}   shell dumpsys display | ${EGREP} mSafeMode | cut -f2 -d "=" )"
          if [ "${MSAFE_MODE}"x = "true"x ] ; then
#
# the phone is booted into save mode of the Android OS
            PHONE_STATUS=6
          else
#
# the phone is booted into the Android OS
#     
            PHONE_STATUS=3
          fi
        fi
      fi

    elif [ "${PHONE_STATUS_OUTPUT}"x = "recovery"x ] ; then
#
# the phone is booted into a recovery (either from the partition or from a image file)
#
      LogInfo "${__FUNCTION}: The phone is in the recovery mode"

      CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell uname -a 2>/dev/null )"
      if [ $? -eq 0 ] ; then
        ACCESS_VIA_ADB_IS_ENABLED=${__TRUE}
      else
        LogInfo "${__FUNCTION}: The phone is in the recovery mode but without adb access"
        PHONE_STATUS=9
      fi
    elif [ "${PHONE_STATUS_OUTPUT}"x = "sideload"x ] ; then
#
# the phone is connected in adb sideload mode
#
      LogInfo "${__FUNCTION}: The phone is in the sideload mode"
      PHONE_STATUS=8
    fi
  fi

# ---------------------------------------------------------------------
  
  if [ ${THISRC} = 0 -a ${ACCESS_VIA_ADB_IS_ENABLED} = ${__TRUE} ] ; then
#
# the phone is booted into a recovery  : Checking now in which one
# 
    LogInfo "${__FUNCTION}: adb access is working - reading some properties from the phone now"

    BOOT_SLOT="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.boot.slot_suffix )"
 
    if [ "${BOOT_SLOT}"x != ""x ] ; then
      [ "${BOOT_SLOT}" = "_b" ] && INACTIVE_SLOT="-a" || INACTIVE_SLOT="-b"
    fi
    
    PROP_RO_TWRP_BOOT="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.twrp.boot )"

    PROP_RO_ORANGEFOX_BOOT="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.orangefox.boot )"

    PROP_RO_BOOTMODE="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.bootmode )"
    
    PROP_RO_BUILD_DESCRIPTION="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.build.description )"
    PROP_RO_PRODUCT_BUILD_VERSION_RELEASE="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.product.build.version.release )"

    LogInfo "${__FUNCTION}: \"ro.boot.slot_suffix\" is \"${BOOT_SLOT}\" "
    LogInfo "${__FUNCTION}: \"ro.twrp.boot\" is \"${PROP_RO_TWRP_BOOT}\" "
    LogInfo "${__FUNCTION}: \"ro.bootmode\" is \"${PROP_RO_BOOTMODE}\" "
    LogInfo "${__FUNCTION}: \"ro.build.description\" is \"${PROP_RO_BUILD_DESCRIPTION}\" "
    LogInfo "${__FUNCTION}: \"ro.product.build.version.release\" is \"${PROP_RO_PRODUCT_BUILD_VERSION_RELEASE}\" "

    LogInfo "${__FUNCTION}: \"ro.secure\" is \"${PROP_RO_SECURE}\" "
    LogInfo "${__FUNCTION}: \"ro.debuggable\" is \"${PROP_RO_DEBUGGABLE}\" "
    LogInfo "${__FUNCTION}: \"ro.build.version.security_patch\" is \"${OS_PATCH_LEVEL}\" "
    LogInfo "${__FUNCTION}: \"ro.modversion\" is \"${PROP_RO_MODVERSION}\" "
 
    if [ "${PROP_RO_TWRP_BOOT}"x = "1"x ] ; then
#
# the phone is booted into TWRP
#
      if [ "${PROP_RO_BOOTMODE}"x = "recovery"x ] ; then
#
# the phone is booted in TWRP on the boot or recovery partition
#

        PHONE_STATUS=2
      else  
#
# the phone is booted in TWRP from a image file
#
        PHONE_STATUS=1
      fi


    elif [ "${PROP_RO_ORANGEFOX_BOOT}"x = "1"x ] ; then
#
# the phone is booted into OrangeFox
#
      ORANGE_FOX_SYSTEM_RELEASE="$( ${ADB} ${ADB_OPTIONS} shell getprop orangefox.system.release )"

      TWRP_COMPATIBLE=0

      if [ "${PROP_RO_BOOTMODE}"x = "recovery"x ] ; then
#
# the phone is booted in OrangeFox on the boot or recovery partition
#
        PHONE_STATUS=2
      else  
#
# the phone is booted in OrangeFox from a image file
#
        PHONE_STATUS=1
      fi
    
    else
#
# the phone is booted is either booted into the Android OS or in a non-TWRP recovery with enabeled adb
#
# ro.boottime.recovery
# [ro.frp.pst]: [/dev/block/bootdevice/by-name/frp]
#
      RO_BOOTMODE="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.bootmode )"
      LogInfo "${__FUNCTION}: \"ro.bootmode\" is \"${RO_BOOTMODE}\" "

      if [ "${RO_BOOTMODE}"x = "recovery"x ] ; then
        PHONE_STATUS=7

      else
        if [ ${PHONE_STATUS} != 6 ] ; then
          PHONE_STATUS=3
        fi
      fi      
    fi

  
    case ${PROP_RO_BUILD_DESCRIPTION} in 
   
      EU_I006D* )
        ASUS_ROM_TYPE="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.vendor.asus.beta )"
        if [ "${ASUS_ROM_TYPE}"x = "1"x ] ; then
          ROM_NAME="ASUS Android Beta"
        else
          ROM_NAME="ASUS Android"
        fi
        
        ;;

      omni* )
        ROM_NAME="OmniROM"
        ;;

      e_* )
        ROM_NAME="/e/"
        ;;

      statix* )
        ROM_NAME="StatixXOS"
        ;;

      lineage* )
        LINEAGE_OS_VERSION="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.lineage.build.version )"
        LogInfo "${__FUNCTION}: \"ro.lineage.build.version\" is \"${LINEAGE_OS_VERSION}\" "

        ROM_NAME="LineageOS ${LINEAGE_OS_VERSION}"
        ;;

      lmodroid_* )
        ROM_NAME="LMODroid"
        ;;

      * )
        ROM_NAME="unknown"
        ;;

    esac
    
  fi

# ---------------------------------------------------------------------
#
# Check if the phone is booted in fastboot or bootloader mode
#
  if [ ${THISRC} = 0 -a ${PHONE_STATUS} = 99 ] ; then

    PHONE_STATUS_OUTPUT="$( ${SUDO_PREFIX} ${TIMEOUT} ${FASTBOOT_TIMEOUT} ${FASTBOOT} devices | ${EGREP} "^${SERIAL_NUMBER}[[:space:]]" 2>&1 )"
    if [ "${PHONE_STATUS_OUTPUT}"x = ""x ] ; then
#
# no phone connected via fastboot
#
      PHONE_STATUS=10    
      CUR_BOOTMODE=""
    else
      CUR_BOOTMODE="$( echo "${PHONE_STATUS_OUTPUT}" | awk '{ print $NF}' )"

# 
# retrieve the boot slot if possible (ignore any error)
#
      CUR_OUTPUT="$( ${SUDO_PREFIX} ${TIMEOUT} ${FASTBOOT_TIMEOUT} ${FASTBOOT} ${FASTBOOT_OPTIONS} getvar current-slot 2>&1 )"
      TEMPRC=$?
      if [ ${TEMPRC} -eq 0 -a "${CUR_OUTPUT}"x != ""x ] ; then
        BOOT_SLOT="_$( echo "${CUR_OUTPUT}" | ${EGREP} "current-slot" | awk '{print $NF}' )"
      fi
    fi
    
    if [[ "${CUR_OUTPUT}" ==  *waiting\ for* ]] ; then
#
# no phone in bootloader or fastbootd connected
#
      PHONE_STATUS=10    
      :
    elif [[ "${CUR_OUTPUT}" ==  *no\ permissions* ]] ; then
#
# the phone is connected in bootloader or fastootd mode but we do not have access
#    
      PHONE_STATUS=11
    elif [ "${CUR_BOOTMODE}"x = "fastbootd"x ] ; then
#
# the phone is booted into the fastbootd
#
      PHONE_STATUS=5
    elif [ "${CUR_BOOTMODE}"x = "fastboot"x ] ; then
#
# check for fastboot mode while booted into the official ASUS Android
#
      CUR_OUTPUT="$( ${SUDO_PREFIX} ${TIMEOUT} ${FASTBOOT_TIMEOUT} ${FASTBOOT} ${FASTBOOT_OPTIONS} --unbuffered getvar super-partition-name 2>&1 | head -1 | cut -f2 -d " "  )"
      if [[ ${CUR_OUTPUT} == "super" ]] ; then
      printf "\r"
#
# the phone is booted into the fastbootd
#
        PHONE_STATUS=5
      else
#
# the phone is booted into the bootloader
#    
        PHONE_STATUS=4
      fi
    fi
  fi

  if [ ${PHONE_STATUS} -ge 10 ] ;  then
#
# check for a phone in EDL mode
#
    PHONE_IN_EDL_MODE="$(  lsusb  2>/dev/null | ${EGREP} Qualcomm | ${EGREP} "(QDL mode)" )"
    if [ "${PHONE_IN_EDL_MODE}"x != ""x ] ; then
#
# found a phone in EDL mode
#
      PHONE_STATUS=12
    fi
    
    THISRC=${__FALSE}
  fi
  
  return ${THISRC}
}



# ----------------------------------------------------------------------
# retrieve_phone_status
#
# function: function to check the status of the attached phone
#
# usage: retrieve_phone_status [reset_usb_port]
#
# returns:  ${__TRUE}  - phone status detected
#           ${__FALSE} - can not find an attached phone with working access
#
# See the comments for the internal function __retrieve_phone_status for details
# 
# If the functions is called with the parameter "0" it will reset the USB port used for the phone if necessary
#
function retrieve_phone_status  {
  typeset __FUNCTION="retrieve_phone_status"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
  
  typeset THISRC=${__TRUE}

  typeset CUR_RESET_THE_USB_PORT="$1"
  
  [ "${CUR_RESET_THE_USB_PORT}"x = ""x ] && CUR_RESET_THE_USB_PORT="${RESET_THE_USB_PORT}"
  
 
# set PHONE_STATUS to the intial value again  
  PHONE_STATUS=99

  if [ "${SERIAL_NUMBER}"x = ""x -a ${CUR_RESET_THE_USB_PORT} = ${__TRUE} ] ; then
    reset_the_usb_port_for_the_phone
  fi
  
  __retrieve_phone_status
  THISRC=$?
  
  LogInfo "${__FUNCTION}: The Status of the phone is ${PHONE_STATUS}"
  
  if [ ${CUR_RESET_THE_USB_PORT} = ${__TRUE} ] ; then
    reset_the_usb_port_for_the_phone_if_necessary
    if [ $? -eq ${__TRUE} ] ; then

# set PHONE_STATUS to the intial value again  
      PHONE_STATUS=99

      set_serial_number
      __retrieve_phone_status
      THISRC=$?
    fi
    
  fi
    
  return ${THISRC}
}


# ----------------------------------------------------------------------
# check_android_boot_image
#
# function: check if a file contains an Android boot image
#
# usage: check_android_boot_image [imagefile]
#
# returns: ${__TRUE} - the file contains an Android boot image
#          ${__FALSE} - the file does not contain an Android boot image
#
function check_android_boot_image {
  typeset __FUNCTION="check_android_boot_image"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC="${__FALSE}"

  typeset CUR_OUTPUT=""
  
  typeset TEMP_TWRP_IMAGE_TO_USE="$1"

  if [ "${TEMP_TWRP_IMAGE_TO_USE}"x != ""x ] ; then
      
    if [ ! -f "${TEMP_TWRP_IMAGE_TO_USE}" ] ; then
      LogError "The file \"${TEMP_TWRP_IMAGE_TO_USE}\" does not exist"
    else
      TEMP_TWRP_IMAGE_TO_USE="$( readlink -f "${TEMP_TWRP_IMAGE_TO_USE}" )"
      LogMsg "Checking the type of the file \"${TEMP_TWRP_IMAGE_TO_USE}\" ..."

      CUR_OUTPUT="$( file "${TEMP_TWRP_IMAGE_TO_USE}" | cut -f2- -d":" )"
      CUR_OUTPUT="$( echo ${CUR_OUTPUT} )"
      
      LogMsg "The file type is \"${CUR_OUTPUT}\" "
      if [[ "${CUR_OUTPUT}"  != *Android\ bootimg* ]] ; then
        LogMsg "The file \"${TEMP_TWRP_IMAGE_TO_USE}\" seems not to be a valid boot image for Android devices"
        THISRC=${__FALSE}
      else
        LogMsg "OK, the file \"${TEMP_TWRP_IMAGE_TO_USE}\" is a valid boot image for Android devices"               
        THISRC=${__TRUE}
      fi
    fi
  fi

  return ${THISRC}
}

# ----------------------------------------------------------------------
# get_twrp_image_for_the_installed_OS
#
# function: select the TWRP image to be used depending on the OS running on the phone
#
# usage: get_twrp_image_for_the_installed_OS
#
# returns: 
#
# returns: ${__TRUE} - The global variable TEMP_TWRP_IMAGE_TO_USE contains the filename of the TWRP image to be used
#                      The global variable CURRENT_INSTALLED_ROM contains the name of the installed ROM
#                      The global variable CURRENT_INSTALLED_ROM_VERSION contains the version of the installed ROM
#          ${__FALSE} - The global variable CURRENT_INSTALLED_ROM is empty; the function could not find a TWRP image for the installed OS
#
# The global variable PHONE_STATUS must contain the valid value before calling this function
# The TWRP images to use for specific ROMs must be defined in the variable TWRP_IMAGES_FOR_THE_RUNNING_OS
# 
# The format for each line in the variable TWRP_IMAGES_FOR_THE_RUNNING_OS is (the field separator is the colon ":"):
#
# property : value : TWRP image to use : Name of the ROM : description
#
# use "*" for the field "value" if the property must be defined but the value is not important
# The fields "Name of the ROM" and the "description" are optional
#
# Lines starting with a hash "#" are ignored
#
function get_twrp_image_for_the_installed_OS {
  typeset __FUNCTION="get_twrp_image_for_the_installed_OS"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC="${__TRUE}"

  typeset CUR_OUTPUT=""

  typeset CUR_LINE=""
  typeset LINE=""

  typeset CUR_PROPERTY_NAME=""
  typeset CUR_PROPERTY_VALUE=""
  typeset CUR_TWRP_IMAGE=""
  typeset CUR_ROM_NAME=""
  typeset CUR_DESC=""
  
  typeset PROPERTY_VALUE_IN_THE_RUNNING_OS=""
  typeset TMPFILE="/tmp/get_twrp_image_for_the_installed_OS.$$"
  
# global variables with the result of the function
#  
  TEMP_TWRP_IMAGE_TO_USE=""
  CURRENT_INSTALLED_ROM=""
  CURRENT_INSTALLED_ROM_VERSION="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.build.version.release 2>/dev/null )"

# disable joker 
#
  set -f
  
  if [ "${CURRENT_INSTALLED_ROM_VERSION}"x = ""x ] ; then
    LogError "Can not access the phone via adb"
    THISRC=${__FALSE}
  elif [ "${TWRP_IMAGES_FOR_THE_RUNNING_OS}"x = ""x ] ; then
    LogError "The environment variable TWRP_IMAGES_FOR_THE_RUNNING_OS is NOT set - can not select a TWRP image for the running OS"
    THISRC=${__FALSE}
  else

    case ${PHONE_STATUS} in 

      1  | 2 | 3 | 6 | 7 )
        LogMsg "Selecting the TWRP image to use depending on the installed OS on the phone ..."

        LogInfo "Writing the contents of the variable \"TWRP_IMAGES_FOR_IMAGE_FILES\" to the temporary file \"${TMPFILE}\" ..."

        echo "${TWRP_IMAGES_FOR_THE_RUNNING_OS}" | ${EGREP} -v "^$|^#" >"${TMPFILE}"
 
        LogInfo "Processing the contents of the temporary file \"${TMPFILE}\" ..."

        while read LINE ; do

          CUR_LINE="${LINE}"

          LogInfo "Processing the line \"${CUR_LINE}\" ..."

          CUR_PROPERTY_NAME=${CUR_LINE%%:*}
          CUR_LINE=${CUR_LINE#*:}
# remove leading and trailing blanks          
          CUR_PROPERTY_NAME=$( echo ${CUR_PROPERTY_NAME}  )

          LogInfo "The property to check is \"${CUR_PROPERTY_NAME}\" "
    
          CUR_PROPERTY_VALUE=${CUR_LINE%%:*}
          CUR_LINE=${CUR_LINE#*:}
# remove leading and trailing blanks          
          CUR_PROPERTY_VALUE=$( echo ${CUR_PROPERTY_VALUE}  )

          LogInfo "The required value for the property to check is \"${CUR_PROPERTY_VALUE}\" "

          CUR_TWRP_IMAGE=${CUR_LINE%%:*}
          CUR_LINE=${CUR_LINE#*:}
# remove leading and trailing blanks          
          CUR_TWRP_IMAGE=$( echo ${CUR_TWRP_IMAGE}  )

          LogInfo "The TWRP image to use is \"${CUR_TWRP_IMAGE}\" "

          CUR_ROM_NAME=${CUR_LINE%%:*}
          CUR_LINE=${CUR_LINE#*:}
# remove leading and trailing blanks          
          CUR_ROM_NAME=$( echo ${CUR_ROM_NAME}  )

          LogInfo "The name of the ROM is \"${CUR_ROM_NAME}\" "

          CUR_ROM_DESC=${CUR_LINE%%:*}
# remove leading and trailing blanks          
          CUR_ROM_DESC=$( echo ${CUR_ROM_DESC}  )
          
          [ "${CUR_ROM_NAME}"x = "${CUR_ROM_DESC}"x ] && CUR_ROM_DESC=""

          LogInfo "The description for the ROM is \"${CUR_ROM_DESC}\" "

          CUR_ROM_NAME="${CUR_ROM_NAME:=???}"

          if [ "${CUR_PROPERTY_NAME}"x = ""x -o "${CUR_PROPERTY_VALUE}"x = ""x -o "${CUR_TWRP_IMAGE}"x = ""x ] ; then
            LogError "The TWRP image definition \"${LINE}\"  in the variable \"TWRP_IMAGES_FOR_THE_RUNNING_OS\" is invalid"
            continue
          fi
#
# adb reads all input from STDIN !
#
          PROPERTY_VALUE_IN_THE_RUNNING_OS="$( ${ADB} ${ADB_OPTIONS} shell getprop ${CUR_PROPERTY_NAME} 2>/dev/null </dev/null )"
 
          if [ "${PROPERTY_VALUE_IN_THE_RUNNING_OS}"x != ""x ] ; then
            if [[ ${PROPERTY_VALUE_IN_THE_RUNNING_OS} == ${CUR_PROPERTY_VALUE} ]] ; then
              LogMsg "The running OS on the phone is ${CUR_ROM_NAME} (Android ${CURRENT_INSTALLED_ROM_VERSION}) ${CUR_ROM_DESC}"
              CURRENT_INSTALLED_ROM="${CUR_ROM_NAME}"
              TEMP_TWRP_IMAGE_TO_USE="${CUR_TWRP_IMAGE}"
              LogMsg "The TWRP image for this OS is \"${TEMP_TWRP_IMAGE_TO_USE}\" "
              break
            fi
          fi

          LogInfo "This line does not match"
        done <"${TMPFILE}"

# delete the temporary file
#
        \rm -rf "${TMPFILE}" 2>/dev/null 1>/dev/null

        if [ "${TEMP_TWRP_IMAGE_TO_USE}"x = ""x ] ; then

          if [ "${TWRP_IMAGE}"x = ""x ] ; then
            LogMsg "No special TWRP image found for the running OS on the phone and no TWRP image preselected - using the default TWRP image"
            TEMP_TWRP_IMAGE_TO_USE="${DEFAULT_TWRP_IMAGE}"
          fi
        fi
        ;;
        
      1 )
        LogMsg "The phone is booted from a TWRP image file"
        ;;

      * ) 
        LogMsg "The phone is NOT booted into the Android OS - can not detect which OS is installed on the phone"
        THISRC=${__FALSE}
        ;;

    esac

#
# check the TWRP image file contents
#
    if [ "${TEMP_TWRP_IMAGE_TO_USE}"x != ""x ] ; then
      check_android_boot_image "${TEMP_TWRP_IMAGE_TO_USE}" 
    fi
  fi

  set +f
  return ${THISRC}
}


# ----------------------------------------------------------------------
# select_twrp_image_for_install_image
#
# function: select the TWRP image to be used depending on the OS image file used
#
# usage: select_twrp_image_for_install_image [image_file]
#
# Without a parameter the function uses the image_file defined in the variable OS_IMAGE_TO_INSTALL
#
# returns: 
#
# returns: ${__TRUE}  - The global variable TEMP_TWRP_IMAGE_TO_USE contains the filename of the TWRP image to be used
#          ${__FALSE} - The global variable TEMP_TWRP_IMAGE_TO_USE is empty; the function could not find a TWRP image for the installed OS
#
# The TWRP images to use for specific ROMs must be defined in the variable TWRP_IMAGES_FOR_IMAGE_FILES
# 
# The format for each line in the variable TWRP_IMAGES_FOR_IMAGE_FILES is (the field separator is the colon ":"):
#
# regex for the image file : TWRP image to use : Name of the ROM : description
#
# The fields "Name of the ROM" and the "description" are optional
#
# Lines starting with a hash "#" are ignored
#
function select_twrp_image_for_install_image {
  typeset __FUNCTION="select_twrp_image_for_install_image"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC="${__TRUE}"

  typeset CUR_OUTPUT=""
  typeset CUR_LINE=""
  typeset LINE=""
  typeset CUR_REGEX_FOR_IMAGE_FILE=""
  typeset CUR_TWRP_IMAGE=""
  typeset CUR_ROM_NAME=""
  typeset CUR_ROM_DESC=""

  typeset CUR_IMAGE_FILE="${OS_IMAGE_TO_INSTALL}"

  typeset TMPFILE="/tmp/get_twrp_image_for_the_installed_OS.$$"
  
# delete the global variable for the result
#  
  TEMP_TWRP_IMAGE_TO_USE=""
  
  if [ "$1"x != ""x ] ; then
    CUR_IMAGE_FILE="$1"
  fi
  
  if [ "${NEW_TWRP_IMAGE}"x != ""x ] ; then
    LogMsg "The environment variable NEW_TWRP_IMAGE is set - using the contents of that variable"
    CUR_TWRP_IMAGE_FILE="${NEW_TWRP_IMAGE}"
  else
#
# remove the path 
#
    CUR_IMAGE_FILE="${CUR_IMAGE_FILE##*/}"

    LogInfo "Writing the contents of the variable \"TWRP_IMAGES_FOR_IMAGE_FILES\" to the temporary file \"${TMPFILE}\" ..."
    
    echo "${TWRP_IMAGES_FOR_IMAGE_FILES}" | ${EGREP} -v "^$|^#" >"${TMPFILE}"
 
    LogInfo "Processing the contents of the temporary file \"${TMPFILE}\" ..."
    
    while read LINE ; do

      CUR_LINE="${LINE}"

      LogInfo "Processing the line \"${CUR_LINE}\" ..."
      
      CUR_REGEX_FOR_IMAGE_FILE=${CUR_LINE%%:*}
      CUR_LINE=${CUR_LINE#*:}
# remove leading and trailing blanks          
      CUR_REGEX_FOR_IMAGE_FILE=$( echo ${CUR_REGEX_FOR_IMAGE_FILE}  )
  
      LogInfo "The regex for the image file is \"${CUR_REGEX_FOR_IMAGE_FILE}\" "

      CUR_TWRP_IMAGE=${CUR_LINE%%:*}
      CUR_LINE=${CUR_LINE#*:}
# remove leading and trailing blanks          
      CUR_TWRP_IMAGE=$( echo ${CUR_TWRP_IMAGE}  )

      LogInfo "The TWRP image file is \"${CUR_TWRP_IMAGE}\" "

      CUR_ROM_NAME=${CUR_LINE%%:*}
      CUR_LINE=${CUR_LINE#*:}
# remove leading and trailing blanks          
      CUR_ROM_NAME=$( echo ${CUR_ROM_NAME}  )

      LogInfo "The name of the ROM is \"${CUR_ROM_NAME}\" "

      CUR_ROM_DESC=${CUR_LINE%%:*}
# remove leading and trailing blanks          
      CUR_ROM_DESC=$( echo ${CUR_ROM_DESC}  )
        
      [ "${CUR_ROM_NAME}"x = "${CUR_ROM_DESC}"x ] && CUR_ROM_DESC=""

      LogInfo "The description for the ROM is \"${CUR_ROM_DESC}\" "


      CUR_ROM_NAME="${CUR_ROM_NAME:=???}"

      if [ "${CUR_REGEX_FOR_IMAGE_FILE}"x = ""x -o "${CUR_TWRP_IMAGE}"x = ""x ] ; then
        LogError "The TWRP image definition \"${LINE}\"  in the variable \"TWRP_IMAGES_FOR_IMAGE_FILES\" is invalid"
        continue
      fi

      if [[ ${CUR_IMAGE_FILE} == ${CUR_REGEX_FOR_IMAGE_FILE} ]] ; then
      
        LogMsg "The TWRP image file \"${CUR_IMAGE_FILE}\" seems to be an image file for ${CUR_ROM_NAME} ${CUR_ROM_DESC}"
 
        LogMsg "The TWRP image to be used for the OS installed with the image file \"${CUR_IMAGE_FILE}\" is \"${CUR_TWRP_IMAGE}\" "

        TEMP_TWRP_IMAGE_TO_USE="${CUR_TWRP_IMAGE}"
        break
      else
        LogInfo "This line does not match"        
      fi
    done <"${TMPFILE}"

# delete the temporary file
#
    \rm -rf "${TMPFILE}" 2>/dev/null 1>/dev/null

    if [ "${TEMP_TWRP_IMAGE_TO_USE}"x = ""x ] ; then
      LogMsg "No special TWRP image found for the running OS on the phone - using the default TWRP image"
      TEMP_TWRP_IMAGE_TO_USE="${DEFAULT_TWRP_IMAGE}"
    fi

#
# check the TWRP image file contents
#
    if [ "${TEMP_TWRP_IMAGE_TO_USE}"x != ""x ] ; then
      check_android_boot_image "${TEMP_TWRP_IMAGE_TO_USE}" 
    fi

  fi
  return ${THISRC}
}


# ----------------------------------------------------------------------
# init_global_vars_for_boot_phone_from_twrp
#
# function: init the global variables for the booting the phone from TWRP
#
# usage: init_global_vars_for_boot_phone_from_twrp
#
# returns: 
#
#     ${__TRUE}  - ok
#     ${__FALSE} - error
#
function init_global_vars_for_boot_phone_from_twrp  {
  typeset __FUNCTION="init_global_vars_for_boot_phone_from_twrp"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}
  
  typeset THISRC=0

#
# init the global variables
#

#
# use default values if necessary
#
  if [ "${TWRP_IMAGE_IN_PARAMETER}"x != ""x ] ; then
    TWRP_IMAGE="${TWRP_IMAGE_IN_PARAMETER}"
    NO_TWRP_IMAGE_AUTO_SELECT=${__TRUE}

    LogMsg "Using the TWRP image found in the parameter: \"${TWRP_IMAGE}\" "
  
  elif [ "${TWRP_IMAGE}"x != ""x ] ; then  
    NO_TWRP_IMAGE_AUTO_SELECT=${__TRUE}

    LogMsg "Using the TWRP image defined in the environment variable TWRP_IMAGE: \"${TWRP_IMAGE}\" "
  else
    TWRP_IMAGE="${DEFAULT_TWRP_IMAGE}"
  fi

# code NOT used anymore ????
#
if [ 0 = 1 ] ; then  
  if [ "${FASTBOOT_WAIT_TIME}"x = ""x ] ; then
    FASTBOOT_WAIT_TIME="${DEFAULT_FASTBOOT_WAIT_TIME}"
  fi
  
  if [ "${ADB_BOOT_WAIT_TIME}"x = ""x ] ; then
    ADB_BOOT_WAIT_TIME="${DEFAULT_ADB_BOOT_WAIT_TIME}"
  fi
  
  if [ "${ADB_DAEMON_WAIT_TIME}"x = ""x ] ; then
    ADB_DAEMON_WAIT_TIME="${DEFAULT_ADB_DAEMON_WAIT_TIME}"
  fi

  if [ "${DECRYPT_DATA_WAIT_TIME}"x = ""x ] ; then
    DECRYPT_DATA_WAIT_TIME="${DEFAULT_DECRYPT_DATA_WAIT_TIME}"
  fi
fi

#

  LogMsg "Using the options \"${ADB_OPTIONS}\" for the adb commands "
  LogMsg "Using the options \"${FASTBOOT_OPTIONS}\" for the fastboot commands "
 
  return ${THISRC}
}

# ----------------------------------------------------------------------
# convert_phone_status_into_status_string
#
# function: converts the phone status into a human readable string
#
# usage: convert_phone_status_into_status_string [phone_status]
#
# returns:  ${__TRUE} - the phone status is known
#           ${__FALSE} - the phone status is not known
#
# The status of the phone is stored in the global variable PHONE_STATUS:
#
#     1 - the phone is already booted from the TWRP image
#     2 - the phone is booted from TWRP installed in the boot or recovery partition
#     3 - the phone is booted into the Android OS
#     4 - the phone is booted into bootloader 
#     5 - the phone is booted into the fastbootd
#     6 - the phone is booted into the safe mode of the Android OS
#     7 - the phone is booted into the a non-TWRP recovery installed in the boot or recovery partition
#     8 - the phone is booted into sideload mode
#     9 - the phone is booted into a recovery without working adb shell
#
#    10 - error retrieving the status of the attached phone
#    11 - the phone is attached but without permissions to access via fastboot or adb
#    12 - the phone seenms to be in EDL mode

#
function convert_phone_status_into_status_string  {
  typeset __FUNCTION="convert_phone_status_into_status_string"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_PHONE_STATUS="$1"

  case ${CUR_PHONE_STATUS} in
  
   1 )
     if [ "${ORANGE_FOX_SYSTEM_RELEASE}"x != ""x ]; then
       echo "The phone is currently booted from an OrangeFox image (a TWRP compatible image)"
     else
       echo "The phone is currently booted from a TWRP image (or an TWRP compatible image)"
     fi
     ;;
     
   2 ) 
     if [ "${ORANGE_FOX_SYSTEM_RELEASE}"x != ""x ]; then
       echo "The phone is currently booted from OrangeGox installed in the boot or recovery partition (OrangeFox is TWRP compatible)"
     else
       echo "The phone is currently booted from TWRP installed in the boot or recovery partition"
     fi
     ;;
     
   3 ) 
     echo "The phone is currently booted into the Android OS"
     ;;
     
   4 ) 
     echo "The phone is currently booted into the bootloader"
     ;;
     
   5 ) 
     echo "The phone is currently booted into the fastbootd"
     ;;

   6 ) 
     echo "The phone is currently booted into the safe-mode of the Android OS"
     ;;

   7 )
     echo "The phone is booted into the non-TWRP recovery on the boot or recovery partition"
     ;;

   8 )
     echo "The phone is booted into the adb sideload mode"
     ;;
   
   9 )
     echo "The phone is booted into an recovery without working adb shell"
     ;;
     
   11 )
     echo "The phone is attached but without access via fastboot or adb"
     ;;

   12 )
     echo "The phone is attached but probably in EDL mode : \"${PHONE_IN_EDL_MODE}\" "
     ;;
          
   * )
     echo "The current status of the phone is not known: ${CUR_PHONE_STATUS}"
     THISRC=${__FALSE}
     ;;
  
  esac

  return ${THISRC}
}


# ----------------------------------------------------------------------
# print_phone_status
#
# function: print the status of the attached phone
#
# usage: print_phone_status
#
# returns:  ${__TRUE} - the phone status is known
#           ${__FALSE} - the phone status is not known
#
# The status of the phone is stored in the global variable PHONE_STATUS:
#
#     1 - the phone is already booted from the TWRP image
#     2 - the phone is booted from TWRP installed in the boot or recovery partition
#     3 - the phone is booted into the Android OS
#     4 - the phone is booted into bootloader 
#     5 - the phone is booted into the fastbootd
#     6 - the phone is booted into the safe mode of the Android OS
#     7 - the phone is booted into the a non-TWRP recovery installed in the boot or recovery partition
#     8 - the phone is booted into sideload mode
#     9 - the phone is booted into a recovery without working adb shell
#
#    10 - error retrieving the status of the attached phone
#    11 - the phone is attached but without permissions to access via fastboot or adb
#    12 - the phone seenms to be in EDL mode
#
function print_phone_status  {
  typeset __FUNCTION="print_phone_status"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
 
  LogMsg "$( convert_phone_status_into_status_string ${PHONE_STATUS} ) (PHONE_STATUS=${PHONE_STATUS})"
  if [ "${ROM_NAME}"x != ""x ] ; then
    LogMsg "The running OS on the phone is \"${ROM_NAME}\" (Android ${PROP_RO_PRODUCT_BUILD_VERSION_RELEASE}) "
  fi
  
#  if [ ${CHECK_ONLY} != ${__TRUE} ] ; then
    get_twrp_image_for_the_installed_OS
#  fi
  
  if [ "${CURRENT_INSTALLED_ROM}"x != ""x ] ; then
    LogMsg "The installed OS is \"${CURRENT_INSTALLED_ROM}\" "
  fi

  if [ "${OS_PATCH_LEVEL}"x != ""x ] ; then
    LogMsg "The patch level of the installed OS is \"${OS_PATCH_LEVEL}\" "
  fi

  if [ "${OS_BUILD_TYPE}"x != ""x ] ; then
    LogMsg "The build type of the installed OS is \"${OS_BUILD_TYPE}\" "
  fi

  if [ "${PROP_RO_MODVERSION}"x != ""x ] ; then
    LogMsg "The image used to install the OS is \"${PROP_RO_MODVERSION}\" "
  fi


  if [ "${ORANGE_FOX_SYSTEM_RELEASE}"x != ""x ] ; then
    LogMsg "The phone is booted from the OrangeFox recovery version \"${ORANGE_FOX_SYSTEM_RELEASE}\" "
  fi

  if [ "${TWRP_COMPATIBLE}"x = "0"x ] ; then
    LogMsg "The recovery is compatible to TWRP"
  elif [ "${TWRP_COMPATIBLE}"x = "1"x ] ; then
    LogMsg "The recovery is NOT compatible to TWRP"
  fi

#  if [ "${TEMP_TWRP_IMAGE_TO_USE}"x != ""x ] ; then
#    LogMsg "The TWRP file auto selected for this OS is \"${TEMP_TWRP_IMAGE_TO_USE}\" "
#  fi
  
  if [ "${BOOT_SLOT}"x != ""x ] ;  then
    LogMsg "The boot slot is ${BOOT_SLOT}."
  fi

  return ${PHONE_STATUS}
}


# ----------------------------------------------------------------------
# check_prereqs_for_boot_phone_from_twrp
#
# function: icheck the prereqs for the booting the phone from TWRP
#
# usage: check_prereqs_for_boot_phone_from_twrp
#
# returns: 
#
#     ${__TRUE}  - prereqs are okay
#     ${__FALSE} - one or more prereqs not met
#
function check_prereqs_for_boot_phone_from_twrp  {
  typeset __FUNCTION="check_prereqs_for_boot_phone_from_twrp"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

#
# check the parameter and variables
#
  typeset ERRORS_FOUND=${__FALSE}
  
  LogMsg "Checking the script prerequisites ..."
  
  if [ "${ADB}"x = ""x ] ; then
    LogError "adb not found"
    ERRORS_FOUND=${__TRUE}
  elif [ ! -x "${ADB}" ] ; then
    LogError "The adb executable \"${ADB}\" is not executable"
    ERRORS_FOUND=${__TRUE}
  fi
  
  if [ "${FASTBOOT}"x = ""x ] ; then
    LogError "fastboot not found"
    ERRORS_FOUND=${__TRUE}
  elif [ ! -x "${FASTBOOT}" ] ; then
    LogError "The fastboot executable \"${FASTBOOT}\" is not executable"
    ERRORS_FOUND=${__TRUE}
  fi
  
  if [ "${TIMEOUT}"x = ""x ] ; then
    LogError "timeout not found"
    ERRORS_FOUND=${__TRUE}
  elif [ ! -x "${TIMEOUT}" ] ; then
    LogError "The timeout executable \"${TIMEOUT}\" is not executable"
    ERRORS_FOUND=${__TRUE}
  fi
    
  if [ ${CHECK_ONLY} != ${__TRUE} ] ; then
  
    if [ "${BOOT_TARGET}"x = ""x ] ; then
      if [ ! -r "${TWRP_IMAGE}" ] ;then
        LogError "TWRP image \"${TWRP_IMAGE}\" not found"
        ERRORS_FOUND=${__TRUE}
      fi
    fi
    
    if ! isNumber "${FASTBOOT_WAIT_TIME}"  ; then
      LogError "The value for the time to wait for booting into the bootloader is not a number: \"${FASTBOOT_WAIT_TIME}\""
      ERRORS_FOUND=${__TRUE}
    else
      LogMsg "Waiting up to ${FASTBOOT_WAIT_TIME} second(s) after booting the phone into the bootloader"
    fi
    
    if ! isNumber "${ADB_BOOT_WAIT_TIME}"  ; then
      LogError "The value for the time to wait until there is a working adb connection is not a number: \"${ADB_BOOT_WAIT_TIME}\""
      ERRORS_FOUND=${__TRUE}
    else
      LogMsg "Waiting up to ${ADB_BOOT_WAIT_TIME} second(s) after booting for a working adb connection"
    fi
    
    if ! isNumber "${ADB_DAEMON_WAIT_TIME}"  ; then
      LogError "The value for the time to wait for the adb daemon to get ready is not a number: \"${ADB_DAEMON_WAIT_TIME}\""
      ERRORS_FOUND=${__TRUE}
    else
      LogMsg "Waiting to ${ADB_DAEMON_WAIT_TIME} second(s) until the adb daemon is ready to use"
    fi

    if ! isNumber "${DECRYPT_DATA_WAIT_TIME}"  ; then
      LogError "The value for the time to wait until the data partition is decrypted is not a number: \"${DECRYPT_DATA_WAIT_TIME}\""
      ERRORS_FOUND=${__TRUE}
    else
      LogMsg "Waiting up to ${DECRYPT_DATA_WAIT_TIME} second(s) until the data partition is decrypted"
    fi

    if ! isNumber "${ADB_SERVICE_WAIT_TIME}"  ; then
      LogError "The value for the time to wait until an Android service is ready to use is not a number: \"${ADB_SERVICE_WAIT_TIME}\""
      ERRORS_FOUND=${__TRUE}
    else
      LogMsg "Waiting up to ${ADB_SERVICE_WAIT_TIME} second(s) until an Android service is ready to use after rebooting the Android OS"
    fi

    if ! isNumber "${FASTBOOT_TIMEOUT}"  ; then
      LogError "The value for the timeput for the fastboot command is not a number: \"${FASTBOOT_TIMEOUT}\""
      ERRORS_FOUND=${__TRUE}
    else
      LogMsg "The timeout value for executing fastboot commmands is ${FASTBOOT_TIMEOUT} second(s)"
    fi

  fi
    
  if [ ${ERRORS_FOUND} = ${__TRUE} ] ; then
    THISRC=${__FALSE}
  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# set_serial_number
#
# function: get the serial number of the phone to use and define the parameter for fastboot and adb
#
# Usage: set_serial_number
#
# returns: 
#
#     ${__TRUE}  - ok
#     ${__FALSE} - error
#
function set_serial_number {
  typeset __FUNCTION="set_serial_number"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=0

#
# init the global variables
#
#  ADB_OPTIONS=""
#  FASTBOOT_OPTIONS=""
  
# 
# init the local variables
#
  typeset ADB_DEVCIES=""
  typeset FASTBOOT_DEVICES=""
  typeset CONNECTED_DEVICES=""
  typeset NO_OF_DEVICES=""
 
#
# check if the variable SERIAL_NUMBER is used
#
  if [ "${SERIAL_NUMBER}"x != ""x ] ; then
    LogMsg "Using the phone with the serial number found in the environment variable SERIAL_NUMBER: \"${SERIAL_NUMBER}\""
 
    echo "${ADB_OPTIONS}" | grep " -s ${SERIAL_NUMBER} " >/dev/null || \
      ADB_OPTIONS="${ADB_OPTIONS} -s ${SERIAL_NUMBER} "

    echo "${FASTBOOT_OPTIONS}" | grep " -s ${SERIAL_NUMBER} " >/dev/null || \
      FASTBOOT_OPTIONS="${FASTBOOT_OPTIONS} -s ${SERIAL_NUMBER} "

  else
#
# check if there is more then one phone connected via USB
#
    ADB_DEVICES="$( ${ADB} ${ADB_OPTIONS} devices | tail -n +2  )"
    FASTBOOT_DEVICES="$( ${SUDO_PREFIX} ${TIMEOUT} ${FASTBOOT_TIMEOUT} ${FASTBOOT} devices 2>&1 | ${EGREP} 'fastboot$|fastbootd$' )"
    
    CONNECTED_DEVICES="${ADB_DEVICES}
${FASTBOOT_DEVICES}"
  
    CONNECTED_DEVICES="$( echo "${CONNECTED_DEVICES}" | ${EGREP} -v '^$' )"
  
    NO_OF_DEVICES="$( echo "${CONNECTED_DEVICES}"  | wc -l )"
  
    if [ ${NO_OF_DEVICES} -gt 1 ] ; then
      LogMsg "Found multiple phones connected via USB:"
  
      if [ "${FASTBOOT_DEVICES}"x != ""x ] ; then
        LogMsg ""
        LogMsg "Devices available via fastboot:"
        LogMsg "-"
        LogMsg "-" "${FASTBOOT_DEVICES}"
        LogMsg "-"
      fi
      
      if [ "${ADB_DEVICES}"x != ""x ] ; then
        LogMsg ""
        LogMsg "Devices available via adb:"
        LogMsg "-"
        LogMsg "-" "${ADB_DEVICES}"
        LogMsg "-"
      fi
      
      LogMsg  ""
      LogMsg "ERROR: There are multiple phones connected via USB"
      LogMsg "       Please select a phone to boot by setting the variable SERIAL_NUMBER to the serial number of the phone that should be booted before executing this script"
      LogMsg  ""

      THISRC=${__FALSE}
    else
      SERIAL_NUMBER="$( echo "${CONNECTED_DEVICES}" | awk '{ print $1 }' )"
      if [ "${SERIAL_NUMBER}"x != ""x ] ; then
        LogMsg "Using the attached phone with the serial number \"${SERIAL_NUMBER}\" (now stored in the variable SERIAL_NUMBER)"

        echo "${ADB_OPTIONS}" | grep " -s ${SERIAL_NUMBER} " >/dev/null || \
          ADB_OPTIONS="${ADB_OPTIONS} -s ${SERIAL_NUMBER} "

        echo "${FASTBOOT_OPTIONS}" | grep " -s ${SERIAL_NUMBER} " >/dev/null || \
          FASTBOOT_OPTIONS="${FASTBOOT_OPTIONS} -s ${SERIAL_NUMBER} "
  
      fi
    fi
  fi

  return ${THISRC}
}

# ----------------------------------------------------------------------
# wait_until_data_is_mounted
#
# function: wait until /data is mounted
#
# Usage: wait_until_data_is_mounted [wait_time_in_seconds]
#
# returns: 
#
#     ${__TRUE}  - /data is mounted
#     ${__FALSE} - /data is not mounted
#
# Notes:
#
function wait_until_data_is_mounted  {
  typeset __FUNCTION="wait_until_data_is_mounted"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__FALSE}
  
  typeset TIMEOUT_VALUE=$1

  typeset ROOT_DEV=""
  typeset DATA_DEV=""
  typeset i=0
  
  TIMEOUT_VALUE=${TIMEOUT_VALUE:=10}

  
  if ! isNumber ${TIMEOUT_VALUE} ; then
    LogError "The parameter for the function \"${__FUNCTION}\" is not a number: ${TIMEOUT_VALUE}"
    THISRC=${__FALSE}
  else
    i=0
    LogMsg "Waiting up to ${TIMEOUT_VALUE} seconds until /data is mounted ..."
    while [ $i -lt ${TIMEOUT_VALUE} ] ; do
      ROOT_DEV="$( ${ADB} ${ADB_OPTIONS} shell df -h / | tail -1 |  awk '{ print $1}')"
      DATA_DEV="$( ${ADB} ${ADB_OPTIONS} shell df -h /data | tail -1 |  awk '{ print $1}' )"
      if [ "${ROOT_DEV}"x != "${DATA_DEV}"x ] ; then
        THISRC=${__TRUE}
        break
      fi
      (( i = i + 1 ))
      printf "."
      sleep 1
    done
  
    printf "\n"
  
  fi

  if [ "${ROOT_DEV}"x != "${DATA_DEV}"x ] ; then
    LogMsg "/data is mounted after ${i} second(s)."
  else
    LogMsg "WARNING: /data is still NOT mounted after ${i} second(s)."
  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# decrypt_data
#
# function: decrypt the data partition if necessary and a password is defined
#
# Usage: decrpyt_data [force]
#
# returns: 
#
#     ${__TRUE}  - partition sucessfully decrypted or decryption not necessary
#     ${__FALSE} - error decyrpting the data partition
#
# Notes:
#
# The function uses twrp if available to decrypt the files on the /data partition 
#
# If twrp is not available via PATH the phone sends the password via input command if booted into the Android OS
# (ugly -- but at least working if a pin code is used ...)
#
function decrypt_data  {
  typeset __FUNCTION="decrypt_data"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

#
  typeset THISRC=${__TRUE}
  typeset CONT=${__TRUE}
  
  typeset FORCE_ENCRYPTION="$1"
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

  typeset TESTDIR=""
  typeset DATA_IS_INITIALIZED=${__FALSE}
  typeset DATA_IS_ENCRYPTED=${__FALSE}
  typeset TWRP=""
 
  typeset i=0
  typeset MAX_WAIT_TIME=${DECRYPT_DATA_WAIT_TIME}
  typeset CRYPTO_TYPE=""

  typeset CUR_USER_PASSWORD="${USER_PASSWORD}"  

  typeset CUR_ID_ON_THE_PHONE=""
  
# check if the data partition is encrypted
#  
  TESTDIR="/sdcard/Download"
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then 
    wait_until_data_is_mounted 20 
    if [ $? -ne ${__TRUE} ] ; then
      LogError "/data is not mounted"

      DATA_IS_ENCRYPTED=${__FALSE}
      FORCE_ENCRYPTION=""

      THISRC=${__FALSE}
    fi

    TWRP="$( ${ADB} ${ADB_OPTIONS} shell which twrp )"
    CUR_ID_ON_THE_PHONE="$( ${ADB} ${ADB_OPTIONS} shell id -u -n )"

  fi
   
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then 
    sleep 2
#
# This test is necessary to catch the 1st boot from the TWRP image after the OS installation
# before the first reboot of the new installed OS
#
    if [ "${CUR_ID_ON_THE_PHONE}"x = "root"x ] ; then
      ${ADB} ${ADB_OPTIONS} shell test -d "/data/media"
      if [ $? -ne 0 ] ; then
#
# the data partition is currently not yet initialized
#
        LogMsg "/data/media not found - /data is not yet initialized"
        DATA_IS_ENCRYPTED=${__FALSE}
        DATA_IS_INITIALIZED=${__FALSE}
        FORCE_ENCRYPTION=""
        
        CONT=${__FALSE}
      fi
    fi
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then 

    DATA_IS_INITIALIZED=${__TRUE}

    LogMsg "The test directory for the encryption test is \"${TESTDIR}\" "

    LogMsg "Testing if the data partition on the phone is encrypted ..."

    if ${ADB} ${ADB_OPTIONS} shell test -d "${TESTDIR}" ; then
#
# the files in /data are not encrypted
#  
      LogMsg "The data partition is not encrypted"

      DATA_IS_ENCRYPTED=${__FALSE}
      CONT=${__FALSE}
    else
      LogMsg "The data partition is encrypted"      
    fi
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then 

    if [ "${CUR_ID_ON_THE_PHONE}"x != "root"x ] ; then    
      CUR_OUTPUT="$( set -x ; ${ADB} ${ADB_OPTIONS} shell su - -c ls -ld /data/media/0/* 2>&1 )" 
      TEMPRC=$? 
    else
      CUR_OUTPUT="$( set -x ; ${ADB} ${ADB_OPTIONS} shell ls -ld /data/media/0/* 2>&1 )"
      TEMPRC=$?
    fi
      
    if [ ${TEMPRC} = 0 ] ; then
       LogMsg "The data partition is encrypted:"
       LogMsg "-" "${CUR_OUTPUT}"
       DATA_IS_ENCRYPTED=${__TRUE}
    fi
  fi
 
  if [ "${FORCE_ENCRYPTION}"x = "force"x ] ; then
    LogMsg "Decrypting the data partition on the phone is requested via parameter"
    DATA_IS_ENCRYPTED=${__TRUE}
  fi  

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then 
  
    if [ ${DATA_IS_ENCRYPTED} = ${__FALSE} ] ; then
      if [ ${DATA_IS_INITIALIZED} = ${__TRUE} ] ;  then
        LogMsg "The data partition on the phone is either not mounted or not encrypted"
      fi
    elif [ "${USER_PASSWORD}"x = ""x -a "${DEFAULT_PASSWORD}"x = ""x ] ; then  
      LogMsg "Decrypting the data partition on the phone is requested but there is no password defined to decrypt it (the environment variable USER_PASSWORD is not set)"
      THISRC=${__FALSE}
    fi
  fi
  
  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then  
    if [ "${CUR_USER_PASSWORD}"x = ""x ] ; then
      if [ "${DEFAULT_PASSWORD}"x != ""x ] ; then
        LogMsg "The user password is not set - now using the default password from Android (${DEFAULT_PASSWORD}) to decrypt the files"
        CUR_USER_PASSWORD="${DEFAULT_PASSWORD}"
      else
        LogWarning "There is no default password defined"        
      fi
    fi

    if [ "${CUR_USER_PASSWORD}"x = "ask"x ] ; then
      printf "Please enter the password for encrypting the data partition on the phone: "
      read CUR_USER_PASSWORD
    fi
    
    if [ "${CUR_USER_PASSWORD}"x != ""x ] ; then

#      CRYPTO_TYPE="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.crypto.type )"
#      LogMsg "The data partition on the phone is encrypted"
     
      if [ "${TWRP}"x != ""x ] ; then
        LogMsg "Now decrypting the data partition on the phone using twrp ....."
        CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell twrp decrypt "${CUR_USER_PASSWORD}"  2>&1 )"
        TEMPRC=$?
        LogMsg "-" "${CUR_OUTPUT}"
        wait_some_seconds 4
      elif [[ " 3 6 " ==  *\ ${PHONE_STATUS}\ *  ]] ; then
        LogMsg "twrp not found -- now decrypting the data partition on the phone using the Android command \"input\" "

        LogMsg "Waiting up to ${MAX_WAIT_TIME} seconds to complete the decrypting "
        i=0 
        while true ; do
          CUR_OUTPUT="$( exec 2>&1 ; ${ADB} ${ADB_OPTIONS} shell input text "${CUR_USER_PASSWORD}" ; ${ADB} ${ADB_OPTIONS} shell input keyevent 66 )"
          ${ADB} ${ADB_OPTIONS} shell test -d "${TESTDIR}"  && break
          (( i = i + 1 ))
          [[ $i -gt ${MAX_WAIT_TIME} ]] && break
          sleep 1
          printf "."
        done
        printf "\n"
        echo "(Waited for $i second(s))"

      else 
        LogError "I don't know how to decrypt the data on the phone"
        THISRC=${__FALSE}
      fi      

#
# check the result
#    
      wait_for_the_adb_daemon
      ${ADB} ${ADB_OPTIONS} shell test -d "${TESTDIR}" 
      if [ $? -eq 0 ] ; then
        LogMsg "Sucessfully decrypted the data partition"
      else
        LogError "Decrypting the data partition failed"
        THISRC=${__FALSE}
      fi
    else
      LogMsg "Decryption of the data partition disabled by the user"
      THISRC=${__FALSE}
    fi
  fi
    
  return ${THISRC}
}


# ----------------------------------------------------------------------
# wipe_dalvik
#
# function: wipe the dalvik
#
# Usage: wipe_dalvik
#
# returns: 
#
#     ${__TRUE}  - succesfull
#     ${__FALSE} - an error occured
#
# Notes:
#
# The function uses twrp to wipe the dalvik; the phone must be booted into the reocvery or a recovery image
#
function wipe_dalvik {
  typeset __FUNCTION="wipe_dalvik"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

  typeset TWRP="$( ${ADB} ${ADB_OPTIONS} shell which twrp )"
  
  if [ ${PHONE_STATUS} != 1 -a ${PHONE_STATUS} != 2 ] ; then
    LogError "The phone is NOT booted from TWRP (the phone status is ${PHONE_STATUS})"
    THISRC=${__FALSE}
  elif [ "${TWRP}"x = ""x ] ; then
    LogError "Executable \"twrp\" not found on the phone"
    THISRC=${__FALSE}
  else
    LogMsg ""
    LogMsg "Wiping the dalvik ..."
    CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell ${SHELL_OPTIONS} twrp wipe dalvik 2>&1 )"
    TEMPRC=$?
    LogMsg "-" "${CUR_OUTPUT}"
    if [ ${TEMPRC} != 0 ] ; then
      LogError "Error wiping the dalvik"
      THISRC=${__FALSE}
    else
      LogMsg "Wiping the dalvik sucesfully done."            
    fi
  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# wipe_cache
#
# function: wipe the cache
#
# Usage:
#
# returns:  wipe_cache
#
#     ${__TRUE}  - succesfull
#     ${__FALSE} - an error occured
#
# Notes:
#
# The function uses twrp to wipe the cache; the phone must be booted into the reocvery or a recovery image
#
function wipe_cache {
  typeset __FUNCTION="wipe_cache"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

  typeset TWRP="$( ${ADB} ${ADB_OPTIONS} shell which twrp )"
  
  if [ ${PHONE_STATUS} != 1 -a ${PHONE_STATUS} != 2 ] ; then
    LogError "The phone is NOT booted from TWRP (the phone status is ${PHONE_STATUS})"
    THISRC=${__FALSE}
  elif [ "${TWRP}"x = ""x ] ; then
    LogError "Executable \"twrp\" not found on the phone"
    THISRC=${__FALSE}
  else
    LogMsg ""
    LogMsg "Wiping the cache ..."
    CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell ${SHELL_OPTIONS} twrp wipe cache 2>&1 )"
    TEMPRC=$?
    LogMsg "-" "${CUR_OUTPUT}"
    if [ ${TEMPRC} != 0 ] ; then
      LogError "Error wiping the cache"
      THISRC=${__FALSE}
    else
      LogMsg "Wiping the cache sucesfully done."            
    fi
  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# umount_data
#
# function: umount the /data partition
#
# Usage: umount_data
#
# returns: 
#
#     ${__TRUE}  - succesfull
#     ${__FALSE} - an error occured
#
# Notes:
#
# The function uses twrp to umount the data partition; the phone must be booted into the reocvery or a recovery image
# 
# Warning:
#
# the adb connection does not work anymore until rebooting the phone after umounting /data
#
#
function umount_data  {
  typeset __FUNCTION="umount_data"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

  typeset CUR_DATA_DEV=""
  typeset CUR_ROOT_DEV=""

  typeset DIR_TO_UMOUNT="/data"
  
  typeset TWRP="$( ${ADB} ${ADB_OPTIONS} shell which twrp )"
  
  if [ ${PHONE_STATUS} != 1 -a ${PHONE_STATUS} != 2 ] ; then
    LogError "The phone is NOT booted from TWRP (the phone status is ${PHONE_STATUS})"
    THISRC=${__FALSE}
  elif [ "${TWRP}"x = ""x ] ; then
    LogError "Executable \"twrp\" not found on the phone"
    THISRC=${__FALSE}
  else
    CUR_DATA_DEV="$( ${ADB} ${ADB_OPTIONS} shell ${SHELL_OPTIONS} df -h ${DIR_TO_UMOUNT} | tail -1 | cut -f1 -d " " )"
    CUR_ROOT_DEV="$( ${ADB} ${ADB_OPTIONS} shell ${SHELL_OPTIONS} df -h / | tail -1 | cut -f1 -d " " )"
    if [ "${CUR_DATA_DEV}"x != "${CUR_ROOT_DEV}"x ] ; then
      LogMsg "${DIR_TO_UMOUNT} is mounted to \"${CUR_DATA_DEV}\" -- umounting it now ..."
      CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell ${SHELL_OPTIONS} twrp umount ${DIR_TO_UMOUNT} 2>&1 )"
      TEMPRC=$?
      LogMsg "-" "${CUR_OUTPUT}"
      if [ ${TEMPRC} != 0 ] ; then
        LogError "Error umounting ${DIR_TO_UMOUNT}"
        THISRC=${__FALSE}
      else
        LogMsg "Umounting /data sucesfully done."      
      fi
    else
      LogMsg "${DIR_TO_UMOUNT} is not mounted to a separate partition"
    fi
  fi
  
  return ${THISRC}
}

# ----------------------------------------------------------------------
# mount_data
#
# function: mount the /data partition
#
# Usage: mount_data
#
# returns: 
#
#     ${__TRUE}  - succesfull
#     ${__FALSE} - an error occured
#
# Notes:
#
# The function uses twrp to mount the data partition; the phone must be booted into the reocvery or a recovery image
#
function mount_data  {
  typeset __FUNCTION="mount_data"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

  typeset CUR_DATA_DEV=""
  typeset CUR_ROOT_DEV=""

  typeset DIR_TO_MOUNT="/data"
  
  typeset TWRP="$( ${ADB} ${ADB_OPTIONS} shell which twrp )"
  
  if [ ${PHONE_STATUS} != 1 -a ${PHONE_STATUS} != 2 ] ; then
    LogError "The phone is NOT booted from TWRP (the phone status is ${PHONE_STATUS})"
    THISRC=${__FALSE}
  elif [ "${TWRP}"x = ""x ] ; then
    LogError "Executable \"twrp\" not found on the phone"
    THISRC=${__FALSE}
  else
    CUR_DATA_DEV="$( ${ADB} ${ADB_OPTIONS} shell ${SHELL_OPTIONS} df -h ${DIR_TO_MOUNT} | tail -1 | cut -f1 -d " " )"
    CUR_ROOT_DEV="$( ${ADB} ${ADB_OPTIONS} shell ${SHELL_OPTIONS} df -h / | tail -1 | cut -f1 -d " " )"
    if [ "${CUR_DATA_DEV}"x != "${CUR_ROOT_DEV}"x ] ; then
      LogMsg "${DIR_TO_MOUNT} is already mounted to \"${CUR_DATA_DEV}\"."
    else
      LogMsg "${DIR_TO_MOUNT} is not mounted  -- mounting it now ..."
      CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell ${SHELL_OPTIONS} twrp mount ${DIR_TO_MOUNT} 2>&1 )"
      TEMPRC=$?
      LogMsg "-" "${CUR_OUTPUT}"
      if [ ${TEMPRC} != 0 ] ; then
        LogError "Error mounting ${DIR_TO_MOUNT}"
        THISRC=${__FALSE}
      else
        LogMsg "Mounting /data sucesfully done."      

        if [ -d /data/media/0 -a ! -d /data/media/0/Download ] ; then
          LogMsg "/data is encrypted"
        fi
      fi
    fi
  fi
  
  return ${THISRC}
}

# ----------------------------------------------------------------------
# format_data
#
# function: format the /data partition
#
# Usage: format_data
#
# returns: 
#
#     ${__TRUE}  - succesfull
#     ${__FALSE} - an error occured
#
# Notes:
#
# The function uses twrp to format the data partition; the phone must be booted into the reocvery or a recovery image
#
function format_data  {
  typeset __FUNCTION="format_data"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

  typeset CUR_ERROR_MESSAGE=""
  
  typeset TWRP="$( ${ADB} ${ADB_OPTIONS} shell which twrp )"
  
  if [ ${PHONE_STATUS} != 1 -a ${PHONE_STATUS} != 2 ] ; then
    LogError "The phone is NOT booted from TWRP (the phone status is ${PHONE_STATUS})"
    THISRC=${__FALSE}
  elif [ "${TWRP}"x = ""x ] ; then
    LogError "Executable \"twrp\" not found on the phone"
    THISRC=${__FALSE}
  else

# umounting /data may kill the adb sessions and disable adb ...
# ???
    umount_data || LogError "Formating the /data partition may fail"
    
    LogMsg ""
    LogMsg "Formating /data ..."
    CUR_OUTPUT="$( set -x ; time ${ADB} ${ADB_OPTIONS} shell ${SHELL_OPTIONS} twrp format data  2>&1   )"
    TEMPRC=$?
    LogMsg "-" "${CUR_OUTPUT}"

    CUR_ERROR_MESSAGE="$( echo "${CUR_OUTPUT}" | grep "E:" )"
    if [ "${CUR_ERROR_MESSAGE}"x != ""x ] ; then
      LogError "Format ended with an error : \"${CUR_ERROR_MESSAGE}\" "
      LogMsg "-" "${CUR_OUTPUT}"
      TEMPRC=255
    fi
            
    if [ ${TEMPRC} != 0 ] ; then
      LogError "Error formating the /data partition"
      THISRC=${__FALSE}
    else
      LogMsg "Formating the data partition succesfully done."      
    fi  
  fi

  return ${THISRC}
}
  

# ----------------------------------------------------------------------
# wipe_data
#
# function: wipe the data partition
#
# Usage: wipe_data
#
# returns:  
#
#     ${__TRUE}  - succesfull
#     ${__FALSE} - an error occured
#
# Notes:
#
# The function uses twrp to wipe the data partition; the phone must be booted into the reocvery or a recovery image
#
function wipe_data  {
  typeset __FUNCTION="wipe_data"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset UMOUNT="$1"
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

  typeset TWRP="$( ${ADB} ${ADB_OPTIONS} shell which twrp )"
  
  if [ ${PHONE_STATUS} != 1 -a ${PHONE_STATUS} != 2 ] ; then
    LogError "The phone is NOT booted from TWRP (the phone status is ${PHONE_STATUS})"
    THISRC=${__FALSE}
  elif [ "${TWRP}"x = ""x ] ; then
    LogError "Executable \"twrp\" not found on the phone"
    THISRC=${__FALSE}
  else
  
# umounting /data kills the adb sessions and disable adb ...
#
#    umount_data || LogError "Wiping the /data partition may fail"
  
    LogMsg ""
    LogMsg "Wiping the data partition ..."
    CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell ${SHELL_OPTIONS} twrp wipe /data 2>&1 )"
    TEMPRC=$?
    LogMsg "-" "${CUR_OUTPUT}"
    if [ ${TEMPRC} != 0 ] ; then
      LogError "Error wiping the /data partition"
      THISRC=${__FALSE}
    else
      LogMsg "Wiping the data partition sucesfully done."            
    fi
  fi
  
  return ${THISRC}
}

# ----------------------------------------------------------------------
# format_metadata
#
# function: format the metadata partition
#
# Usage: format_metadata
#
# returns: 
#
#     ${__TRUE}  - succesfull
#     ${__FALSE} - an error occured
#
# Notes:
#
# The function uses twrp to format the metadata partition; the phone must be booted into the reocvery or a recovery image
#
function format_metadata  {
  typeset __FUNCTION="format_metadata"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

  typeset TWRP="$( ${ADB} ${ADB_OPTIONS} shell which twrp )"
  
  if [ ${PHONE_STATUS} != 1 -a ${PHONE_STATUS} != 2 ] ; then
    print_phone_status
    LogError "The phone is not booted from TWRP"
    THISRC=${__FALSE}
  elif [ "${TWRP}"x = ""x ] ; then
    LogError "Executable \"twrp\" not found on the phone"
    THISRC=${__FALSE}
  else

    LogMsg ""
    LogMsg "Formating the metadata partition ..."
  
    CUR_OUTPUT="$( exec 2>&1 ; set -x ; ${ADB} ${ADB_OPTIONS} shell umount /dev/block/by-name/metadata ;  ${ADB} ${ADB_OPTIONS} shell mke2fs -F -t ext4 /dev/block/by-name/metadata )"
    TEMPRC=$?
    LogMsg "-" "${CUR_OUTPUT}"
    if [ ${TEMPRC} != 0 ] ; then
      LogError "Error formating the metadata partition"
      THISRC=${__FALSE}
    else
      LogMsg "Formating the metadata partition sucesfully done."            
    fi
  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# list_running_adb_daemons
#
# function: list the running adb daemons
#
# Usage: list_running_adb_daemons
#
# returns: 
#
#     ${__TRUE}  - running adb daemons found
#     ${__FALSE} - no running adb daemons found
#
# Notes:
#
#
function list_running_adb_daemons  {
  typeset __FUNCTION="list_running_adb_daemons"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CUR_OUTPUT=$$
  
  CUR_OUTPUT="$( ps -ef  | ${EGREP} -v grep | ${EGREP} " adb " )" 
  if [ $? -eq 0 ] ; then
    LogMsg "Running adb daemons are now:" 
    LogMsg "-"
    LogMsg "-" "${CUR_OUTPUT}" 
    LogMsg "-"
  else
    THISRC=${__FALSE}
  fi

  return ${THISRC}
}

# ----------------------------------------------------------------------
# kill_adb_daemon 
#
# function: kill the adb daemon  on the PC
#
# Usage: kill_adb_daemon
#
# returns: 
#
#     ${__TRUE}  - succesfull
#     ${__FALSE} - an error occured
#
# Notes:
#
#
function kill_adb_daemon  {
  typeset __FUNCTION="kill_adb_daemon"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0
 
  CUR_OUTPUT="$( set -x ;  ${ADB} ${ADB_OPTIONS} kill-server 2>&1 )"
  TEMPRC=$?
  
  LogMsg "-" "${CUR_OUTPUT}"
 
  LogMsg "-"
  LogMsg "The returncode of the command is ${TEMPRC}"
  LogMsg "-"


  return ${THISRC}
}


# ----------------------------------------------------------------------
# start_adb_daemon
#
# function: start the adb daemon manually
#
# Usage: start_adb_daemon [root]
#
# returns: 
#
#     ${__TRUE}  - succesfull
#     ${__FALSE} - an error occured
#
# Notes:
#
function start_adb_daemon  {
  typeset __FUNCTION="start_adb_daemon"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

  typeset CUR_ADB_USER=""
  typeset CUR_PREFIX=""
  
  typeset CUR_USER_RUNNING_THIS_SCRIPT="$( id -un )"

  if [ $# -ne 0 ] ; then
    if [ "$1"x = "root"x -a $# -eq 1 ] ; then
      LogMsg "Starting the adb daemon as user \"root\" "
      CUR_PREFIX="sudo"
    else
      LogWarning "restart_adb_daemon: Ignoring unknown parameter \"$*\"   "
    fi
  fi

  list_running_adb_daemons
  if [ $? -eq ${__TRUE} ] ; then
    TEMPRC=0
  else  

    LogMsg "Starting the adb deamon now ..."
    
    CUR_OUTPUT="$( set -x ;  ${CUR_PREFIX} ${ADB} ${ADB_OPTIONS} start-server 2>&1 )"
    TEMPRC=$?

    list_running_adb_daemons
  
    LogMsg "Testing the access now ..."

    CUR_OUTPUT="$( set -x ; ${ADB} ${ADB_OPTIONS} shell uname -a 2>&1 )"
    TEMPRC=$?
    if [ ${TEMPRC} != 0 ] ; then
      LogMsg "-"
      LogMsg "-" "${CUR_OUTPUT}"
      LogMsg "-"

      CUR_OUTPUT="$( set -x ; ${ADB} ${ADB_OPTIONS} devices 2>&1 )"
      LogMsg "-"
      LogMsg "-" "${CUR_OUTPUT}"
      LogMsg "-"
    else
      LogMsg "... the access via adb works"
    fi
  fi

  if [ ${TEMPRC} != 0 ] ; then
    LogError "The access via adb does not work anymore"
    THISRC=${__FALSE}
  fi
       

  return ${THISRC}
}

# ----------------------------------------------------------------------
# restart_adb_daemon_manually
#
# function: restart the adb daemon on the PC manually (no systemd service)
#
# Usage: restart_adb_daemon_manually [root]
#
# returns: 
#
#     ${__TRUE}  - succesfull
#     ${__FALSE} - an error occured
#
# Notes:
#
#
function restart_adb_daemon_manually  {
  typeset __FUNCTION="restart_adb_daemon_manually"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0
 
  typeset CUR_ADB_USER=""
  typeset CUR_PREFIX=""
  
  typeset CUR_USER_RUNNING_THIS_SCRIPT="$( id -un )"

  typeset CUR_ADB_PORT="${ADB_PORT:=${DEFAULT_ADB_PORT}}"
  
  list_running_adb_daemons
  
  if [ $# -ne 0 ] ; then
    if [ "$1"x = "root"x -a $# -eq 1 ] ; then
      LogMsg "Restarting the adb daemon as user \"root\" "
    
      CUR_PREFIX="sudo"
    else
      LogWarning "restart_adb_daemon: Ignoring unknown parameter \"$*\"   "
    fi
  fi

  LogMsg "Killing the adb deamon now ..."
    
  CUR_OUTPUT="$( ps -ef | ${EGREP} -i " adb " | ${EGREP} "${CUR_ADB_PORT}" | ${EGREP} fork-server  )"
  if [ "${CUR_OUTPUT}"x  = ""x ] ; then
    LogMsg "There is no adb daemon currently running"
  else
    CUR_ADB_USER="$( echo "${CUR_OUTPUT}" |  awk '{ print $1}' )"
    LogMsg "The running adb daemon was started by the user \"${CUR_ADB_USER}\" "
    if [ "${CUR_ADB_USER}"x = "${CUR_USER_RUNNING_THIS_SCRIPT}"x  ] ; then
      :
    elif [ "${CUR_ADB_USER}"x = "root"x ] ; then
      CUR_PREFIX="sudo"
    else
      LogWarningMsg "The running adb daemon was started by the user \"${CUR_ADB_USER}\" but the current user is \"${CUR_USER_RUNNING_THIS_SCRIPT}\" "
    fi
    
    LogMsg "Stopping the adb daemon now ..."
  
    CUR_OUTPUT="$( set -x ; ${CUR_PREFIX} ${ADB} ${ADB_OPTIONS} kill-server 2>&1 )"
    TEMPRC=$?
    LogMsg "-" "${CUR_OUTPUT}"
 
    LogMsg "-"
    LogMsg "The returncode of the command is ${TEMPRC}"

  fi
  
  LogMsg "Starting the adb daemon now ..."
  
  CUR_OUTPUT="$( set -x ; ${CUR_PREFIX} ${ADB} ${ADB_OPTIONS} start-server 2>&1 )"
  TEMPRC=$?
  
  LogMsg "-" "${CUR_OUTPUT}"
 
  LogMsg "-"
  LogMsg "The returncode of the command is ${TEMPRC}"
  LogMsg "-"

  list_running_adb_daemons
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# restart_systemd_service
#
# function: restart a systemd service if it exists and is running
#
# Usage: restart_systemd_service [systemd_service]
#
# returns: 
#
#     0 - systemd service succesfully restarted
#     1 - systemd service is not defined
#     2 - systemd service is not running
#    11 - parameter missing
#    99 - error restarting the systemd service
#
# Notes:
#
# 
function restart_systemd_service  {
  typeset __FUNCTION="restart_systemd_service"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=11
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0
   
  typeset CUR_PREFIX=""
  
  typeset CUR_SYSTEMD_SERVICE="$1"

  if [ "$( id -un )"x != "root"x ] ; then
    CUR_PREFIX="sudo"
    LogInfo "Executing the commands to restart the systemd service using \"sudo\" "
  fi

  if [ "${CUR_SYSTEMD_SERVICE}"x != ""x ]  ; then
    CUR_OUTPUT="$( systemctl show  --property=FragmentPath "${CUR_SYSTEMD_SERVICE}" 2>&1  | cut -f2- -d "=" )"
    if [ "${CUR_OUTPUT}"x = ""x ] ; then
      THISRC=1
      LogInfo "The systemd service \"${CUR_SYSTEMD_SERVICE}\" is not defined"
    else
      CUR_OUTPUT="$( systemctl is-active "${CUR_SYSTEMD_SERVICE}" 2>&1  | cut -f2- -d "=" )"
      if [ "${CUR_OUTPUT}"x != "active"x ] ; then
        THISRC=2
        LogInfo "The systemd service \"${CUR_SYSTEMD_SERVICE}\" is not running"
      else
        LogMsg "The status of the systemd service \"${CUR_SYSTEMD_SERVICE}\" is :"
        LogMsg "-"
        LogMsg "-" "$( systemctl status "${CUR_SYSTEMD_SERVICE}" 2>& 1)"
        LogMsg "-"
  
        LogMsg "Restarting the systemd service \"${CUR_SYSTEMD_SERVICE}\" ..."
        CUR_OUTPUT="$( ${CUR_PREFIX} systemctl restart "${CUR_SYSTEMD_SERVICE}" 2>&1 )"
        TEMPRC=$?
        
        LogInfo "The output of the command to restart the systemd service \"${CUR_SYSTEMD_SERVICE}\" is:" && \
          LogMsg "-" "${CUR_OUTPUT}"
  
        LogMsg "The status of the systemd service \"${CUR_SYSTEMD_SERVICE}\" is now:"
        LogMsg "-"
        LogMsg "-" "$( systemctl status "${CUR_SYSTEMD_SERVICE}" 2>& 1)"
        LogMsg "-"
  
        CUR_OUTPUT="$( systemctl is-active "${CUR_SYSTEMD_SERVICE}" 2>&1  | cut -f2- -d "=" )"
        if [ "${CUR_OUTPUT}"x = "active"x ] ; then
          THISRC=0
          LogMsg "systemd service \"${CUR_SYSTEMD_SERVICE}\" successfully restarted"
        else
          LogMsg "Restarting the systemd service \"${CUR_SYSTEMD_SERVICE}\" failed"
          THISRC=99
        fi
      fi
    fi
  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# restart_adb_daemon
#
# function: restart the adb daemon on the PC either via systemd or manual
#
# Usage: restart_adb_daemon [root]
#
# returns: 
#
#     ${__TRUE}  - succesfull
#     ${__FALSE} - an error occured
#
# Notes:
#
# The function restarts the adb daemon via systemd service if it was started by the systemd, if not the adb daemon is restarted manually.
# If the running adb daemon was started by the user root it will be restarted by the user root using "sudo".
#
function restart_adb_daemon  {
  typeset __FUNCTION="restart_adb_daemon"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

# 
# first try to restart the adb daemon via systemd

  restart_systemd_service "adb"
  TEMPRC=$?
  
  if [ ${TEMPRC} -lt 99 ] ; then
#
# there is no running systemd service for adb -> restart the adb daemon manually
#
    restart_adb_daemon_manually $*
    THISRC=$?
  else
#  
# the adb daemon was started via systemd and the restart of the adb daemon via systemd service failed
#  
    THISRC=${__FALSE}
  fi

  return ${THISRC}
}


# ----------------------------------------------------------------------
# enable_safe_mode
#
# function: prepare the phone for booting into the safemode
#
# Usage :  enable_safe_mode
#
# returns: 
#
#     ${__TRUE}  - the next reboot of the phone is into the safemode
#     ${__FALSE} - could not enable the safeode
#
function enable_safe_mode  {
  typeset __FUNCTION="enable_safe_mode"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  if [ ${PHONE_STATUS} != 6 -a ${PHONE_STATUS} != 3 ] ; then
    LogError "The phone must be booted into the Android OS to reboot it into the safe mode (PHONE_STATUS is ${PHONE_STATUS})"
    THISRC=${__FALSE}
  else
    ${ADB} ${ADB_OPTIONS} shell su - -c "setprop persist.sys.safemode 1" 2>/dev/null
    if [ $? -ne 0 ] ; then
      ${ADB} ${ADB_OPTIONS} shell setprop persist.sys.safemode 1 2>/dev/null
      if [ $? -ne 0 ] ; then
        LogError "No root access - rebooting into the safe mode requires root access"
        THISRC=${__FALSE}
      fi
    fi
  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# copy_file_on_the_phone
#
# function: copy a file or block device on the phone via dd
#
# Usage :  copy_file_on_the_phone [source] [target]
#
# source and target can either be a file or a block device on the phone
# The function uses the prefix "su - -c" only if necessary
# 
# returns: 
#
#     ${__TRUE}  - copying was sucessfull
#     ${__FALSE} - an error occured
#
function copy_file_on_the_phone  {
  typeset __FUNCTION="copy_file_on_the_phone"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

  typeset CMD_PREFIX=""
  
  typeset SOURCE="$1"
  typeset TARGET="$2"
  
  typeset SOURCE_CHKSUM=0
  typeset TARGET_CHKSUM=0
  
  typeset SOURCE_ABS_PATH=""
  typeset TARGET_ABS_PATH=""
  
  typeset SHELL_USER_ON_THE_PHONE=""
     
  if [ ${THISRC} = ${__TRUE} ] ; then
    if [ "${TARGET}"x = ""x ] ; then
      LogError "${__FUNCTION}: parameter missing: \"$*\"  "
      THISRC=${__FALSE}
    elif [ $# -gt 2 ] ; then
      LogError "${__FUNCTION}: Too much parameter: \"$*\" "
      THISRC=${__FALSE}
    elif [[ ${SOURCE} != /* ]] ; then
      LogError "The source is not a fully qualified filename: \"${SOURCE}\" "
      THISRC=${__FALSE}
    elif [[ ${TARGET} != /* ]] ; then
      LogError "The target is not a fully qualified filename: \"${TARGET}\""
      THISRC=${__FALSE}      
    fi
  fi

  if [[ " 1 2 3 6 9 " !=  *\ ${PHONE_STATUS}\ *  ]] ; then
    LogError "Invalid phone status to to copy a file on the phone using dd"
    THISRC=${__FALSE}
  fi    

  if [ ${THISRC} = ${__TRUE} ] ; then

    LogMsg "Copying \"${SOURCE}\" to \"${TARGET}\" using dd ..."

    SHELL_USER_ON_THE_PHONE="$( ${ADB} ${ADB_OPTIONS} shell id -un )"
    if [ $? -ne 0 ] ; then
      LogError "The access via adb to the phone does not work"
      THISRC=${__FALSE}
    fi
  fi
  
  if [ ${THISRC} = ${__TRUE} ] ; then
    if [ "${SHELL_USER_ON_THE_PHONE}"x != "root"x ] ; then
      ${ADB} ${ADB_OPTIONS} shell test -r "${SOURCE}" 2>/dev/null && ${ADB} ${ADB_OPTIONS} shell touch "${TARGET}" 2>/dev/null
      if [ $? -eq 0 ] ; then
        LogMsg "No root access necessary to create the copy"
      else
        LogMsg "Root access is necessary to create the copy"
    
        CMD_PREFIX="su - -c "
        LogMsg "The shell user on the phone is ${SHELL_USER_ON_THE_PHONE} -- uses the prefix \"${CMD_PREFIX}\" for the commands to execute"
      fi
    else
      LogMsg "The shell user on the phone is the user \"root\" "    
    fi
  fi
     
  if [ ${THISRC} = ${__TRUE} ] ; then
    if  ! ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX} test -r "${SOURCE}"  ; then
      LogError "The source \"${SOURCE}\" does not exist"
      THISRC=${__FALSE}
    fi
  fi

  if [ ${THISRC} = ${__TRUE} ] ; then  

    ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX} test -L ${SOURCE} && \
      SOURCE_ABS_PATH="$( ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX} readlink ${SOURCE} )" || \
      SOURCE_ABS_PATH="${SOURCE}"

    ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX} test -L  ${TARGET} && \
      TARGET_ABS_PATH="$( ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX} readlink ${TARGET} )" || \
      TARGET_ABS_PATH="${TARGET}"
    
    if [ "${SOURCE_ABS_PATH}"x = "${TARGET_ABS_PATH}"x ] ; then
      LogError "Source \"${SOURCE_ABS_PATH}\" and target \"${TARGET_ABS_PATH}\" are identical"
      THISRC=${__FALSE}
    fi
  fi        

  if [ ${THISRC} = ${__TRUE} ] ; then
    CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX}  dd  if="${SOURCE}" of="${TARGET}" )"
    TEMPRC=$?
    LogMsg "-" "${CUR_OUTPUT}"
    if  [ ${TEMPRC} != 0 ] ; then
      LogError "Error copying \"${SOURCE}\" to \"${TARGET}\" using dd ..."
      THISRC=${__FALSE}
    else
      LogMsg "Calculating the checksum of source and target ..."
      LogMsg ""
      SOURCE_CHKSUM="$( ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX}  cksum "${SOURCE}"  )"  
      TARGET_CHKSUM="$( ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX}  cksum "${TARGET}"  )"  
      
      LogMsg "${SOURCE_CHKSUM}"
      LogMsg "${TARGET_CHKSUM}"

      if [ ${SOURCE_CHKSUM%% *} != ${TARGET_CHKSUM%% *} ] ; then
        LogError "The check sums are not equal - something went wrong"
        THISRC=${__FALSE}
      else
        LogMsg ""
        LogMsg "OK, the check sums from source and target are equal"        
      fi
    fi
  fi
  
  return ${THISRC}
}



# ----------------------------------------------------------------------
# download_file_from_the_phone
#
# function: download_file_from_the_phone using dd
#
# Usage :  download_file_from_the_phone [file_on_the_phone] [local_file]
#
# file_on_the_phone can either be a file or a block device on the phone
# The function uses the prefix "su - -c" only if necessary
#
# local_file is a file on the PC
#
# returns: 
#
#     ${__TRUE}  - download sucessfull
#     ${__FALSE} - an error occured
#
function download_file_from_the_phone  {
  typeset __FUNCTION="download_file_from_the_phone"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

  typeset CMD_PREFIX=""
  
  typeset SOURCE="$1"
  typeset TARGET="$2"
  
  typeset SOURCE_CHKSUM=0
  typeset TARGET_CHKSUM=0
  
  typeset SOURCE_ABS_PATH=""
  typeset TARGET_ABS_PATH=""
       
  if [ ${THISRC} = ${__TRUE} ] ; then
    if [ "${TARGET}"x = ""x ] ; then
      LogError "${__FUNCTION}: parameter missing: \"$*\"  "
      THISRC=${__FALSE}
    elif [ $# -gt 2 ] ; then
      LogError "${__FUNCTION}: Too much parameter: \"$*\" "
      THISRC=${__FALSE}
    elif [[ ${SOURCE} != /* ]] ; then
      LogError "The source is not a fully qualified filename: \"${SOURCE}\" "
      THISRC=${__FALSE}
    elif [[ ${TARGET} != /* ]] ; then
      LogError "The target is not a fully qualified filename; \"${TARGET}\""
      THISRC=${__FALSE}      
    fi
  fi

  if [[ " 1 2 3 6 9 " !=  *\ ${PHONE_STATUS}\ *  ]] ; then
    LogError "Invalid phone status to download a file from the phone"
    THISRC=${__FALSE}
  fi    

  if [ ${THISRC} = ${__TRUE} ] ; then

    LogMsg "Downloading the file \"${SOURCE}\" to the local file \"${TARGET}\" using dd ..."

    SHELL_USER_ON_THE_PHONE="$( ${ADB} ${ADB_OPTIONS} shell id -un )"
    if [ $? -ne 0 ] ; then
      LogError "The access via adb to the phone does not work"
      THISRC=${__FALSE}
    fi
  fi
  
  if [ ${THISRC} = ${__TRUE} ] ; then
    if [ "${SHELL_USER_ON_THE_PHONE}"x != "root"x ] ; then

      ${ADB} ${ADB_OPTIONS} shell test -r "${SOURCE}" 2>/dev/null
      if [ $? -eq 0 ] ; then
        LogMsg "No root access necessary to download the file"
      else
        LogMsg "Root access is necessary to download the file"
    
        CMD_PREFIX="su - -c "
        LogMsg "The shell user on the phone is ${SHELL_USER_ON_THE_PHONE} -- uses the prefix \"${CMD_PREFIX}\" for the commands to execute"
      fi
    else
      LogMsg "The shell user on the phone is the user \"root\" "    
    fi
  fi
     
  if [ ${THISRC} = ${__TRUE} ] ; then
    if  ! ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX} test -r "${SOURCE}"  ; then
      LogError "The source \"${SOURCE}\" does not exist"
      THISRC=${__FALSE}
    fi
  fi

  if [ ${THISRC} = ${__TRUE} ] ; then
    CUR_OUTPUT="$( ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX}  dd  if="${SOURCE}" | dd of="${TARGET}" )"
    TEMPRC=$?
    LogMsg "-" "${CUR_OUTPUT}"
    if  [ ${TEMPRC} != 0 ] ; then
      LogError "Error downloading \"${SOURCE}\" to \"${TARGET}\" using dd ..."
      THISRC=${__FALSE}
    else
      LogMsg "Calculating the checksum of source and target ..."
      LogMsg ""
      SOURCE_CHKSUM="$( ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX}  cksum "${SOURCE}"  )"  
      TARGET_CHKSUM="$(  cksum "${TARGET}"  )"  
      
      LogMsg "${SOURCE_CHKSUM}"
      LogMsg "${TARGET_CHKSUM}"

      if [ ${SOURCE_CHKSUM%% *} != ${TARGET_CHKSUM%% *} ] ; then
        LogError "The check sums are not equal - something went wrong"
        THISRC=${__FALSE}
      else
        LogMsg ""
        LogMsg "OK, the check sums from source and target are equal"        
      fi
    fi
  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# upload_file_to_the_phone
#
# function: upload_file_to_the_phone using dd
#
# Usage :  upload_a_file_to_the_phone [local_file] [file_on_the_phone] 
#
# local_file is a file on the PC
#
# file_on_the_phone can either be a file or a block device on the phone
# The function uses the prefix "su - -c" only if necessary
#
# returns: 
#
#     ${__TRUE}  - download sucessfull
#     ${__FALSE} - an error occured
#
function upload_file_to_the_phone  {
  typeset __FUNCTION="upload_file_to_the_phone"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}
  
  typeset CUR_OUTPUT=""
  typeset TEMPRC=0

  typeset CMD_PREFIX=""
  
  typeset SOURCE="$1"
  typeset TARGET="$2"
  
  typeset SOURCE_CHKSUM=0
  typeset TARGET_CHKSUM=0
  
  typeset SOURCE_ABS_PATH=""
  typeset TARGET_ABS_PATH=""
       
  if [ ${THISRC} = ${__TRUE} ] ; then
    if [ "${TARGET}"x = ""x ] ; then
      LogError "${__FUNCTION}: parameter missing: \"$*\"  "
      THISRC=${__FALSE}
    elif [ $# -gt 2 ] ; then
      LogError "${__FUNCTION}: Too much parameter: \"$*\" "
      THISRC=${__FALSE}
    elif [[ ${SOURCE} != /* ]] ; then
      LogError "The source is not a fully qualified filename: \"${SOURCE}\""
      THISRC=${__FALSE}
    elif [[ ${TARGET} != /* ]] ; then
      LogError "The target is not a fully qualified filename: \"${TARGET}\""
      THISRC=${__FALSE}      
    fi
  fi

  if [[ " 1 2 3 6 9 " !=  *\ ${PHONE_STATUS}\ *  ]] ; then
    LogError "Invalid phone status to upload a file to the phone"
    THISRC=${__FALSE}
  fi    

  if [ ${THISRC} = ${__TRUE} ] ; then

    LogMsg "Uploading the local file \"${SOURCE}\" to \"${TARGET}\" on the phone using dd ..."

    SHELL_USER_ON_THE_PHONE="$( ${ADB} ${ADB_OPTIONS} shell id -un )"
    if [ $? -ne 0 ] ; then
      LogError "The access via adb to the phone does not work"
      THISRC=${__FALSE}
    fi
  fi
  
  if [ ${THISRC} = ${__TRUE} ] ; then
    if [ "${SHELL_USER_ON_THE_PHONE}"x != "root"x ] ; then

      ${ADB} ${ADB_OPTIONS} shell touch "${TARGET}" 2>/dev/null
      if [ $? -eq 0 ] ; then
        LogMsg "No root access necessary to upload the file"
      else
        LogMsg "Root access is necessary to upload the file"

        CMD_PREFIX="su - -c "
        LogMsg "The shell user on the phone is ${SHELL_USER_ON_THE_PHONE} -- uses the prefix \"${CMD_PREFIX}\" for the commands to execute"
      fi
    else
      LogMsg "The shell user on the phone is the user \"root\" "    
    fi
  fi
     
  if [ ${THISRC} = ${__TRUE} ] ; then
    if  ! test -r "${SOURCE}"  ; then
      LogError "The local source \"${SOURCE}\" does not exist"
      THISRC=${__FALSE}
    fi
  fi

  if [ ${THISRC} = ${__TRUE} ] ; then
    CUR_OUTPUT="$( dd if="${SOURCE}" | ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX}  dd of="${TARGET}" )"
    TEMPRC=$?
    LogMsg "-" "${CUR_OUTPUT}"
    if  [ ${TEMPRC} != 0 ] ; then
      LogError "Error uploading \"${SOURCE}\" to \"${TARGET}\" using dd ..."
      THISRC=${__FALSE}
    else
      LogMsg "Calculating the checksum of source and target ..."
      LogMsg ""
      TARGET_CHKSUM="$(  cksum "${SOURCE}"  )"  
      SOURCE_CHKSUM="$( ${ADB} ${ADB_OPTIONS} shell ${CMD_PREFIX}  cksum "${TARGET}"  )"  
      
      LogMsg "${SOURCE_CHKSUM}"
      LogMsg "${TARGET_CHKSUM}"

      if [ ${SOURCE_CHKSUM%% *} != ${TARGET_CHKSUM%% *} ] ; then
        LogError "The check sums are not equal - something went wrong"
        THISRC=${__FALSE}
      else
        LogMsg ""
        LogMsg "OK, the check sums from source and target are equal"        
      fi
    fi
  fi
  
  return ${THISRC}
}


# ----------------------------------------------------------------------
# boot_phone_from_the_TWRP_image
#
# function: reboot the phone from the TWRP image
#
# Usgae: boot_phone_from_the_TWRP_image [twrp_image_file]
#
# returns: ${__TRUE}  - ok
#          ${__FALSE} - error
#
# The current status of the phone is stored in the global variable PHONE_STATUS:
#
#     1 - the phone is already booted from the TWRP image
#     2 - the phone is booted from TWRP installed in the boot or recovery partition
#     3 - the phone is booted into the Android OS
#     4 - the phone is booted into bootloader 
#     5 - the phone is booted into the fastbootd
#     6 - the phone is booted into the safe mode of the Android OS
#     7 - the phone is booted into the a non-TWRP recovery installed in the boot or recovery partition
#     8 - the phone is booted into sideload mode
#     9 - the phone is booted into a recovery without working adb shell
#
# The global variable PHONE_BOOT_ERROR contains the error code if booting the phone fails
#
function boot_phone_from_the_TWRP_image {
  typeset __FUNCTION="boot_phone_from_the_TWRP_image"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

  typeset THISRC=${__TRUE}

  typeset CUR_TWRP_IMAGE="$1"

#
# init global variables
#
  PHONE_BOOT_ERROR=""
  
#
# init local variables
#
  typeset BOOT_INTO_BOOTLOADER_USING_ADB=${__FALSE}

 # ---------------------------------------------------------------------
# use the default twrp image file if necessary
#
  if [ "${CUR_TWRP_IMAGE}"x != ""x ] ; then
#    LogMsg "Using the TWRP image found in the parameter for the function \"${__FUNCTION}\" "
    :
  else
    CUR_TWRP_IMAGE="${TWRP_IMAGE}"
  fi

# ---------------------------------------------------------------------
  
  if [ ${PHONE_STATUS} = 1 -a ${THISRC} = ${__TRUE} ] ; then
#
# the phone is booted from the TWRP image
#
    LogMsg "The phone is booted from a TWRP image "
    
    if [ ${FORCE_REBOOT_INTO_TWRP_IMAGE}x = ${__TRUE}x ] ; then
      LogMsg "Rebooting the phone from the TWRP image requested via parameter"
      BOOT_INTO_BOOTLOADER_USING_ADB=${__TRUE}
    fi
  fi

# ---------------------------------------------------------------------
  
  if [ ${PHONE_STATUS} = 2 -a ${THISRC} = ${__TRUE} ] ; then
#
# the phone is booted from the TWRP in the boot or recovery partition
#
    LogMsg "The phone is booted from a TWRP in the boot or recovery partition "

    if [ ${FORCE_BOOT_INTO_TWRP_IMAGE}x = ${__TRUE}x ] ; then
      LogMsg "Rebooting the phone from the TWRP image requested via parameter"
      BOOT_INTO_BOOTLOADER_USING_ADB=${__TRUE}
    fi
  fi      

# ---------------------------------------------------------------------

  if [ ${PHONE_STATUS} = 3 -a ${THISRC} = ${__TRUE} ] ; then

#
# the phone is booted into the Android OS
#
    LogMsg "The phone is booted into the Android OS "

    BOOT_INTO_BOOTLOADER_USING_ADB=${__TRUE}
  fi      

# ---------------------------------------------------------------------

  if [ ${PHONE_STATUS} = 7 -a ${THISRC} = ${__TRUE} ] ; then

#
# the phone is booted into non-TWRP recovery with adb access
#
    LogMsg "The phone is booted into the LineageOS recovery "

    BOOT_INTO_BOOTLOADER_USING_ADB=${__TRUE}
  fi      


# ---------------------------------------------------------------------

  if [ ${PHONE_STATUS} = 6 -a ${THISRC} = ${__TRUE} ] ; then
#
# the phone is booted into the safe mode of the Android OS
#
    LogMsg "The phone is booted into the safe mode of the Android OS "

    BOOT_INTO_BOOTLOADER_USING_ADB=${__TRUE}
  fi      

# ---------------------------------------------------------------------

  if [ ${PHONE_STATUS} = 8 -a ${THISRC} = ${__TRUE} ] ; then

#
# the phone is booted into the sideload mode
#
    LogMsg "The phone is booted into the sideload mode "

    BOOT_INTO_BOOTLOADER_USING_ADB=${__TRUE}
  fi      

# ---------------------------------------------------------------------

  if [ ${PHONE_STATUS} = 9 -a ${THISRC} = ${__TRUE} ] ; then

#
# the phone is booted into a recovery without adb shell
#
    LogMsg "The phone is booted into a recovery without adb shell "

    BOOT_INTO_BOOTLOADER_USING_ADB=${__TRUE}
  fi      

# ---------------------------------------------------------------------

  if [ ${BOOT_INTO_BOOTLOADER_USING_ADB} = ${__TRUE} -a ${THISRC} = ${__TRUE} ]; then

    LogMsg "Booting the phone into the bootloader now ..."

    ${ADB} ${ADB_OPTIONS} reboot bootloader

    wait_for_phone_to_be_in_the_bootloader 
    if [ $? -ne ${__TRUE} ] ; then
      LogError "Booting the phone into the bootloader failed"
      THISRC=${__FALSE}
      
      PHONE_STATUS=99
      
      PHONE_BOOT_ERROR=102
    else
      PHONE_STATUS=4
    fi
  fi

# ---------------------------------------------------------------------
  
  if [ ${PHONE_STATUS} = 5 -a ${THISRC} = ${__TRUE} ] ; then
#
# the phone is booted into the fastbootd
#  
    LogMsg "The phone is booted into the fastbootd "

    ${SUDO_PREFIX} ${TIMEOUT} ${FASTBOOT_TIMEOUT} ${FASTBOOT} ${FASTBOOT_OPTIONS} reboot bootloader

    wait_for_phone_to_be_in_the_bootloader 
    if [ $? -ne ${__TRUE} ] ; then
      LogError "Booting the phone into the bootloader failed"
      THISRC=${__FALSE}

      PHONE_STATUS=99

      PHONE_BOOT_ERROR=102
    else
      PHONE_STATUS=4  
    fi
  fi

# ---------------------------------------------------------------------

  if [ ${PHONE_STATUS} = 4 -a ${THISRC} = ${__TRUE} ] ; then
#
# the phone is booted into the bootloader
#  
    LogMsg "The phone is booted into the bootloader "

    if [ ${RESTART_BOOT_LOADER}x = ${__TRUE}x ] ; then
      LogMsg "Reloading the boot loader ..."
      ${SUDO_PREFIX} ${FASTBOOT} ${FASTBOOT_OPTIONS} reboot bootloader
    fi
    
    LogMsg "Booting the phone from the TWRP image \"${CUR_TWRP_IMAGE}\" now  ..."

    ${SUDO_PREFIX} ${FASTBOOT} ${FASTBOOT_OPTIONS} boot "${CUR_TWRP_IMAGE}"

    wait_for_phone_with_a_working_adb_connection 
    if [ $? -ne ${__TRUE} ] ; then
      LogError "Booting the phone from the TWRP image file \"${CUR_TWRP_IMAGE}\" failed"
      THISRC=${__FALSE}

      PHONE_STATUS=99

      PHONE_BOOT_ERROR=103
    fi

#
# wait until the boot is done
#
    if [ "${ADB_DAEMON_WAIT_TIME}"x != ""x -a  "${ADB_DAEMON_WAIT_TIME}"x != "0"x -a ${THISRC} = ${__TRUE} ] ; then
      wait_for_the_adb_daemon ${ADB_DAEMON_WAIT_TIME} 
      if [ $? -ne ${__TRUE} ] ; then
        LogError "Booting the phone from the TWRP image file \"${CUR_TWRP_IMAGE}\" failed"
        THISRC=${__FALSE}
      else
#
# the phone is now booted in the TWRP image
#
        PHONE_STATUS=1

# 
# decrypt the data partition if necessary
#
        decrypt_data || THISRC=${__FALSE}

      fi
    fi

  fi

# ---------------------------------------------------------------------

  if [ ${THISRC} = ${__TRUE} ] ; then
    if [ ${PHONE_STATUS} = 1  -o ${PHONE_STATUS} = 2 ] ; then

      TWRP_BOOT_IMAGE="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.product.bootimage.name )"
      TWRP_BOOT_IMAGE_VERSION="$( ${ADB} ${ADB_OPTIONS} shell getprop ro.twrp.version )"

      if [ "${TWRP_BOOT_IMAGE_VERSION}"x = ""x ] ; then
        LogWarning "Can not get the value of the property \"ro.twrp.version\" "
      fi

      if [ "${TWRP_BOOT_IMAGE}"x = ""x ] ; then
        LogWarning "Can not get the value of the property \"ro.product.bootimage.name \" "
      fi
    
      LogMsg "The phone is booted into TWRP: \"${TWRP_BOOT_IMAGE}\" version \"${TWRP_BOOT_IMAGE_VERSION}\" "
    fi
  fi

# ---------------------------------------------------------------------
  
  return ${THISTRC}
}


# ----------------------------------------------------------------------
# reboot_phone
#
# function: reboot the phone 
#
# Usage:  reboot_phone [wait|nowait] [force|noforce] [new_state] [wait_time_in_seconds] [nodecrypt]
#
# returns:  ${__TRUE}  - ok
#           ${__FALSE} - error
#
# new_state can be any known parameter for the reboot command from adb and fastboot and "Android" or "android" to 
# boot the phone into the installed Android OS.
#
# If the parameter "--nowait" is used the function reboots the phone into without checking the result.
# if the parameter "force" is used the function reboots the even if it's already booted into the requested state
# Without a parameter the phone will be booted into the Android OS installed in the current slot and 
# the function checks for a working adb connection after the reboot.
# When booting into the recovery or into the Android OS the function trys to decrypt the data partition.
# Use the parameter "nodecrypt" to disable the decryption.
#
# The boot method used depends on the value of the global variable PHONE_STATUS, the known values 
# for the variable PHONE_STATUS are:
#
#     1 - the phone is booted from the TWRP image
#     2 - the phone is booted from TWRP installed in the boot or recovery partition
#     3 - the phone is booted into normal mode
#     4 - the phone is booted into bootloader 
#     5 - the phone is booted into the fastbootd
#     6 - the phone is booted into the safe mode of the Android O
#     7 - the phone is booted into the a non-TWRP recovery installed in the boot or recovery partition
#     8 - the phone is booted into sideload
#     9 - the phone is booted into a recovery without working adb shell
#
function reboot_phone {
  typeset __FUNCTION="reboot_phone"
  ${__DEBUG_CODE}
  ${__FUNCTION_INIT}

 
  typeset THISRC=${__TRUE}

  typeset CONT=${__TRUE}
  
  typeset BOOT_TARGET=""
 
  typeset WAIT_FOR_THE_PHONE=${__TRUE}
  typeset FORCE_REBOOT=${__FALSE}
  typeset BOOT_THE_PHONE=${__TRUE}
  
  typeset CURRENT_STATE=""
  typeset NEW_PHONE_STATE=""
  typeset CUR_PARAMETER=""
  typeset BOOT_METHOD=""
  typeset i=0
  typeset CUR_BOOT_WAIT_TIME=""
  
  typeset DECRYPT_USER_DATA=${__FALSE}
  typeset DECRYPTION_DISABLED=${__FALSE}

  LogMsg "Parameter for the function \"${__FUNCTION}\" are: $*"

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
    while [ $# -ne 0 ] ; do
      CUR_PARAMETER="$1"
      shift
      
      case ${CUR_PARAMETER} in
        --nodecrypt | nodecrypt )
          DECRYPTION_DISABLED=${__TRUE}
          ;;
          
        --force | force )
          FORCE_REBOOT=${__TRUE}
          ;;
  
        --noforce | noforce )
          FORCE_REBOOT=${__FALSE}
          ;;
  
        --nowait | nowait )
          WAIT_FOR_THE_PHONE=${__FALSE}
          ;;
  
        --wait | wait )
          WAIT_FOR_THE_PHONE=${__TRUE}
          ;;
  
        Android | android | recovery | bootloader | sideload | fastboot | safemode )
          if [ "${BOOT_TARGET}"x = ""x ] ; then 
            BOOT_TARGET="$( echo "${CUR_PARAMETER}" | tr "[:upper:]" "[:lower:]" )"
  
          else
            LogError "${__FUNCTION}: Duplicate parameter found: \"${CUR_PARAMETER}\" "
            THISRC=100
          fi
          ;;
  
        * )
          isNumber ${CUR_PARAMETER} 
          if [ $? -eq 0 ] ; then
            CUR_BOOT_WAIT_TIME="${CUR_PARAMETER}"
          else
            LogError "${__FUNCTION}: Invalid parameter found: \"${CUR_PARAMETER}\" "
            THISRC=101
          fi
          ;;
  
       esac
    done
  fi


  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
#
# default boot target is the Android OS
#  
    if [ "${BOOT_TARGET}"x = ""x ] ; then
      BOOT_TARGET="android"
    fi

    if [ "${BOOT_TARGET}"x = "recovery"x  -o  "${BOOT_TARGET}"x = "android"x ] ; then
      DECRYPT_USER_DATA=${__TRUE}
    fi

# 
# get the current status of the phone
#    
    retrieve_phone_status

    LogMsg "The current phone status is \"${PHONE_STATUS}\" "
  
    case ${PHONE_STATUS} in
    
      1 )
        CURRENT_STATE="TWRP"
        BOOT_METHOD="adb"
        ;;
  
      2 )
        CURRENT_STATE="recovery"
        BOOT_METHOD="adb"
        ;;
    
      3 )
        CURRENT_STATE="android"
        BOOT_METHOD="adb"
        ;;
  
      4 )
        CURRENT_STATE="bootloader"
        BOOT_METHOD="fastboot"
        ;;
  
      5 )
        CURRENT_STATE="fastboot"
        BOOT_METHOD="fastboot"
        ;;
  
      6 )
        CURRENT_STATE="safemode"
        BOOT_METHOD="adb"
        ;;
  
      7 )
        CURRENT_STATE="recovery"
        BOOT_METHOD="adb"
        ;;
  
      8 )
        CURRENT_STATE="sideload"
        BOOT_METHOD="adb"
        ;;      
  
      9 )
        CURRENT_STATE="recovery"
        BOOT_METHOD="adb"
        ;;      
  
      * )
        CURRENT_STATE="unknown"
        BOOT_METHOD="unknown"
        ;;      
      
    esac
  
    LogMsg "Booting the phone using \"${BOOT_METHOD}\" "
   
    BOOT_THE_PHONE=${__TRUE}

    if [ "${CURRENT_STATE}"x = "${BOOT_TARGET}"x ] ; then
      LogMsg "The phone is already booted into the ${BOOT_TARGET}"
      if [ ${FORCE_REBOOT} = ${__TRUE} ] ; then
        LogMsg "A reboot is requested via parameter"
      else
        CONT=${__FALSE}
      fi
    fi
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
    
    case ${BOOT_TARGET} in 

      android )
        NEW_PHONE_STATE=" 3 6 "
        NEW_ACCESS_MODE="adb"
        BOOT_TARGET=""
        ;;

      recovery )
        NEW_PHONE_STATE=" 2 7 9 "
        NEW_ACCESS_MODE="adb"
        ;;

      bootloader )
        NEW_PHONE_STATE=4
        NEW_ACCESS_MODE="fastboot"
        ;;

      fastboot )
        NEW_PHONE_STATE=5
        NEW_ACCESS_MODE="fastboot"
        ;;

      sideload )
        NEW_PHONE_STATE=8
        NEW_ACCESS_MODE="fastboot"
        ;;

      safemode )
        NEW_PHONE_STATE=6
        NEW_ACCESS_MODE="adb"
        BOOT_TARGET=""
        ;;

    esac

    if [ "${NEW_PHONE_STATE}"x = "6"x ] ; then
      enable_safe_mode
      if  [ $? -ne ${__TRUE} ] ; then
        LogError "Booting the phone into the safe mode requires a running Android OS with root access"
        THISRC=113
      fi
    fi
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then

    if [ "${BOOT_METHOD}"x = "unknown"x ] ; then
       LogError "The current phone state  ${PHONE_STATUS} - there is no known boot method for this state"
       THISRC=114
    elif [ "${BOOT_METHOD}"x = "adb"x ] ; then
      if [ "${CUR_BOOT_WAIT_TIME}"x = ""x ] ; then
        CUR_BOOT_WAIT_TIME=${ADB_BOOT_WAIT_TIME:=60}
      fi
      LogMsg "Rebooting the phone using the command \" ${ADB} ${ADB_OPTIONS} reboot ${BOOT_TARGET}\" now ..."
      ${ADB} ${ADB_OPTIONS} reboot ${BOOT_TARGET}
    else
      if [ "${CUR_BOOT_WAIT_TIME}"x = ""x ] ; then
        CUR_BOOT_WAIT_TIME=${FASTBOOT_WAIT_TIME:=60}
      fi
      LogMsg "Rebooting the phone using the command \"${FASTBOOT} ${FASTBOOT_OPTIONS} reboot ${BOOT_TARGET}\" now ..."
      ${SUDO_PREFIX} ${TIMEOUT} ${FASTBOOT_TIMEOUT} ${FASTBOOT} ${FASTBOOT_OPTIONS} reboot ${BOOT_TARGET}
    fi
  fi

  if [ ${THISRC} = ${__TRUE} -a ${CONT} = ${__TRUE} ] ; then
    
    if [ ${WAIT_FOR_THE_PHONE} = ${__TRUE} ] ; then

      case ${NEW_ACCESS_MODE} in
        
        "adb" )
          wait_for_phone_with_a_working_adb_connection
          THISRC=$?
          ;;
        
        * )
          LogMsg "Waiting up to ${CUR_BOOT_WAIT_TIME} second(s) for the phone ..."

          THISRC=${__FALSE}
          i=0
           
          while [ $i -lt ${CUR_BOOT_WAIT_TIME} ] ; do
            printf "."
            (( i = i + 5 ))
            sleep 5
            retrieve_phone_status ${__FALSE}

            if [[ " ${NEW_PHONE_STATE} " == *\ ${PHONE_STATUS}\ * ]] ; then
              THISRC=${__TRUE} 
              break
            fi
          done
          printf "\n"

          if [ ${THISRC} != ${__TRUE} ] ; then
            LogError "Booting the phone into the ${BOOT_TARGET:=Android OS} failed; current status is ${PHONE_STATUS}"
          else
            LogMsg "Booting the phone into the ${BOOT_TARGET:=Android OS} succeeded after ${i} seconds; the current status of the phone is ${PHONE_STATUS}"

            if [ ${DECRYPT_USER_DATA} = ${__TRUE} -a ${DECRYPTION_DISABLED} != ${__TRUE} ] ; then
# 
# decrypt the data partition if necessary
#
              decrypt_data      
            fi      
          fi
          ;;
       esac
    fi
  fi
  
  return ${THISRC}
}

# ---------------------------------------------------------------------
# main function
#

# only process the parameter if running as standalone script
#
if [ ${RUNNING_AS_STANDALONE_SCRIPT} = ${__TRUE} ] ; then

# execute the init code of this script
#  
  EXECUTE_BOOT_PHONE_FROM_TWRP_INIT=${__TRUE}
  
  TWRP_IMAGE_IN_ENVIRONMENT="${TWRP_IMAGE}"

  TWRP_IMAGE_IN_PARAMETER=""

  BOOT_TARGET=""

# parameter that must be forwared to the function reboot_phone
# 
  PARAMETER_FOR_REBOOT_PHONE=""


#
# process the parameter of the script
#
  
  while [ $# -ne 0 ] ; do
  
    CUR_PARAMETER="$1"
    shift
    LogInfo "Processing the parameter \"${CUR_PARAMETER}\" ..."

    case ${CUR_PARAMETER} in

      -h )
        ${EGREP} "^#h#" $0 | cut -c4-
        boot_phone_from_twrp_die 110
        ;;

      -H | --help | help )
#
# extract the usage help from the script source
#
        ${EGREP} -i "^#H#" $0 | cut -c4-

        LogMsg ""
        LogMsg " The default TWRP image to use is \"${DEFAULT_TWRP_IMAGE}\" "
        LogMsg ""
        boot_phone_from_twrp_die 110
        ;;

      usb_reset | reset_usb )
        RESET_THE_USB_PORT=${__TRUE}
        ;;   


      restart_bootloader )
        RESTART_BOOT_LOADER=${__TRUE}
        ;;

      no_usb_reset | no_reset_usb )
        RESET_THE_USB_PORT=${__FALSE}
        ;;   
    
      decrypt )
        DECRYPT_ONLY=${__TRUE}
        ;;

      twrp | TWRP )
        BOOT_TARGET=""
        ;;

      --nodecrypt | nodecrypt )
        DECRYPTION_DISABLED=${__TRUE}

        PARAMETER_FOR_REBOOT_PHONE="${PARAMETER_FOR_REBOOT_PHONE} ${CUR_PARAMETER}"
        ;;

      Android | android| Recovery | recovery | bootloader | sideload | fastboot | safemode )
        BOOT_TARGET="${CUR_PARAMETER}"
        ;;

      serial=* | s=* | --serial=* | -s=# )
        SERIAL_NUMBER="${CUR_PARAMETER##*=}"
        ;;
        
      -s | --serial )
        if [ $# -ge 1 ] ; then
          shift
          SERIAL_NUMBER=$1
          shift
        else
          boot_phone_from_twrp_die 105 "ERROR: Missing value for the parameter \"$1\"  "
        fi
        ;;

      wait=* | --wait=* )
        ADB_DAEMON_WAIT_TIME="${CUR_PARAMETER#*=}"
        ;;

      password=* | --password=* )
        USER_PASSWORD="${CUR_PARAMETER#*=}"
        ;;
  
      force | --force )
        FORCE_BOOT_INTO_TWRP_IMAGE=${__TRUE}

        PARAMETER_FOR_REBOOT_PHONE="${PARAMETER_FOR_REBOOT_PHONE} ${CUR_PARAMETER}"
        ;;
  
      noforce  | --noforce )
        FORCE_BOOT_INTO_TWRP_IMAGE=${__FALSE}

        PARAMETER_FOR_REBOOT_PHONE="${PARAMETER_FOR_REBOOT_PHONE} ${CUR_PARAMETER}"
        ;;
  
      reboot | --reboot )
        FORCE_REBOOT_INTO_TWRP_IMAGE=${__TRUE}

        PARAMETER_FOR_REBOOT_PHONE="${PARAMETER_FOR_REBOOT_PHONE} ${CUR_PARAMETER}"
        ;;
  
      noreboot | --norebot )
        FORCE_REBOOT_INTO_TWRP_IMAGE=${__FALSE}

        PARAMETER_FOR_REBOOT_PHONE="${PARAMETER_FOR_REBOOT_PHONE} ${CUR_PARAMETER}"
        ;;
  
      checkonly | --checkonly | check | --check )
         CHECK_ONLY=${__TRUE}
         ;;
  
      nocheckonly  | --nocheckonly )
         CHECK_ONLY=${__FALSE}
         ;;

      status )
         CHECK_ONLY=${__TRUE}
         PRINT_STATUS=${__TRUE}
         ;;
  
      nostatus | --nostatus )
         CHECK_ONLY=${__FALSE}
         PRINT_STATUS=${__FALSE}
         ;;
      reset_usb_only )
         ONLY_RESET_THE_USB_PORT=${__TRUE}
         ;;

      * )
        if [ "${TWRP_IMAGE_IN_PARAMETER}"x != ""x ] ; then
          boot_phone_from_twrp_die 100 "Unknown parameter found: \"${CUR_PARAMETER}\" "
        fi
        TWRP_IMAGE_IN_PARAMETER="${CUR_PARAMETER}"
        ;;
  
    esac
  done  

  [ $# -ne 0 ] && boot_phone_from_twrp_die 100 "Unknown parameter found: \"$*\" "


  LogMsg "${SCRIPT_NAME} ${SCRIPT_VERSION} - boot a phone from a TWRP image"
  LogMsg ""

fi

# ---------------------------------------------------------------------
# The next code is executed if running as standalone script or as include script
#

if [ "${EXECUTE_BOOT_PHONE_FROM_TWRP_INIT}"x != "${__FALSE}"x ] ; then

#
# with correct udev rules fastboot must be executed by the user root -> use sudo if the script is executed by a non-root user
# (This is only necessary if the udev rules are incomplete)
#
  if [ "${SUDO_PREFIX}"x = "none"x ] ; then
    LogMsg "The usage of sudo is disabled (SUDO_PREFIX is none)"
    SUDO_PREFIX=""
  elif [ "${SUDO_PREFIX}"x = ""x ] ; then
    CUR_USER="$( whoami )"
    if [ "${CUR_USER}"x != "root"x ] ; then
      SUDO_PREFIX="sudo"
      LogMsg "The script is running as user \"${CUR_USER}\" -- using \"${SUDO_PREFIX}\" for the fastboot commands ..."
    else
      SUDO_PREFIX=""
    fi
  fi

  set_serial_number
  
  get_usb_device_for_the_phone 

  if [ ${RESET_THE_USB_PORT} = ${__TRUE} ] ; then
    if [ "${SERIAL_NUMBER}"x = ""x ] ; then
      reset_the_usb_port_for_the_phone
    else
      LogMsg "The phone is available via adb - no reset of the USB port necessary"
    fi
  fi

  set_serial_number || boot_phone_from_twrp_die 109 "Too many phones connected"

  init_global_vars_for_boot_phone_from_twrp || boot_phone_from_twrp_die 111 "Error intializing the variables"
  
  check_prereqs_for_boot_phone_from_twrp || boot_phone_from_twrp_die 112 "One or more errors in the prereq found"
      
  retrieve_phone_status
  
  print_phone_status
  
  if [ ${NO_TWRP_IMAGE_AUTO_SELECT} != ${__TRUE} -a "${TEMP_TWRP_IMAGE_TO_USE}"x != ""x ] ; then
    TWRP_IMAGE="${TEMP_TWRP_IMAGE_TO_USE}"
  fi

# check the TWRP image file contents
#
  if [ "${TWRP_IMAGE}"x != ""x ] ; then
    check_android_boot_image "${TWRP_IMAGE}" || \
      boot_phone_from_twrp_die 101 "The file \"${TWRP_IMAGE}\" is not a valid boot image"
  fi

fi

# ---------------------------------------------------------------------
# process the parameter that are not used for reboot_phone
#

# ---------------------------------------------------------------------
#

if [ ${DECRYPT_ONLY} = ${__TRUE} ] ; then
  if [[ " 1 2 3 6 " != *\ ${PHONE_STATUS}\ * ]] ; then
    boot_phone_from_twrp_die 105 "Decrypting the data partition is only possible if the phone is booted from TWRP or booted into the Android OS"
  else
    decrypt_data
  fi

# ---------------------------------------------------------------------
#
elif [ ${CHECK_ONLY} = ${__TRUE} ] ; then
  boot_phone_from_twrp_die ${PHONE_STATUS}

# ---------------------------------------------------------------------
#
elif [ ${ONLY_RESET_THE_USB_PORT} = ${__TRUE} ] ; then
  reset_the_usb_port_for_the_phone
  boot_phone_from_twrp_die $?

# ---------------------------------------------------------------------
#
elif [ ${RUNNING_AS_STANDALONE_SCRIPT} = ${__TRUE} ] ; then

  if [ "${BOOT_TARGET}"x != ""x ] ; then

# ---------------------------------------------------------------------
#
# boot into one of the known modes for the phone
#
    reboot_phone ${BOOT_TARGET} ${PARAMETER_FOR_REBOOT_PHONE} 
    if [ $? -ne ${__TRUE} ]; then
      boot_phone_from_twrp_die 108 "Booting the phone into the requested mode failed"
    fi
    
  else

# ---------------------------------------------------------------------
#
# boot from a TWRP image
#
    boot_phone_from_the_TWRP_image "${CUR_TWRP_IMAGE}"
    if [ $? -ne ${__TRUE} ]; then
      boot_phone_from_twrp_die 103 "Booting the phone from the TWRP image failed"
    fi

  fi
else

  if [ "${EXECUTE_BOOT_PHONE_FROM_TWRP_INIT}"x != "${__FALSE}"x ] ; then

    if [ ${PRINT_STATUS} = ${__TRUE} ] ; then
      print_phone_status
    fi

    boot_phone_from_twrp_die ${PHONE_STATUS}
  fi

fi

boot_phone_from_twrp_die 0

