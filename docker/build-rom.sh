#!/bin/sh
# Runs as `builder`. Downloads + verifies the Libreboot ROM tarball, injects the
# neutered ME and onboard NIC MAC, then patches the chosen variant with the real
# Intel VBIOS (and removes SeaVGABIOS). Result is copied to /output.
set -eu

LBMK=/home/builder/lbmk
TARBALL="libreboot-${RELEASE}_${BOARD}.tar.xz"
UTIL="libreboot-${RELEASE}_util.tar.xz"
ROMDIR="${MIRROR}/${RELEASE}/roms"
UTILDIR="${MIRROR}/${RELEASE}"

echo ">> Release=${RELEASE} board=${BOARD} variant=${VARIANT} mac=${MAC}"

cd "${LBMK}"

# 1. Import the Libreboot signing key (idempotent).
wget -q -O /tmp/lbkey.asc https://libreboot.org/lbkey.asc
gpg --import /tmp/lbkey.asc

# 2. Download ROM tarball + checksum + signature and verify both.
echo ">> Downloading ${TARBALL}"
wget -q "${ROMDIR}/${TARBALL}" "${ROMDIR}/${TARBALL}.sha512" "${ROMDIR}/${TARBALL}.sig"
sha512sum -c "${TARBALL}.sha512"
gpg --verify "${TARBALL}.sig" "${TARBALL}"

# 3. Download the util tarball (ships a prebuilt cbfstool) and verify it too.
echo ">> Downloading ${UTIL}"
wget -q "${UTILDIR}/${UTIL}" "${UTILDIR}/${UTIL}.sha512" "${UTILDIR}/${UTIL}.sig"
sha512sum -c "${UTIL}.sha512"
gpg --verify "${UTIL}.sig" "${UTIL}"

# 4. Inject neutered ME (downloaded + me_cleaner'd by lbmk) and the NIC MAC.
#    This modifies the ROM tarball in place.
echo ">> Injecting ME + MAC"
rm -f lock
./mk inject "${TARBALL}" setmac "${MAC}"

# 5. Unpack both tarballs.
mkdir -p work && tar -xf "${TARBALL}" -C work
tar -xf "${UTIL}" -C work

ROM=$(find work -type f -path "*/${BOARD}/${VARIANT}.rom" | head -n1)
[ -n "${ROM}" ] || { echo "ERROR: variant ${VARIANT}.rom not found in tarball"; exit 1; }

CBFSTOOL=$(find work -type f -name cbfstool -perm -u+x | grep -E '(x86_64|amd64)' | head -n1)
[ -n "${CBFSTOOL}" ] || CBFSTOOL=$(find work -type f -name cbfstool -perm -u+x | head -n1)
[ -n "${CBFSTOOL}" ] || { echo "ERROR: cbfstool not found in util tarball"; exit 1; }
echo ">> Using cbfstool: ${CBFSTOOL}"

# 6. Patch: add the real Intel VBIOS for both possible iGPUs, drop the emulated
#    SeaVGABIOS shim so they can't fight over INT 10h. This is what makes
#    Windows boot and stops the Linux boot-time colour flicker on txtmode.
OUT="/output/${VARIANT}_vgabios.rom"
cp "${ROM}" "${OUT}"
"${CBFSTOOL}" "${OUT}" add -f /home/builder/vgabios.bin -n "pci8086,0166.rom" -t optionrom
"${CBFSTOOL}" "${OUT}" add -f /home/builder/vgabios.bin -n "pci8086,0126.rom" -t optionrom
"${CBFSTOOL}" "${OUT}" remove -n vgaroms/seavgabios.bin 2>/dev/null || true

echo ">> Done. Final CBFS:"
"${CBFSTOOL}" "${OUT}" print
echo ">> ROM written to ${OUT}"
