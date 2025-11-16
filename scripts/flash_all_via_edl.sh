#!/usr/bin/bash
# 
# flash_all_via_edl.sh - simple script to flash all partitions on an ASUS Zenfone 8 with the image file from a raw image for the phone 
#                        using the edl script from this repository https://github.com/bkerler/edl
#                     
#
# Usage: flash_all_via_edl.sh [reboot|noreboot] [noask]
#
# History
#   15.11.2025 v1.0.0 /bs
#     initial release
#
# Note:
#   All directories used are hardcoded in the script!
#   The script uses the firehose loader from the raw image
#
#   Use the command
#
#   PREFIX=echo flash_all_via_edl.sh
#
#   to only print the commands to flash the partitions
#

# base directory with the raw image
#
IMAGE_DIR="/data/backup/ASUS_ZENFONE8/raw_images/Android13/OPEN-ZS590KS-32.0501.0403.4-BSP-2206-user-20220705"

# directory with the firmware images (normally a sub directory in the directory with the raw image)
#
FIRMWARE_DIR="${IMAGE_DIR}/firmware"

# Firehose loader to use
FIREHOSE_LOADER="${FIRMWARE_DIR}/prog_firehose_ddr.elf"

# edl executable
#
EDL="$( which edl )"
EDL="${EDL:=./edl}"

# ------------------------------------------------------
#
function _edl {
   ${PREFIX} ${EDL} --loader="${FIREHOSE_LOADER}" $*
}

# ------------------------------------------------------

NOASK=""

while [ $# -ne 0 ] ; do
  CUR_PARAMETER="$1"
  shift

  case ${CUR_PARAMETER} in

    -h | --help | help )	
      echo "$0 - flash all partitions on an ASUS Zenfone 8 using edl"
      echo "Usage: $0 [reboot|noreboot] [noask]"
      exit 0
      ;;

    "noask" )
      NOASK="noask"
      ;;

    "reboot" )
      SKIPREBOOT="reboot"
      ;;
 
    "noreboot" )
      SKIPREBOOT="noreboot"
      ;;

    * )
     echo "ERROR: Unknown parameter found: \"${CUR_PARAMETER}\" "
     exit 100
     ;;
  esac
done

# ------------------------------------------------------

echo "Flashing the phone connected via USB using edl ..."



echo
echo "Using the edl executable \"${EDL}\" "
echo "Using the firehose loader \"${FIREHOSE_LOADER}\" "
echo "Using the partition images from the directory \"${IMAGE_DIR}\" "
echo "Using the firmware partition images from the directory \"${FIRMWARE_DIR}\" "
echo

if [ ! -x ${EDL} ] ; then
  echo "ERROR: edl executable not found!"
  exit 3
fi

if [ ! -r "${FIREHOSE_LOADER}" ] ; then
  echo "ERROR: The firehose loader \"${FIREHOSE_LOADER}\" does not exist"
  exit 4
fi

if [ ! -d "${IMAGE_DIR}" ] ; then
  echo "ERROR: The directory \"${IMAGE_DIR}\" does not exist"
  exit 5
fi

if [ "${IMAGE_DIR}"x != "${FIRMWARE_DIR}"x ] ; then
  if [  ! -d "${FIRMWARE_DIR}" ] ; then
    echo "ERROR: The directory \"${IMAGE_DIR}\" does not exist"
    exit 6
  fi
fi

if [ "${NOASK}"x != "noask"x ] ; then
  echo
  echo "Press return to start restoring the partitions "
  read USER_INPUT
fi


# =================== erase: misc ======================

_edl e misc

# ====================== flash: abl ====================

_edl w abl_a ${IMAGE_DIR}/abl.elf

_edl w abl_a ${IMAGE_DIR}/abl.elf


# sudo $FASTBOOT reboot-bootloader

# ============== add for fac flash fail ================
# _edl w multiimgoem_a  ${FIRMWARE_DIR}/multi_image.mbn 

# _edl w multiimgoem_b  ${FIRMWARE_DIR}/multi_image.mbn 


# ==================== partition_0 =====================
# sudo $FASTBOOT flash partition:0 gpt_both0.bin
# failure_prompt $? partition:0

# ==================== partition_1 =====================
# sudo $FASTBOOT flash partition:1 gpt_both1.bin
# failure_prompt $? partition:1

