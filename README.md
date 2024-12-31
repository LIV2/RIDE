# 🏍 RIDE - A500+ Fast Ram + IDE
## IDE + 11.37 Megabyte Fast RAM for the A500/A1000/A2000/CDTV
![PCB](Docs/PCB3D.png?raw=True)

## Features
- Autoboot IDE, Kick 1.3 compatible Open Source driver [lide.device](https://github.com/LIV2/lide.device)
- 11.37MB Fast RAM - 1.5MB $C0/Ranger + 8MB Fast + 1.87 Bonus ($A00000)

## Table of contents
1. [Compatibility](#compatibility)
2. [Jumper settings](#jumper-settings)
3. [Connections](#connections)
4. [Programming](#programming)
5. [Ordering PCBs](#ordering-pcbs)
    * [PCB Order details](#pcb-order-details)
    * [PCB Assembly](#pcb-assembly)
    * [Bill of Materials](#bill-of-materials)
6. [License](#license)

## Compatibility

Compatible with Kickstart 1.3 and up.

## Jumper settings

**IDE Off**: Close to disable IDE  
**RAM1/RAM2**: Autoconfig RAM configuration
|RAM1|RAM2|Size|
|-|-|----|
|Open|Open|**8 MB**|
|Closed|Open|**4 MB**|
|Open|Closed|**2 MB**|
|Closed|Closed|**Disable**|

## Connections
* **LED**: Activity LED  
* **OVR**: **(Optional)** if connected this will enable the Ranger ($C00000) and Bonus ($A00000) RAM regions.  
Connect OVR to Gary pin 29 or pin 17 of the side expansion port  
* **CFGIN/OUT**: These pins allow this device to co-exist with other Autoconfig devices.
If there are no other Autoconfig devices in your system you can just leave these unconnected.  
If there *are* other Autoconfig devices you will want to use one of these to add the device to the chain.<br /><br />
In the Amiga 2000 you can connect CFGIN to U606 Pin 8 which will add the device to the end of the chain but **NOTE: This takes up the config signal for the leftmost slot (CN601) so do NOT install a Zorro card there**

## Programming

Program the CPLD using this [jed file](https://github.com/LIV2/RIDE/raw/master/Binary/RIDE.jed) - You can find instructions on how to do that [here](https://linuxjedi.co.uk/2020/12/01/programming-xilinx-jtag-from-a-raspberry-pi/)

IDE ROM can be programmed by booting from the latest lide-update.adf [here](https://github.com/LIV2/LIDE.device/releases/latest).


## Ordering PCBs

Download the latest Gerbers.zip from the latest release listed on the right-hand side of this page.

Also included in the release are the placement and bom files needed for JLCPCB's assembly service

### PCB Order details
This PCB has been designed to JLCPCB's 4-layer capabilities so I recommend ordering from them

* Layers: 4
* Surface finish: ENIG
* Remove Order Number: Yes

### PCB Assembly
The release files include the relevant BOM and CPL files for JLCPCB's Assembly service  
You can use the following options:  
* PCBA Type: Economic
* Assembly side: Top side
* Confirm Parts Placement: Yes (I recommend checking that all ICs have pin 1 in the correct location etc)

### Bill of materials
The Bill of materials can be found under [Releases](https://github.com/LIV2/RIDE/releases/latest)

## Acknowledgements
Thanks to [SukkoPera](https://github.com/SukkoPera) for supporting my early IDE prototype.

## License
[![License: GPL v2](https://img.shields.io/badge/License-GPL_v2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)

This project is licensed under the GPL-2.0 only license