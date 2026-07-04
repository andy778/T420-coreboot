# T420-coreboot

I have followed these guides except that I have used an FT232H instead of a Raspberry Pi for reading and writing the BIOS chip [MX25L6406E](https://www.macronix.com/Lists/Datasheet/Attachments/8630/MX25L6406E,%203V,%2064Mb,%20v1.9.pdf)  

* [Lenovo T420 Coreboot W/Raspberry Pi](https://www.instructables.com/Lenovo-T420-Coreboot-WRaspberry-Pi)
* [t420-coreboot-guide](https://github.com/nenadstoisavljevic/t420-coreboot-guide?tab=readme-ov-file)


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

## LIBREBOOT 

I looked at the guide below for inspiration; one can't follow it exactly any more as the libreboot project has refactored (especially the vendor files) since it was made. I have used a Debian Bookworm container on top of Proxmox 
-> 8 GB of RAM and a 15 GB drive (8 GB is too small) 

* [Installing libreboot on a ThinkPad T420](http://www.härdin.se/blog/2023/03/22/installing-libreboot-on-a-thinkpad-t420/)

### Download and build the development environment  
```sh
git clone https://codeberg.org/libreboot/lbmk
```

## Update flash after it has been flashed the first time
* [How do I "edit grub to add iomem=relaxed"?](https://askubuntu.com/questions/1120578/how-do-i-edit-grub-to-add-iomem-relaxed)

```sh
sudo flashrom -p internal:boardmismatch=force -c MX25L6406E/MX25L6408E -w coreboot.rom
```

## Tested hardware 
* Updated CPU to Intel i7-3632QM — with coreboot one can go to Ivy Bridge
* AX210 Mini PCIe WLAN 6E card  
* BE200 Mini PCIe WLAN 7 card
* mSATA SanDisk U100 in the Mini PCIe slot next to the RAM in the bottom  