# ==================== partition_2 =====================
# sudo $FASTBOOT flash partition:2 gpt_both2.bin
# failure_prompt $? partition:2


# ==================== partition_3 =====================
# sudo $FASTBOOT flash partition:3 gpt_both3.bin
# failure_prompt $? partition:3


# ==================== partition_4 =====================
# sudo $FASTBOOT flash partition:4 gpt_both4.bin
# failure_prompt $? partition:4


# ==================== partition_5 =====================
# sudo $FASTBOOT flash partition:5 gpt_both5.bin
# failure_prompt $? partition:5


# ==================== partition_6 =====================
# sudo $FASTBOOT flash partition:6 gpt_both6.bin
# failure_prompt $? partition:6

# ================ flash: multiimgoem ==================

_edl w multiimgoem_a  ${FIRMWARE_DIR}/multi_image.mbn 
_edl w multiimgoem_b  ${FIRMWARE_DIR}/multi_image.mbn 

# =============== flash: xbl & xbl_config===============

_edl w xbl_a  ${FIRMWARE_DIR}/xbl.elf

_edl w xbl_b  ${FIRMWARE_DIR}/xbl.elf

_edl w xbl_config_a  ${FIRMWARE_DIR}/xbl_config.elf

_edl w xbl_config_b  ${FIRMWARE_DIR}/xbl_config.elf


# =================== flash: shrm ======================

_edl w shrm_a  ${FIRMWARE_DIR}/shrm.elf

_edl w shrm_b  ${FIRMWARE_DIR}/shrm.elf

# ====================== flash: abl ====================

_edl w abl_a ${IMAGE_DIR}/abl.elf

_edl w abl_b ${IMAGE_DIR}/abl.elf

# ==================== flash: aop ======================

_edl w aop_a  ${FIRMWARE_DIR}/aop.mbn

_edl w aop_b  ${FIRMWARE_DIR}/aop.mbn

# ==================== flash: TZ =======================

_edl w tz_a  ${FIRMWARE_DIR}/tz.mbn

_edl w tz_b  ${FIRMWARE_DIR}/tz.mbn

# ==================== flash: hyp ======================

_edl w hyp_a  ${FIRMWARE_DIR}/hypvm.mbn 

_edl w hyp_b  ${FIRMWARE_DIR}/hypvm.mbn 

# ================== flash: Modem ======================

_edl w modem_a  ${FIRMWARE_DIR}/NON-HLOS.bin

_edl w modem_b  ${FIRMWARE_DIR}/NON-HLOS.bin


# ================ flash: bluetooth ====================

_edl w bluetooth_a  ${FIRMWARE_DIR}/BTFM.bin

_edl w bluetooth_b  ${FIRMWARE_DIR}/BTFM.bin

# ===================== flash: dsp =====================

_edl w dsp_a ${FIRMWARE_DIR}/dspso.bin

_edl w dsp_b ${FIRMWARE_DIR}/dspso.bin


# ================= flash: keymaster ===================

_edl w keymaster_a  ${FIRMWARE_DIR}/km41.mbn 

_edl w keymaster_b  ${FIRMWARE_DIR}/km41.mbn 

# =================== flash: rtice =====================

 _edl w rtice ${FIRMWARE_DIR}/rtice.mbn

# ================== flash: storsec ====================

_edl w storsec ${FIRMWARE_DIR}/storsec.mbn

# =================== erase: misc ======================

_edl e misc

# =================== erase: ssd =======================
#erase_partition ssd
# _edl e ssd

# ================= erase: keystore ====================
#erase_partition keystore
# _edl e keystore

# ================ flash: apdp & spunvm ================
#flash_image apdp apdp.mbn
#flash_image	spunvm firmware/spunvm.bin

_edl e spunvm

# ================ flash: qweslicstore =================

_edl w qweslicstore_a  ${FIRMWARE_DIR}/qweslicstore.bin

_edl w qweslicstore_b  ${FIRMWARE_DIR}/qweslicstore.bin

# ================== flash: batinfo ====================
#flash_image	batinfo batinfo.img

# ================== flash: devcfg =====================

_edl w devcfg_a ${FIRMWARE_DIR}/devcfg.mbn 

_edl w devcfg_b ${FIRMWARE_DIR}/devcfg.mbn 

