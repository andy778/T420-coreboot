#!/bin/sh
# Runs as `builder`. Downloads + verifies the Libreboot ROM tarball, injects the
# neutered ME and onboard NIC MAC, then patches the chosen variant with the real
# Intel VBIOS (and removes SeaVGABIOS). Result is copied to /output.
set -eu

LBMK=/home/builder/lbmk
TARBALL="libreboot-${RELEASE}_${BOARD}.tar.xz"
ROMDIR="${MIRROR}/${RELEASE}/roms"

echo ">> Release=${RELEASE} board=${BOARD} variant=${VARIANT} mac=${MAC}"

cd "${LBMK}"

# lbmk's own sanity check literally runs `git config --global user.name`,
# which only reads ~/.gitconfig -- it ignores --system config, so this has
# to be set for this user specifically (not at image-build time as root).
git config --global user.name "builder"
git config --global user.email "builder@localhost"

# 1. Import the Libreboot signing key (idempotent).
wget -q -O /tmp/lbkey.asc https://libreboot.org/lbkey.asc
gpg --import /tmp/lbkey.asc

# 2. Download ROM tarball + checksum + signature and verify both.
echo ">> Downloading ${TARBALL}"
wget -q "${ROMDIR}/${TARBALL}" "${ROMDIR}/${TARBALL}.sha512" "${ROMDIR}/${TARBALL}.sig"
sha512sum -c "${TARBALL}.sha512"
gpg --verify "${TARBALL}.sig" "${TARBALL}"

# 3. Inject neutered ME (downloaded + me_cleaner'd by lbmk) and the NIC MAC.
#    This modifies the ROM tarball in place.
echo ">> Injecting ME + MAC"
rm -f lock
./mk inject "${TARBALL}" setmac "${MAC}"

# 4. Unpack.
mkdir -p work && tar -xf "${TARBALL}" -C work

ROM=$(find work -type f -path "*/${BOARD}/${VARIANT}.rom" | head -n1)
[ -n "${ROM}" ] || { echo "ERROR: variant ${VARIANT}.rom not found in tarball"; exit 1; }

# cbfstool comes from Debian's coreboot-utils package (no _util.tar.xz is
# published on the mirror, only roms/ and the full source tarball).
command -v cbfstool >/dev/null || { echo "ERROR: cbfstool not found (coreboot-utils not installed?)"; exit 1; }

# 5. Patch: add the real Intel VBIOS for both possible iGPUs, drop the emulated
#    SeaVGABIOS shim so they can't fight over INT 10h. This is what makes
#    Windows boot and stops the Linux boot-time colour flicker on txtmode.
OUT="/output/${VARIANT}_vgabios.rom"
cp "${ROM}" "${OUT}"
cbfstool "${OUT}" add -f /home/builder/vgabios.bin -n "pci8086,0166.rom" -t optionrom
cbfstool "${OUT}" add -f /home/builder/vgabios.bin -n "pci8086,0126.rom" -t optionrom
cbfstool "${OUT}" remove -n vgaroms/seavgabios.bin 2>/dev/null || true

echo ">> Done. Final CBFS:"
cbfstool "${OUT}" print
echo ">> ROM written to ${OUT}"
