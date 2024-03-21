 
# IskraSmartMeterInterface

This repository contains the design files and firmware for the ISKRA-Smart-Meter-Interface project.

As for now, this only consists of the software driver for Tasmota.
The schematic along with the board-files and a housing will be released after some cleanup work.

This project is based on work done by  [pocki80](https://github.com/pocki80) who reverse engineered the correct encryption scheme and data format. - Thank you!

## Overview
The main controller interfaces with the smart-meter via a serial infrared interface. Provisions are made for bidirectional communications. However, the meter deployed by WienerNetze (in Vienna), does not appear to accept any commands.

The ESP32 runs the awesome [Tasmota](https://tasmota.github.io/docs/) firmware and has a custom driver for the smart-meter written in [Berry](https://berry-lang.github.io/). It can be found in the [app](/app) folder.


## Usage
Assemble the board as per schematics and flash Tasmota (version >=13).

Drop the Berry-script named [smart_meter.be](/app/smart_meter.be) from the [app](/app) folder into the filesystem and add it to the 'autoexec.be' as per the example.

Configure your the key you received from your energy supplier as well as the MQTT-Topic you would like to publish your data to in [smart_meter_config.json](/app/smart_meter_config.json) and copy it to the device as well.

A MQTT-broker must be configured in the regular settings of Tasmota.


## License
This project is licensed under the GPLv3.

