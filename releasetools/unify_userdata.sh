#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
#           (C) 2017 The LineageOS Project
#

# Inherit resize_userdata.zip
$(dirname ${0%.sh})/resize_userdata.sh ${1};
if [ ${?} -ne 0 ]; then
  exit 1;
fi;

# Device name
device="${1#*_}";
if [ -z "${device}" ]; then
  device='mint';
fi;

# Device variables
path=$(cd ${0%/*} && pwd -P);
name=$(basename ${0%.sh});
input=${path}/${name};
reporoot=${path%%/device*};
repoout=${reporoot}/out;
out="${repoout}/target/product/${device}";
targetdir="${out}/${name}_temp";
targetzip="${out}/${name}-$(date +%Y%m%d).zip";
targettmpzip="${targetzip}.unsigned.zip";
binary_updater="${out}/obj/EXECUTABLES/updater_intermediates/updater";
binary_files="${out}/recovery/root/sbin/sgdisk ${out}/utilities/toybox";
script_files="${out}/resize_userdata.zip";

# Host OS detection
case $(uname -s) in
  Darwin)
    host_os='darwin';;
  *)
    host_os='linux';;
esac;

# Script introduction
echo '';
echo '';
echo "++++ ${name} ++++";
echo '';

# Verify if output files exist
for file in ${binary_files} ${binary_updater} ${script_files}; do
  if [ ! -f ${file} ]; then
    echo " Full '${device}' build required for the package (${file#${out}/} not found)";
    echo '';
    exit 1;
  fi;
done;

# Delete output file and dir if exist
rm -rf ${targetdir};
rm -f ${targettmpzip};
rm -f ${targetzip};

# Create a temporary work folder
mkdir "${targetdir}";
mkdir -p "${targetdir}/install/bin";
mkdir -p "${targetdir}/install/${name}";
mkdir -p "${targetdir}/META-INF/com/google/android";
cd ${targetdir};

# Copy the output files
cp ${input}/updater-script ./META-INF/com/google/android/;
cp ${binary_updater} ./META-INF/com/google/android/update-binary;
cp ${input}/*.sh ./install/${name}/;
for file in ${binary_files}; do
  cp ${file} ./install/bin/;
done;
for file in ${script_files}; do
  cp ${file} ./install/${name}/;
done;

# Package the zip output
zip ${targettmpzip} * -r;

# Find signapk.jar dependencies
host_conscrypt_jni=$(ls -1 ${reporoot}/prebuilts/sdk/tools/${host_os}/lib64/libconscrypt_openjdk_jni* \
                   | head -n 1);
if [ -z "${host_conscrypt_jni}" ]; then
  echo '';
  echo -e "\e[0;33mPackage ${name}:\e[0m Missing libconscrypt_openjdk_jni dependency";
  echo '';
  exit 1;
fi;

# Sign the zip output
java -Djava.library.path="${LD_LIBRARY_PATH}:${host_conscrypt_jni%/*}" \
     -jar ${reporoot}/prebuilts/sdk/tools/lib/signapk.jar \
     -w ${reporoot}/build/target/product/security/testkey.x509.pem \
     ${reporoot}/build/target/product/security/testkey.pk8 \
     ${targettmpzip} \
     ${targetzip};

# Restore the original path
cd ${path};

# Delete the temporary work folder and zip output
rm -rf ${targetdir};
rm -f ${targettmpzip};

# Result flashable zip
echo '';
echo -e "\e[0;33mPackage ${name}:\e[0m ${targetzip}";
echo '';
