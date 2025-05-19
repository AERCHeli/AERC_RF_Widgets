## 📋 RF Widgets - Single Model Suite - Requirements & Features

### Overview

** USE AT YOUR OWN RISK **

### ✅ Universal Requirements

- **RF Suite (rfsuite)** Majority of the scripts make use of RF Suite and the fantastic work that has been done on the project.
- **Transmitter running the latest version of Ethos**
---

### 🔁 Shared Functionality Across All Widgets

- **Telemetry Connection Monitoring**
	- Tracks telemetry link status and triggers a grace period on reconnect
	- Grace period includes blinking `--` display before data is shown

- **Dynamic Display Rendering**
	- Dynamic text scaling so the text used will be the largest usable for the widget space
	- Triple-layer white border which is enabled by default but can be disabled per widget
	- Defaults to Black Background but there is a toggle option to return it to Ethos background to provide a more 'standard' look
	- Widgets blink during the configured grace period to allow time for telemetry sensors to stabilise before populating and stop blinking after the grace period

- **Audio Alert System**
	- Toggleable per widget if the widget has audio alerts configured
	- Alerts disabled during grace period or invalid data, this protects against false alerting when no model is connected or when connecting your model via USB

- **Settings Configuration**
	- Per-widget customization: thresholds, display toggles, audio control, enable/disable certain functionality etc

- **Fallback Behavior**
	- Shows "..No Link.." when telemetry is unavailable (no model connected)
	- Displays `--` during grace or missing data
---

### 🎯 Widget Specific Functionality & Requirements

#### 📦 RF Battery (`rfbatt`)

- **Requirements**
	- Requires Charge, Cell Count & Voltage telemetry sensors
	charge level
- **Functionality**
- Displays battery % using charge sensor or voltage fallback
- Updates ETHOS `Remaining` telemetry sensor
- Handles **HV LiPos**, **reserve %**, **cell count**
- Detects and warns for **discharged batteries**
- Optional battery info block showing pack voltage, cell voltage, and cell count

-Future Improvements:
User definable audio callouts (currently only supports no audio callouts or callouts in 10% increments starting at 100%)

#### ⚡ RF BEC Voltage (`rfbec`)
- Monitors BEC voltage, color-coded (green/red)
- Plays alert when voltage drops below configured threshold
- Uses `becAlert` voltage in volts (e.g., 6.7V)
- Optional border display
Requirements: Telemetry sensor named BEC Voltage (Widget wont work if you dont have this sensor configured and available)

Functionality:
Defaults to ..No Link.. when telemetry isnt connected or after telemetry is lost.
Displays BEC voltage after 15 seconds of telemetry being active.
Voltage displayed in .1 decimals and rounds the number based off .2 decimal places (eg. 8.08 will display as 8.1V)
Border on/off toggle
Audio on/off toggle
Configurable BEC Voltage Alert, this value is used to determine the display color of the BEC Voltage value. 
	If its greater than this value it will display green.
	If the BEC Voltage drops below this value it will play an audio alert 'BEC Voltage Critical' with haptic feedback
Throttle Switch assignment - this is tied to audio alerting, the BEC Voltage Critcal alert will only play if you have audio enabled and if the throttle switch is configured with your motor on position

#### 📈 RF ESC Temp (`rfesc`)
- Displays ESC temperature in °C or °F
- Audio alerts for hot and critical temperatures
- Configurable:
  - Warning / Critical temps
  - °C/°F unit and suffix
- Optional suffix toggle and border display
Defaults to ..No Link.. when telemetry isnt connected or after telemetry is lost.
Displays BEC voltage after 15 seconds of telemetry being active.
Voltage displayed in .1 decimals and rounds the number based off .2 decimal places (eg. 8.08 will display as 8.1V)
Border on/off toggle
Audio on/off toggle
Configurable BEC Voltage Alert, this value is used to determine the display color of the BEC Voltage value. 
	If its greater than this value it will display green.
	If the BEC Voltage drops below this value it will play an audio alert 'BEC Voltage Critical' with haptic feedback
