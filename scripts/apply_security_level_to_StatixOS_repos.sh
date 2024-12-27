#!/bin/ksh
#
# apply_security_level_to_StatixOS_repos.sh - apply a Android Security Patch to the local repositories for the StatixOS
#
# History
#   12.08.2024 v1.0.0 /bs 
#     initial release
#
# the list of Build Tags for the various Android Security Patches is available here:
#
#  https://source.android.com/docs/setup/reference/build-numbers#source-code-tags-and-builds
#
if [ "$1"x = "-h"x -o "$1"x = "--help"x -o $# -ne 1 ] ; then
  echo "Usage: $0 new_branch "
  echo "       see https://source.android.com/docs/setup/reference/build-numbers#source-code-tags-and-builds for the available branches"
  exit 1
fi

NEW_BRANCH="$1"

if [ ! -r .repo/manifests/default.xml ] ; then
  echo "The script must be executedd in the top level of a StatixOS repo"
  exit 5
fi

REPO_DIR="${PWD}"

echo "Applying the Security Level \"${NEW_BRANCH}\" ..."

if [[ ${NEW_BRANCH} == android-* ]] ; then
  NEW_BRANCH="${NEW_BRANCH#*-}"
fi

echo ""
echo "Correcting the file \".repo/manifests/default.xml\" ..."

${PREFIX} sed -i -e "s/android-14.0.0_r[0-9][0-9]/android-${NEW_BRANCH}/g"  .repo/manifests/default.xml
echo "The config is now:"
 grep  "${NEW_BRANCH%_*}"  .repo/manifests/default.xml

echo ""
echo "Applying the patches to the AOSP repositories ..."
${PREFIX} time python vendor/statix/scripts/merge-aosp.py  ${NEW_BRANCH}

echo ""
echo "Updating the repo \"build/release\" ..."

${PREFIX} cd build/release && ${PREFIX} git pull aosp  android-${NEW_BRANCH}


cd "${REPO_DIR}"

echo ""
echo "The current security patch of the files in the repo is now:"
echo ""
print_security_patch

    
