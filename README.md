
# FHEM Trådfri Module

This is a small extension module for the FHEM Home-Control software. It enables connectivity to an IKEA Trådfri gateway.

## About this branch (cf-dev)
Das ist der Beta Pfad des Moduls

## Installation in FHEM
Zuerst im OS folgendes Modul installieren.
```
sudo apt-get libjson-perl
```

Danach im FHEM folgende Kommandos absetzen
```
update add https://raw.githubusercontent.com/Saharel001/Tradfri-FHEM/dev-cf/src/controls_tradfri.txt
update
shutdown restart
```

* Get the list of devices: `get TradfriGW deviceList`. It will return something like that:  
   ```
   65541 => Wohnzimmer Remote 
   65543 => TRADFRI remote control 2 
   65545 => TRADFRI remote control 3 

   ``` 
   
## Contact me

If you've a github account: please open an issue, with the appropriate description of your problem.