Throttle Switch assignment - this is tied to audio alerting, the BEC Voltage Critcal alert will only play if you have audio enabled and if the throttle switch is configured with your motor on position

#### 🛫 RF Flight Counter (`rfcount`)
- Tracks flights per model using throttle switch timing
- Saves:
  - `preset` (baseline flights)
  - `flightsSincePreset` (session)
  - `totalFlights` (computed)
- Logs flight records with date to `flight-log.txt`
- Configurable:
  - Throttle switch
  - Trigger delay
  - Preset value
  - Date format
  Tracks flight counts per model
Configurable preset flight amount per model so you can easily configure your starting flight value
Logs each flight you do to a text file on the SD card as Date, Model Name, Total Flight Count so you can track flights per month / year etc 
Configurable date format for the flight log
Throttle Switch assignment - Used to determine when to log a flight

Future Improvements
Audio notification when a flight has been logged with a toggle on/off button.
Visual blinking during delay period with yellow text.

#### 🖼 RF Model Image (`rfimage`)
- Displays model-specific image from `/bitmaps/models/<craftName>.bmp`
- Fallback to default image if not found
- Loads image once per session using `rfsuite.craftName`
- Optional border

Future:
Configurable default image to display to replace the Rotorflight logo when telemetry isnt active or a model image isnt found.
Defaults to Rotorflight Image when telemetry isnt connected or after telemetry is lost.
Loads model image from bitmaps\model\"craftname.bmp" - check path. You need to ensure you model image file is placed in this folder and the name matches exactly what Craftname is configured as in Rotorflight (including any spaces).
Border on/off toggle

#### 🏷 RF Model Name (`rfname`)
- Displays `rfsuite.session.craftName` as large centered label
- Blinks `--` during grace period
- Displays "No Craftname" if name is unavailable
- Optional border
RFName:
Defaults to ..No Link.. when telemetry isnt connected or after telemetry is lost.
Border on/off toggle
Displays craftname from Rotorflight Craftname (including any spaces)
Displays a message in lui of Craftname to alert you if you havent configured a craftname in Rotorflight
Text size is dynamic and will use the largest available text size based on the widget frame size in use.

#### 🔄 RF RPM (`rfrpm`)
- Displays headspeed (RPM) from telemetry
- Color-coded: green above `minRpm`, red below
- Configurable `minRpm` value
- Optional border
Defaults to ..No Link.. when telemetry isnt connected or after telemetry is lost.
Border on/off toggle
Configurable MinRPM value - any headspeed below this will show red headspeed text
Future Improvements:
If requested - I can include Headspeed Audio callouts at intervals or based on a configurable switch. Just not convinced people would want it?

Future improvements I have planned:
Configurable background color / text color
Look using different gauge styles instead of just plain numbers for BEC Voltage, ESC Temp & Headspeed
Additional Language support

** EXTRA CHECKS / TODO BEFORE LIVE**
Check Max Widgets
Temporarily remove summary from battery bar or display Min Percent Sensor telemetry value, and consumed telemetry value on the right

take away borders on all widgets or look at 1pt borders?
Check for nil errors so add defaults in incase missing, check how bs does it - then re-test in sim with a blank model - look at forcing returns if telem sensors are missing or reporting 0?
Look at BattSelector and RFSuite for solid ways to use helper libraries for shared functions
Test layouts on X20/R/S and X18R sims also to ensure all good and to confirm compatibility
finalise notes for all scripts, prepare github steps, work on readme file formating and getting images and screenshots, check bladescaper's. Create an intro blurb explaining why I have done it and the setup. Also mention youtube video of a full FRSky TX setup from scratch.
Create Github Repository and upload V1 files and make a 'release'
Play around with old github and how to easily deploy updates via branches


Standard Lipo
Reserve %	Clamp Voltage (V/cell)
0			3.7
10			3.75
20			3.8
30			3.85
40			3.9
50			3.95

HV Lipo
Reserve %	Clamp Voltage (V/cell)
0			3.7
10			3.76
20			3.82
30			3.88
40			3.94
50			4
