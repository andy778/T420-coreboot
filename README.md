# T420-coreboot

I have followed these guides except that I have used an FT232H instead of a Raspberry Pi for reading and writing the BIOS chip [MX25L6406E](https://www.macronix.com/Lists/Datasheet/Attachments/8630/MX25L6406E,%203V,%2064Mb,%20v1.9.pdf)  

* [Lenovo T420 Coreboot W/Raspberry Pi](https://www.instructables.com/Lenovo-T420-Coreboot-WRaspberry-Pi)
* [t420-coreboot-guide](https://github.com/nenadstoisavljevic/t420-coreboot-guide?tab=readme-ov-file)

> **Status:** since 2026-07-18 the machine runs **Libreboot 26.01rev1** — see the [Libreboot update](#libreboot-update-done-2026-07-18-release-2601rev1) section. `config`, `vgabios.bin` and release 20240802 belong to the original 2024 custom coreboot build and are kept for history/rollback.


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

Running Libreboot `t420_8mb`, `seagrub_..._corebootfb_svenska.rom` (SeaBIOS + GRUB, libgfxinit, neutered ME). Built in a Proxmox CT with Debian Trixie; flashed internally on the T420 (kernel arg `iomem=relaxed`), no clip needed.

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

# 5. Extract tarball, take bin/t420_8mb/seagrub_..._corebootfb_svenska.rom
#    (ignore cache/DO_NOT_FLASH/)

# 6. On the T420, AC plugged in, wait for VERIFIED — on error reflash backup, do NOT reboot
sudo flashrom -p internal:boardmismatch=force -c MX25L6406E/MX25L6408E -w <rom>
```

First boot is slow / may reset once (memory training). Bricked: FT232H + clip, write `backup-a.rom`.

### Windows fix: add the vendor VGA option ROM

Stock Libreboot uses libgfxinit + SeaVGABIOS (emulated INT 10h) — Linux boots fine but **Windows hangs at the boot logo**. The old 2024 build worked because it ran the real Intel VBIOS. Fix: inject `vgabios.bin` (in this repo) into the image with `cbfstool` (from lbmk, or the `libreboot-<RELEASE>_util.tar.xz` archive on the mirror):

```sh
cp seagrub_t420_8mb_libgfxinit_corebootfb_svenska.rom windows-fix.rom
# SeaBIOS picks pciVVVV,DDDD.rom by live PCI ID -> 0166 = Ivy Bridge HD 4000 (i7-3632QM),
# 0126 = Sandy Bridge HD 3000 (only runs if that CPU is installed; harmless to keep both)
cbfstool windows-fix.rom add -f vgabios.bin -n "pci8086,0166.rom" -t optionrom
cbfstool windows-fix.rom add -f vgabios.bin -n "pci8086,0126.rom" -t optionrom
# drop the emulated shim so it can't fight the real VBIOS over INT 10h
cbfstool windows-fix.rom remove -n vgaroms/seavgabios.bin
cbfstool windows-fix.rom print   # sanity check; etc/pci-optionrom-exec must not be 0
```

Flash `windows-fix.rom` as in step 6 above. GRUB and Linux are unaffected.

## Update flash after it has been flashed the first time (historical — superseded by the Libreboot update section above)
* [How do I "edit grub to add iomem=relaxed"?](https://askubuntu.com/questions/1120578/how-do-i-edit-grub-to-add-iomem-relaxed)

```sh
sudo flashrom -p internal:boardmismatch=force -c MX25L6406E/MX25L6408E -w coreboot.rom
```

## Tested hardware 
* Updated CPU to Intel i7-3632QM — with coreboot one can go to Ivy Bridge
* AX210 Mini PCIe WLAN 6E card  
* BE200 Mini PCIe WLAN 7 card
* mSATA SanDisk U100 in the Mini PCIe slot next to the RAM in the bottom  