# ============= flash: cmnlib & cmnlib64 ===============
#flash_image cmnlib_a firmware/cmnlib.mbn
#flash_image cmnlib_b firmware/cmnlib.mbn

# _edl w cmnlib_a ${FIRMWARE_DIR}/cmnlib.mbn

# _edl w cmnlib_b ${FIRMWARE_DIR}/cmnlib.mbn

#flash_image cmnlib64_a firmware/cmnlib64.mbn
#flash_image cmnlib64_b firmware/cmnlib64.mbn

# _edl w cmnlib64_a ${FIRMWARE_DIR}/cmnlib64.mbn

# _edl w cmnlib64_a ${FIRMWARE_DIR}/cmnlib64.mbn

# ==================== flash: qupfw ====================

_edl w qupfw_a ${FIRMWARE_DIR}/qupv3fw.elf

_edl w qupfw_b ${FIRMWARE_DIR}/qupv3fw.elf

# ==================== flash: qupfw ====================

_edl w cpucp_a ${FIRMWARE_DIR}/cpucp.elf

_edl w cpucp_b ${FIRMWARE_DIR}/cpucp.elf

# ==================== flash: logfs ====================

_edl w logfs  ${FIRMWARE_DIR}/logfs_ufs_8mb.bin

# ================= flash: uefisecapp ==================

_edl w uefisecapp_a  ${FIRMWARE_DIR}/uefi_sec.mbn

_edl w uefisecapp_b  ${FIRMWARE_DIR}/uefi_sec.mbn

# ================ flash: featenabler ==================

_edl w featenabler_a  ${FIRMWARE_DIR}/featenabler.mbn

_edl w featenabler_b  ${FIRMWARE_DIR}/featenabler.mbn

# =================== flash: imagefv ===================

_edl w imagefv_a  ${FIRMWARE_DIR}/imagefv.elf

_edl w imagefv_b  ${FIRMWARE_DIR}/imagefv.elf

# ==================== flash: vbmeta ===================
#flash_image persist persist.img

# _edl w persist  ${IMAGE_DIR}/persist.img 


# ===================== flash: ADF =====================
if [ -e ${IMAGE_DIR}/ADF.img ]; then

_edl w ADF  ${IMAGE_DIR}/ADF.img

fi

# ==================== flash: vbmeta ===================

_edl w vbmeta_a  ${IMAGE_DIR}/vbmeta.img

_edl w vbmeta_b  ${IMAGE_DIR}/vbmeta.img

# =============== flash: vbmeta_system =================

_edl w vbmeta_system_a  ${IMAGE_DIR}/vbmeta_system.img 

_edl w vbmeta_system_b  ${IMAGE_DIR}/vbmeta_system.img 

# ==================== flash: boot =====================


_edl w boot_a ${IMAGE_DIR}/boot.img

_edl w boot_b ${IMAGE_DIR}/boot.img

# ================= flash: vendor_boot =================

_edl w vendor_boot_a ${IMAGE_DIR}/vendor_boot.img

_edl w vendor_boot_b ${IMAGE_DIR}/vendor_boot.img

# ==================== flash: dtbo =====================

_edl w dtbo_a ${IMAGE_DIR}/dtbo.img

_edl w dtbo_b ${IMAGE_DIR}/dtbo.img


# =================== flash: XROM ======================
if [ -e ${IMAGE_DIR}/ASUS-xrom.img ]; then
  _edl w xrom_a ${IMAGE_DIR}/ASUS-xrom.img

  _edl w xrom_b ${IMAGE_DIR}/ASUS-xrom.img
fi

# ==================== flash: asdf =====================

_edl e asdf

_edl w asdf ${IMAGE_DIR}/asdf_384M.img

# =================== flash: super =====================

# erase_partition super
# flash_image super super.img

# _edl e super
# _edl w super ${IMAGE_DIR}/super.img


# =================== erase: data ======================

# sudo $FASTBOOT -w
# _edl e data

# ==================== reset active ====================

# ====================== finished ======================
if [ "$SKIPREBOOT" == "noreboot" ]; then
	echo =======================
	echo  "Download Complete !"
	echo =======================
elif [ "$SKIPREBOOT" == "reboot" ]; then
	echo =======================
	echo "Rebooting the phone now ..."
	_edl reset
else
	echo =======================
	echo  "Download Complete !"
	echo =======================
	echo Press any key to continue, system will reboot.
	read
    _edl reset
fi


