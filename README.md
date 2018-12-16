#STOP DEVELOPMENT
I only develop the fhem modul, after Peter stop his development i do this too.
My future sulution is a change to a HUE Bridge.


# FHEM Trådfri Module

This is a small extension module for the FHEM Home-Control software. It enables connectivity to an IKEA Trådfri gateway.

## Install to FHEM
Run the following commands to add this repository to your FHEM setup:
```
update add https://raw.githubusercontent.com/Saharel001/Tradfri-FHEM/src/controls_tradfri.txt
update
shutdown restart
```

Since there is no documentation yet, FHEM might throw some errors during update. Don't worry about them.

## Prerequisites

**Summary:**
* Perl JSON packages (JSON.pm), on my setups they can be installed by running `sudo apt-get install libjson-perl`
* IKEA devices: a gateway, a bulb and a remote control/ dimmer

You need to have an IKEA Trådfri Bulb or Panel, a Control-Device (e.g. the Dimmer) and the Gateway.  
The gateway has to be set-up with the App, the control device and the bulbs need to be paired.  
__Caution__: Do not make the same mistake I've made. You can __not__ just buy a bulb and a gateway. You need a control device, like the round dimmer, too!

## What this module can do

You can currently do the following with the devices.
Please note, that this module is still in development and there will be new functionality.  

|  | Devices | Groups |  
| ---:|:---:|:---:|  
| Turn on/ off | X | X |  
| Get on/ off state | X | X |
| Update on/ off state periodically | X | X |
| Update on/ off state in realtime |||
| Set brightness | X | X |
| Get brightness | X | X |
| Update brightness periodically | X | X |
| Update brightness in realtime |||
| Set the color temperature | X |--|
| Get the color temperature | X |--|
| Update the color periodically | X |--|
| Update the color in realtime ||--|
| Set the mood |--|X|
| Get the mood |--||
| Get information about a mood |--||
| Update the mood periodically |--||
| Update the mood in realtime |--||

Additional features:
* Get information about a bulb, e.g. firmware version, type and reachable state
* Get the IDs of all devices that are connected to the gateway
* Get the IDs of all groups that are configured in the gateway
* Get the IDs of all moods that are configured for a group

...and some more features, that aren't listed here (but in the FHEM command reference)
## What this module can not do
These points will be implemented later:
* Pair new devices, set group memberships
* Moods can't be modified, added

## Getting started
You need to do as follows in order to control a bulb:
### 1. Declare the Gateway-Connection

* Define a new device in you FHEM setup: `define TradfriGW TradfriGateway <Gateway-Socket>`.
* Don't forget to install the Perl JSON packages (JSON.pm). See "Prerequisites" for a hint how I've installed them.
* You can use the gateway's IP address or its DNS name, don't forget the network port.
* Save your config by running the `save` command in FHEM 

### 2. Control a single device
* Get the list of devices: `get TradfriGW deviceList`. It will return something like that:  
   ```
   65541 => Livingroom Remote 
   65543 => TRADFRI remote control 2 
   65545 => TRADFRI remote control 3 
   ```   
   In my setup, there are three devices: Two bulbs and one control unit. The devices are labeled with the names you configured in the app.  
* Define a new device, with one of the adresses you've just found out (it must be a bulb's address, this module is unable to interact with controllers): `define Bulb1 TradfriDevice 65537`
* Check, if the gateway device was asigned correctly as the IODev
* You can now control this device:  
   `set Bulb1 on` will turn the lamp on  
   `set Bulb1 off` will turn the lamp off  
   `set Bulb1 dimvalue x` will set the lamp's brightness, where x is between 0 and 254   
   `set Bulb1 color warm` will set the lamp to warm-white (if supported)
* If you like to set the color temperature and the brightness directly in the web-interface, set the attribute webCmd to `dimvalue:color`
* You can get additional information about controlling devices in the automatically generated FHEM HTML command reference, under TradfriDevice
### 3. Control a lighting group
* Get the list of groups: `get TradfriGW groupList`. It will return something like that:  
   ```
   168311 => Entrance
   ```   
   In my setup, there is only one group called "Entrance".
* Define a new group, with one of the adresses you've just found out: `define Group1 TradfriGroup 193768`
* Check, if the gateway device was asigned correctly as the IODev
* You can now control this group, like a single device:  
   `set Group1 on` will turn all devices in the group on  
   `set Group1 off` will turn all devices in the group off
   `set Group1 dimvalue x` will set all brightnesses of the group to a certain value, where x is between 0 and 254 
* If you like to set the brightness directly in the web-interface, set the attribute webCmd to `dimvalue`
* You can get additional information about controlling groups in the automatically generated FHEM HTML command reference, under TradfriGroup

## What to do, if my FHEM isn't responding anymore?

Actually, this shouldn't happen anymore. Wait 5 seconds, and all processes, that are related to this Trådfri module, should kill themselves (if there is a configuration error, that isn't yet handled by this module).    
If you managed to kill this module, fell free to contact me (with your log, you configuration and a description, of what you did to make FHEM unresponsible).

In most cases if Jtradfri not resonse, the IKEA Gateway are crashed. In this case you must be restart the gateway and the jTradfri service after that too.

## Credits
FORK from https://github.com/peterkappelt/Tradfri-FHEM

## Contact me
You may also leave a comment there. A FAQ page will be created soon.
If you've a github account: please open an issue, with the appropriate description of your problem.
