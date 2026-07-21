# T420-coreboot

I have followed these guides except that I have used an FT232H instead of a Raspberry Pi for reading and writing the BIOS chip [MX25L6406E](https://www.macronix.com/Lists/Datasheet/Attachments/8630/MX25L6406E,%203V,%2064Mb,%20v1.9.pdf)  

* [Lenovo T420 Coreboot W/Raspberry Pi](https://www.instructables.com/Lenovo-T420-Coreboot-WRaspberry-Pi)
* [t420-coreboot-guide](https://github.com/nenadstoisavljevic/t420-coreboot-guide?tab=readme-ov-file)

> **Status:** since 2026-07-18 the machine runs **Libreboot 26.01rev1** (`txtmode` variant patched with the vendor Intel VBIOS so Windows 11 boots and there's no colour flicker) — see the [Libreboot update](#libreboot-update-done-2026-07-18-release-2601rev1) section. `config` and release 20240802 belong to the original 2024 custom coreboot build and are kept for history/rollback; `vgabios.bin` is still in active use (it's the VBIOS the fix injects).


### FT232H 

![FT232H and SOIC8 clip](FT232H.jpg)

#### Pinout 

[FTDI_FT2232H](https://wiki.flashrom.org/FT2232SPI_Programmer#FTDI_FT2232H_Mini-Module)

| Name | Color | Test clip pin# | FT232H pin#|
| ---- | ----- | -------------- | ---------- | 
| /CS  | Brown | 1              | AD3        | 
| MISO | Yellow| 2              | AD2        | 
| GND  | Black | 4              | GND        | 
| MOSI | Orange| 5              | AD1        | 
| SCLK | Green | 6              | AD0        | 
| VCC  | Red   | 8              | +3.3V      | 



#### Read out the BIOS
```sh
flashrom -p ft2232_spi:type=232H -c MX25L6406E/MX25L6408E -r factory1.rom
```

#### Write back the compiled BIOS
```sh
flashrom -p ft2232_spi:type=232H -c MX25L6406E/MX25L6408E -w coreboot.rom
```

## LIBREBOOT (historical — first attempt notes from 2024)

I looked at the guide below for inspiration; one can't follow it exactly any more as the libreboot project has refactored (especially the vendor files) since it was made. I have used a Debian Bookworm container on top of Proxmox 
-> 8 GB of RAM and a 15 GB drive (8 GB is too small) 

* [Installing libreboot on a ThinkPad T420](http://www.härdin.se/blog/2023/03/22/installing-libreboot-on-a-thinkpad-t420/)

### Download and build the development environment  
```sh
git clone https://codeberg.org/libreboot/lbmk
```

## Libreboot update (done 2026-07-18, release 26.01rev1)

**Final working image:** Libreboot `t420_8mb`, `seagrub_..._libgfxinit_txtmode_svenska.rom` **patched with the real Intel VBIOS** (see the [Windows/flicker fix](#windows--flicker-fix-add-the-vendor-vga-option-rom) below). SeaBIOS + GRUB, neutered ME. Built in a Proxmox CT with Debian Trixie; flashed internally on the T420 (kernel arg `iomem=relaxed`), no clip needed. The [Docker build](#one-shot-docker-build) does the whole download → inject → patch chain automatically.

> Variant history: `corebootfb` boots Linux but Windows 11 hangs at the logo and the fix caused colour flicker on Kali. `txtmode` + real VBIOS is what the 2024 build used and is the layout that boots Windows 11 **and** Linux cleanly.

```sh
# 1. On the T420: backup current flash (read twice, sha256sum must match, keep off-laptop)
sudo flashrom -p internal -c MX25L6406E/MX25L6408E -r backup-a.rom

# 2. In the Proxmox CT (only dependencies as root, lbmk refuses sudo otherwise)
git clone https://codeberg.org/libreboot/lbmk && cd lbmk
git fetch --tags && git checkout <RELEASE>      # e.g. 26.01rev1
sudo ./mk dependencies debian

# 3. Get + verify ROMs (mirror: mirrors.mit.edu/libreboot/stable/<RELEASE>/roms/)
wget <mirror>/libreboot-<RELEASE>_t420_8mb.tar.xz{,.sha512,.sig}
sha512sum -c *.sha512 && gpg --verify *.sig     # key: libreboot.org/lbkey.asc

# 4. Inject neutered ME + onboard NIC MAC  (stale "cannot create lock"? -> rm -f lock)
./mk inject libreboot-<RELEASE>_t420_8mb.tar.xz setmac 00:21:cc:61:b8:5c

# 5. Extract tarball, take bin/t420_8mb/seagrub_..._txtmode_svenska.rom
#    (ignore cache/DO_NOT_FLASH/) -- then apply the VBIOS patch below before flashing

# 6. On the T420, AC plugged in, wait for VERIFIED — on error reflash backup, do NOT reboot
sudo flashrom -p internal:boardmismatch=force -c MX25L6406E/MX25L6408E -w <rom>
```

First boot is slow / may reset once (memory training). Bricked: FT232H + clip, write `backup-a.rom`.

### Windows / flicker fix: add the vendor VGA option ROM

Stock Libreboot uses libgfxinit + SeaVGABIOS (emulated INT 10h): Linux boots but **Windows 11 hangs at the boot logo**, and on the `corebootfb` variant adding the VBIOS gives Kali **colour flicker at startup** (framebuffer vs. VGA double-init). The 2024 build never had this because it used **text-mode SeaBIOS + the real Intel VBIOS**. So: use the `txtmode` variant and inject `vgabios.bin` (in this repo).

Get `cbfstool`: Debian/Ubuntu `sudo apt install coreboot-utils`, or build it from lbmk's coreboot source. (There is no util tarball on the mirror — only `roms/` and the full source tarball are published.)

```sh
cp seagrub_t420_8mb_libgfxinit_txtmode_svenska.rom windows-fix.rom
# SeaBIOS picks pciVVVV,DDDD.rom by live PCI ID -> 0166 = Ivy Bridge HD 4000 (i7-3632QM),
# 0126 = Sandy Bridge HD 3000 (only runs if that CPU is installed; harmless to keep both)
cbfstool windows-fix.rom add -f vgabios.bin -n "pci8086,0166.rom" -t optionrom
cbfstool windows-fix.rom add -f vgabios.bin -n "pci8086,0126.rom" -t optionrom
# drop the emulated shim so it can't fight the real VBIOS over INT 10h
cbfstool windows-fix.rom remove -n vgaroms/seavgabios.bin
cbfstool windows-fix.rom print   # sanity check; etc/pci-optionrom-exec must not be 0
```

Flash `windows-fix.rom` as in step 6 above. GRUB is plain text (not the graphical splash); Windows 11 and Linux both boot clean.

### One-shot Docker build

`docker/` wraps steps 2–5 + the VBIOS patch into one image, so next release = rebuild with a new `RELEASE`. It downloads and GPG-verifies the ROM tarball, injects ME + MAC, patches the `txtmode` variant (using `cbfstool` from Debian's `coreboot-utils` package), and drops the finished ROM in `./out/`.

```sh
# from the repo root (needs network for the ME blob download during inject)
docker build -f docker/Dockerfile --build-arg RELEASE=26.01rev1 -t t420-rom .
docker run --rm -v "$PWD/out:/output" t420-rom
# -> out/seagrub_t420_8mb_libgfxinit_txtmode_svenska_vgabios.rom  (flash as step 6)
```

Override defaults with `-e` on `docker run` (`MAC`, `VARIANT`, `BOARD`, `MIRROR`). Still verify + flash on the T420 yourself — the container only builds the ROM.

Verified 2026-07-21: the Docker-built ROM's sha256sum matched the manually built `windows-fix2.rom` byte-for-byte.

## Update flash after it has been flashed the first time (historical — superseded by the Libreboot update section above)
* [How do I "edit grub to add iomem=relaxed"?](https://askubuntu.com/questions/1120578/how-do-i-edit-grub-to-add-iomem-relaxed)

```sh
sudo flashrom -p internal:boardmismatch=force -c MX25L6406E/MX25L6408E -w coreboot.rom
```

## Tested hardware 
* Updated CPU to Intel i7-3632QM — with coreboot one can go to Ivy Bridge
* AX210 Mini PCIe WLAN 6E card  
* BE200 Mini PCIe WLAN 7 card (have it, not installed/tested yet)
* mSATA SanDisk U100 in the Mini PCIe slot next to the RAM in the bottom  

