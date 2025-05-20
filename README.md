# 📋 AERC RotorFlight & Ethos Widgets

## Overview
This package contains a range of widgets for use on Frsky Ethos transmitters that leverage a variety of useful RotorFlight telemetry sensors to provide visual and audio information that I felt is valuable when flying RC Helicopters.

** WHILST TESTING OF THESE WIDGETS HAS BEEN EXTENSIVE, USE THESE WIDGETS AT YOUR OWN RISK **

## 📝 Release Notes

- 20/05/2025 - Official V1.0 Release

## X18R/RS and X20 Series:

### Main Display when telemetry connected:

![X18RS - Example](https://github.com/user-attachments/assets/18f39b55-cdc5-4c95-ba79-9a690f61f107)

### Summary Display when telemetry disconnected (Shows max telemetry info and battery last known state):

![X18RS - Summary](https://github.com/user-attachments/assets/4c01946e-cb1c-4a8c-be81-8279f794ceed)

## X14 Series:

### Main Display when telemetry connected:

![X14 Series - Example](https://github.com/user-attachments/assets/2ffcc64a-d0c0-46fb-a380-bf6eedda18b1)

### Summary Display when telemetry disconnected (Shows max telemetry info and battery last known state):

![X14 Series - Summary](https://github.com/user-attachments/assets/af64c146-5173-4b0f-a9c0-5e16f2d70dd2)

## ✅ Requirements

- [RFSuite](https://github.com/rotorflight/rotorflight-lua-ethos-suite) - These scripts piggy-back off the amazing work that has been done with RF Suite, it is a requirement that RFSuite be installed for the vast majority of these scripts to function.
- Frsky Transmitter running the latest version (1.6 and above)
- I will be creating a supporting Youtube video that covers the installation and configuration of these widgets and will cover them in more detail (coming soon)
- Whilst not essential, these widgets display better when used in conjunction with the Dark Mode display setting on the transmitter
- Supports either FRSky or ELRS Telemetry
- You don't need to use all of the widgets, they have been designed so they work independantly, although they do work best when used in conjuction with one another to provide a similar look and feel

## Telemetry Requirements:

In order for the widgets to work correctly, the following telemetry sensors need to be selected in RotorFlight and discovered on the radio:

- Altitude, BEC Voltage, Cell Count, Charge Level, Consumption, Current, ESC Temp, Headspeed, Throttle, Voltage

## Installation Instructions:

1. Download the latest release of [AERC_RF_Widgets](https://github.com/AERCHeli/AERC_RF_Widgets)

![Release](https://github.com/user-attachments/assets/9f446267-d96a-4bd8-9d69-0a8ea0e49f1f)

3. Extract the .zip file
4. Connect your Frsky transmitter into your PC and select 'Ethos Suite'
5. Copy the `aerc` folder you extracted in step 2 onto the transmitters storage under the `scripts\` directory
6. Unplug the transmitter > press the Disp button > Select the + icon to add a new display and scroll down to the bottom and choose the layout (see further down for the new layouts)
7. Within the configure screens menu, add all of the newly created AERC Widgets (see below example)
   
![Layout Installation](https://github.com/user-attachments/assets/8cec3c1c-f089-4d24-93cf-7033310c144d)

8. Exit out of the configure screens menu and you will be presented with something similar to the below

![Initial Layout](https://github.com/user-attachments/assets/bd380edb-228e-4ac7-af0f-c6dfd3220342)

Note: You may see missing sensors or other warning messages if you have your Heli connected, if you see `Missing Sensor` within any of the widgets, this means that the associated telemetry sensor for the widget isnt available - See Telemetry Requirements above for required telemetry sensors.

9. Configure switches for those widgets that require it, they will display `No Switch` if they require switches to be assigned

I'd suggest opening `Configure Widget` for each of the widgets so you can configure them and adjust any options to your own setup / region

I will be releasing a youtube video that will cover this is far more detail, so if you're experiencing issues that would be the best point of reference to resolve them.

## 🔁 Shared Functionality Across All Widgets

### Telemetry Connection Monitoring:
- Tracks telemetry link status and triggers a grace period on reconnect
- Grace period during model connection that displays `--` before data is shown, this allows time for telemetry sensors to update and stabilise prior to displaying values

### Dynamic Display Rendering:
- Dynamic text scaling to ensure text used will be the largest usable for the widget space
- Defaults to Black Background with a toggle option to return it to the Ethos native background to provide a more 'standard' look
- Visual information displayed if telemetry sensors are missing or if configurable switch hasnt been defined
- Configurable suffixs for all telemetry sensors (Can show or disable the telemetry suffix)
- XXL Text On/Off function in each widget to allow it to make use of XXL text if supported in the widget window

### Audio Alert System:
- On/Off functionality per widget if the widget has audio alerts configured
- Audio alerts disabled during grace period or invalid data, this protects against false alerting when no model is connected or when connecting your model via USB for RF Configuration Updates
  
### Settings Configuration:
- Per-widget customization: thresholds, display toggles, audio control, enable/disable certain functionality, summary duration etc

### Summary Duration:
- Telemetry widgets will display summary information when the model is disconnected showing the max values received during the flight and a summary of battery values
- Configurable duration for this to be displayed per widget (default 30 seconds)

### Future improvements Planned: 
- Configurable background color / text color
- Gauge styles instead of just plain numbers for BEC Voltage, ESC Temp & Headspeed
- Additional Language support
- Audio notification when a flight has been logged with a toggle On/Off button
- User definable audio callouts (currently only supports no audio callouts or callouts in 10% increments starting at 100%)

## AERC Layouts

These layouts will be installed by default when you load the widgets into your scripts directory

### X18R / RS and X20 Series Layouts:

![X18RS - Layouts](https://github.com/user-attachments/assets/8ad19ea8-9c89-4805-be2a-a5a22cd6fb94)

### X14 Series Layouts:

![X14 Series - Layout](https://github.com/user-attachments/assets/a2c9da8b-ea88-47f9-aec1-458183d5c541)

NOTE: You do not need to use these layouts and can use any of the widgets below in your own layout, just keep in mind they have been designed for use with the layout I have designed but will function fine in any widget box provided the size is appropriate

## 🔋 AERC Battery

- Displays a dynamic battery bar where the green fill dynamically shrinks as the battery is consumed
	- Note: If you disable the battery info display settings, this widget will run in a small widget window also
- Configurable On/Off Battery remaining callouts every 10% with haptic feedback and audio alerting when the battery reaches 0%
- Configurable reserve % so you can fly to 0% on the battery display but land at a safe pack voltage, default is 30% which is approx 3.80v per cell
- Detects and warns for discharged batteries
- Configurable to support HV LiPos
- Optional battery info block showing pack voltage, cell voltage, cell count and consumed mah
- Configurable cell count to support edge cases where Cell Count telemetry is not functional (there is currently an on-going issue with some scorpion esc's and Cell Count telemetry)

## ⚡ AERC BEC Voltage

- Displays BEC Voltage from telemetry
- Monitors BEC voltage, color-coded (green/red)
- Configurable alert value, set this approx 0.3v below your BEC operating voltage
- Configuable On/Off audio alerting when BEC voltage drops below configured threshold AND the Motor On / Throttle switch has been assigned

## 📈 AERC ESC Temp

- Displays ESC temperature in °C or °F 
- Audio alerts for warning level and critical level temperatures
- Configurable warning / critical temp values

## 🚁 AERC Flights

- Tracks flights per model
- Configurable (per-model) `preset` value so you can specify an initial flight count, allowing you to determine the starting flight count for each model
- Configurable `duration` value which is the time in seconds before a flight is recorded (defaults to 25).
- Flights logged to scripts/aerc/flight_log/ into a simple .txt file that can be used to view the number of flights you have done between a certain period of time.	
- Configurable date format for flight log recording

## 📸 AERC Model Image

- Displays RotorFlight logo by default when no model connected or if no model image is found
- Loads model image from `scripts\aerc\images`. You need to ensure you model image file is copied into this folder and the name of the image file matches craftname in Rotorflight (including any spaces). Also ensure the model image file is in .BMP format.

## 🏷 AERC Model Name

- Displays `craftname` from Rotorflight Craftname (including any spaces)
- Displays a message in lui of Craftname to alert you if you havent configured a craftname in Rotorflight

## 🔄 AERC RPM

- Displays headspeed (RPM) from telemetry
- Color text display logic: green above minRpm value or red if below it

## ⚡ AERC Current / Altitude / Throttle

- These are simple telemetry display widgets that display Current, Altitude and Throttle telemetry values
- Altitude supports both M or Ft

## ⏱ AERC Timer

- Customised timer that provides a the same appearance as other widgets
- Configurable as a count up or count down timer with configurable On/Off audio alerting
