# T420-coreboot

I have followed these guides except that i have used at FT232H instead of an raspberrypi for readding and writing the bios 

[Lenovo T420 Coreboot W/Raspberry Pi](https://www.instructables.com/Lenovo-T420-Coreboot-WRaspberry-Pi) and 
[t420-coreboot-guide](https://github.com/nenadstoisavljevic/t420-coreboot-guide?tab=readme-ov-file)


### FT232H 

#### Pinnout 

[FTDI_FT2232H](https://wiki.flashrom.org/FT2232SPI_Programmer#FTDI_FT2232H_Mini-Module)

| Name | Color | Test clip pin# | FT232H pin#|
| ---- | ----- | -------------- | ---------- | 
| /CS  | Brown | 1              | AD3        | 
| MISO | Yellow| 2              | AD1        | 
| GND  | Black | 4              | +3.3V      | 
| MOSI | Orange| 5              | AD1        | 
| SCLK | Green | 6              | AD0        | 
| VCC  | Red   | 8              | GND        | 



#### Read out the BIOS
```sh
flashrom -p ft2232_spi:type=232H -c MX25L6406E/MX25L6408E -r factory1.rom
```

#### Write back the compiled BIOS
```sh
flashrom -p ft2232_spi:type=232H -c MX25L6406E/MX25L6408E -w coreboot.rom
```
