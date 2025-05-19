# 📋 AERC RotorFlight & Ethos Widgets

### Overview
This package contains a range of widgets for use on Frsky Ethos transmitters that leverage a variety of useful RotorFlight telemetry sensors to provide visual and audio information that I felt is valuable when flying RC Helicopters.

** WHILST TESTING OF THESE WIDGETS HAS BEEN EXTENSIVE, USE THESE WIDGETS AT YOUR OWN RISK **

X18R/RS or X20 Series:
![X18RS - Example](https://github.com/user-attachments/assets/18f39b55-cdc5-4c95-ba79-9a690f61f107)
![X18RS - Summary](https://github.com/user-attachments/assets/4c01946e-cb1c-4a8c-be81-8279f794ceed)

X14 Series:
![X14 Series - Example](https://github.com/user-attachments/assets/2ffcc64a-d0c0-46fb-a380-bf6eedda18b1)
![X14 Series - Summary](https://github.com/user-attachments/assets/af64c146-5173-4b0f-a9c0-5e16f2d70dd2)

### ✅ Requirements

- RFSuite - These scripts piggy-back off the amazing work that has been done with RF Suite, it is a requirement that RFSuite be installed for the vast majority of these scripts to function. [RFSuite](https://github.com/rotorflight/rotorflight-lua-ethos-suite)
- Frsky Transmitter running the latest version (1.6 and above)
- I will be creating a supporting Youtube video that covers the installation and configuration of these widgets and discussed them in more detail soon
- Whilst not essential, these widgets display better when used in conjunction with the Dark Mode display setting on the transmitter
- Supports either FRSky or ELRS Telemetry
- You don't need to use all of the widgets, they have been designed so they work independantly, although they do work best when worked in conjuction with one another to provide a similar look and feel

Telemetry Requirements:

- In order for the widgets to work correctly, the following telemetry sensors need to be selected in RotorFlight and discovered on the radio:
- Altitude, BEC Voltage, Cell Count, Charge Level, Consumption, Current, ESC Temp, Headspeed, Throttle, Voltage

### 🔁 Shared Functionality Across All Widgets

- Telemetry Connection Monitoring:
	- Tracks telemetry link status and triggers a grace period on reconnect
	- Grace period during model connection that displays `--` before data is shown, this allows time for telemetry sensors to update and stabilise prior to displaying values

- Dynamic Display Rendering:
	- Dynamic text scaling to ensure text used will be the largest usable for the widget space
	- Defaults to Black Background with a toggle option to return it to the Ethos native background to provide a more 'standard' look
	- Visual information displayed if telemetry sensors are missing or if configurable switch hasnt been defined
	- Configurable suffixs for all telemetry sensors (Can show or disable the telemetry suffix)
	- XXL Text On/Off function in each widget to allow it to make use of XXL text if supported in the widget window

 - Audio Alert System:
	- On/Off functionality per widget if the widget has audio alerts configured
	- Audio alerts disabled during grace period or invalid data, this protects against false alerting when no model is connected or when connecting your model via USB
  
- Settings Configuration:
	- Per-widget customization: thresholds, display toggles, audio control, enable/disable certain functionality, summary duration etc

 - Summary Duration:
	- Telemetry widgets will display summary information when the model is disconnected showing the max values received during the flight and a summary of battery values
	- Configurable duration for this to be displayed per widget (default 30 seconds)

 - 🚀 Future improvements Planned: 
	- Configurable background color / text color
	- Gauge styles instead of just plain numbers for BEC Voltage, ESC Temp & Headspeed
	- Additional Language support
	- Audio notification when a flight has been logged with a toggle on/off button
	- User definable audio callouts (currently only supports no audio callouts or callouts in 10% increments starting at 100%)

### 📝 Release Notes

- 20/05/2025 - Official V1.0 Release

*** 📐 AERC Layouts ***

- These layouts will be installed by default when you load the widgets into your scripts directory

![X18RS - Layouts](https://github.com/user-attachments/assets/8ad19ea8-9c89-4805-be2a-a5a22cd6fb94)
![X14 Series - Layout](https://github.com/user-attachments/assets/781db913-4857-46ca-a0d3-e81c2399cdd6)

NOTE: You do not need to use these layouts and can use any of the widgets below in your own layout, just keep in mind they have been designed for use with the layout I have designed but will function fine in any widget box provided the size is appropriate

*** 📦 AERC Battery ***

- Displays a dynamic battery bar where the green fill dynamically shrinks as the battery is consumed
	- Note: If you disable the battery info display settings, this widget will run in a small widget window also
- Configurable on/off Battery remaining callouts every 10% with haptic feedback and audio alerting when the battery reaches 0%
- reserve %**, **cell count**
- Detects and warns for discharged batteries
- Configurable to support HV LiPos
- Optional battery info block showing pack voltage, cell voltage, cell count and consumed mah
- Configurable cell count to support edge cases where Cell Count telemetry is not functional (there is currently an on-going issue with some scorpion esc's and Cell Count telemetry)

*** ⚡ AERC BEC Voltage ***

- Displays BEC Voltage from telemetry
- Monitors BEC voltage, color-coded (green/red)
- Configurable alert value, set this approx 0.3v below your BEC operating voltage
- Configuable On/Off audio alerting when BEC voltage drops below configured threshold AND the Motor On / Throttle switch has been assigned

*** 📈 AERC ESC Temp ***

- Displays ESC temperature in °C or °F 
- Audio alerts for warning level and critical level temperatures
- Configurable warning / critical temp values
- Optional suffix toggle

***🚁 AERC Flights ***

- Tracks flights per model using throttle switch timing
- Configurable (per-model) `preset` value so you can specify an initial flight count, allowing you to determine the starting flight count for each model
- Configurable `duration` value which is the time in seconds before a flight is recorded (defaults to 25).
- Flights logged to scripts/aerc/flight_log/ into a simple .txt file that can be used to view the number of flights you have done between a certain period of time.	
- Configurable date format for flight log recording

*** 🖼 AERC Model Image ***

- Displays RotorFlight logo by default when no model connected or if no model image is found
- Loads model image from `scripts\aerc\images`. You need to ensure you model image file is copied into this folder and the name of the image file matches craftname in Rotorflight (including any spaces).

*** 🏷 AERC Model Name ***

- Displays `craftname` from Rotorflight Craftname (including any spaces)
- Displays a message in lui of Craftname to alert you if you havent configured a craftname in Rotorflight

*** 🔄 AERC RPM ***

- Displays headspeed (RPM) from telemetry
- Color text display logic: green above `minRpm`, red below

*** ⚡ AERC Current / Altitude / Throttle ***

- These are simple telemetry display widgets that display Current, Altitude and Throttle telemetry values
- Altitude supports both Meters or Ft

*** ⏱ AERC Timer ***

- Customised timer that provides a the same appearance as other widgets
- Configurable as a count up or count down timer with configurable on/off audio alerting
