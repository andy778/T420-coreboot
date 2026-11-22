#!/bin/sh
# Runs as `builder`. UEFI (EDK2) variant: downloads + verifies the Libreboot ROM
# tarball, injects the neutered ME and onboard NIC MAC. No VBIOS patching (EDK2
# uses libgfxinit/corebootfb). Result is copied to /output.
set -eu
LBMK=/home/builder/lbmk
TARBALL="libreboot-${RELEASE}_${BOARD}.tar.xz"
ROMDIR="${MIRROR}/${RELEASE}/roms"
echo ">> Release=${RELEASE} board=${BOARD} variant=${VARIANT} mac=${MAC}"
cd "${LBMK}"
git config --global user.name "builder"
git config --global user.email "builder@localhost"
wget -q -O /tmp/lbkey.asc https://libreboot.org/lbkey.asc
gpg --import /tmp/lbkey.asc
wget -q "${ROMDIR}/${TARBALL}" "${ROMDIR}/${TARBALL}.sha256" "${ROMDIR}/${TARBALL}.sig"
sha256sum -c "${TARBALL}.sha256"
gpg --verify "${TARBALL}.sig" "${TARBALL}"
rm -f lock
./mk inject "${TARBALL}" setmac "${MAC}"
mkdir -p work && tar -xf "${TARBALL}" -C work
ROM=$(find work -type f -name "*${VARIANT}.rom" ! -name 'DO_NOT*' | head -n1)
[ -n "${ROM}" ] || { echo "ERROR: injected ROM not found"; find work -type f; exit 1; }
cp "${ROM}" "/output/${VARIANT}.rom"
echo ">> Final CBFS:"
cbfstool "/output/${VARIANT}.rom" print
echo ">> ROM written to /output/${VARIANT}.rom"
