-- #########################################################################
-- #                                                                       #
-- # License GPLv3: https://www.gnu.org/licenses/gpl-3.0.html              #
-- #                                                                       #
-- # This program is free software; you can redistribute it and/or modify  #
-- # it under the terms of the GNU General Public License version 2 as     #
-- # published by the Free Software Foundation.                            #
-- #                                                                       #
-- # This program is distributed in the hope that it will be useful        #
-- # but WITHOUT ANY WARRANTY; without even the implied warranty of        #
-- # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
-- # GNU General Public License for more details.                          #
-- #                                                                       #
-- #########################################################################

-- AERC Widgets - Rotorflight & ETHOS
-- Author: Andy.E (Discord: AJ#9381)
-- Version: 1.0
-- Widget Name: AERC Battery

-- === Global Settings ===
local GRACE_DELAY = 15 -- Time (seconds) to blink before showing battery info after telemetry connected
local BLINK_INTERVAL = 0.5 -- Blinking toggle interval (seconds)
local GRACE_BLINK_DELAY = 2 -- Delay before blinking starts after telemetry connect

-- === Widget Creation ===
local function create()
    local now = os.clock()
    	return {
		telemetrySource = nil, -- Telemetry active source
		sourceVoltage = nil, -- Battery total voltage telemetry source
		sourceCharge = nil,	-- Battery charge level (%) telemetry source
		sourceCellCount = nil, -- Cell count telemetry source
		sourceConsumption = nil, -- Battery consumption (used mAh) telemetry source
		value = 0, -- Calculated battery remaining percentage
		voltage = 0, -- Latest battery voltage reading
		cellCount = 0, -- Cell Count reading
		cellVoltage = nil, -- Latest cell voltage reading
		consumption = 0, -- Latest mAh consumption value
		lastGoodConsumption = 0, -- Retains values for summary screen
		lastGoodValue = 0, -- Retains values for summary screen
		lastGoodVoltage = 0, -- Retains values for summary screen
		lastGoodCellCount = 0, -- Retains values for summary screen
		graceUntil = 0, -- Time until grace period ends
		doneVoltageCheck = false, -- Whether initial discharged battery voltage check completed
		voltageDialogDismissed = false, -- Whether the discharged battery dialog has been dismissed
		telemetryReconnectTime = nil, -- Time (os.clock) when telemetry was last reconnected
		hasTelemetryEverBeenActive = false, --flag to track telemetry loss
		lastTelemetryActive = false, -- Last known telemetry active state
		isDischargedPack = false, -- If true, use voltage-based battery estimation instead of charge telemetry
		voltageDetected = false, -- True once voltage > 2V has been seen after telemetry connect
		playedCallouts = {}, -- Table tracking which audio callouts have been played
		criticalPlayCount = 0, -- Number of times the critical battery callout has been played
		criticalLastPlayTime = 0, -- Last time a critical callout was played (os.clock)
		audioReady = false, -- True if audio callouts are allowed (after stabilization delay)
		blinkOn = true, -- Blinking state flag
		lastBlinkTime = now, -- Last time blink toggled
		blinkReadyTime = now + GRACE_BLINK_DELAY, -- Time when blinking should start
		audioEnabled = true, -- Audio state
		useDefaultBackground = false, -- Default to Black background
		useXXLFont = false, -- Enable XXL font
		showInfoBlock = true, -- Battery info state
		distCheckEnabled = true, -- Enable detection by default
		useHvLipo = false, -- Enable HV Lipo state
		reservePercent = 30, -- Default; overridden after model load
		newReserve = 30, -- Used for editable config
		dischargedThreshold = 4.10, -- Default threshold per cell
		newDischargedThreshold = 4.10, -- Editable in config form
		userCellCount = 0, -- User-defined cell count fallback
		newUserCellCount = 0, -- Used for config form editing
		startingValue = nil, -- Flag for battery % value
		holdUntil = 0, -- Time to retain battery bar after telemetry loss
		retainDisplay = false, -- Whether to draw the last known bar during hold
		maxHoldDuration = 30, -- Configurable hold duration in seconds
	}
end

-- Returns true if still within the grace delay period after reconnect
local function inGrace(widget)
	return os.clock() < (widget.graceUntil or 0)
end

-- Define percentage ranges for audio battery level announcements
local calloutRanges = {
	[100] = {min = 94, max = 100}, [90] = {min = 85, max = 92},
	[80]  = {min = 75, max = 84},  [70] = {min = 65, max = 74},
	[60]  = {min = 55, max = 64},  [50] = {min = 45, max = 54},
	[40]  = {min = 35, max = 44},  [30] = {min = 25, max = 34},
	[20]  = {min = 15, max = 24},  [10] = {min = 5,  max = 14},
}

-- Percentage clamping
local function clampPercent(value)
	return math.floor(math.max(0, math.min(100, value)) + 0.5)
end

-- Determine max voltage based on HV Lipo enabled
local function getMaxCellVoltage(widget)
	return widget.useHvLipo and 4.30 or 4.20
end

-- Battery Percentage calculations
local function computeRemaining(widget)
	local minV = 3.7
	local maxV = getMaxCellVoltage(widget)
	local reserve = widget.reservePercent or 30
	local perCell = widget.cellVoltage or 0
	local chargeLevel = widget.sourceCharge and widget.sourceCharge:value() or 0

	-- Clamp to 100% if cell voltage exceeds threshold for configured pack type
	local fullVoltage = widget.useHvLipo and 4.20 or widget.dischargedThreshold
	if not widget.startingValue and widget.cellVoltage and widget.cellVoltage > fullVoltage then
		widget.startingValue = 100
	end
	
	-- Step 1: One-time voltage × charge estimate for starting value
	if not widget.startingValue then
		local voltageFactor = (perCell - minV) / (maxV - minV)
		voltageFactor = math.max(0, math.min(1, voltageFactor))

		local estimated = voltageFactor * chargeLevel
		if estimated < reserve then
			widget.startingValue = 0
		else
			local usable = (estimated - reserve) / (100 - reserve)
			widget.startingValue = clampPercent(usable * 100)
		end
	end

	-- Step 2: Use chargeLevel drop to reduce from starting value
	if widget.startingValue and chargeLevel > 0 then
		local consumed = 100 - chargeLevel
		local usableDrop = (consumed / (100 - reserve)) * 100
		local remaining = widget.startingValue - usableDrop
		return clampPercent(remaining)
	else
		return 0
	end
end

-- Select the largest fitting font from allowed list based on widget.useXXLFont
local function selectFont(widget, text, maxWidth, maxHeight)
	local fontPaddingW = 8
	local fontPaddingH = 8
	local fonts = widget.useXXLFont and { FONT_XXL, FONT_XL, FONT_L, FONT_M, FONT_S } or { FONT_XL, FONT_L, FONT_M, FONT_S }
	for _, font in ipairs(fonts) do
		lcd.font(font)
		local textW, textH = lcd.getTextSize(text)
		if textW <= (maxWidth - fontPaddingW) and textH <= (maxHeight - fontPaddingH) then
			return font, textW, textH
		end
	end
	lcd.font(FONT_S)
	local textW, textH = lcd.getTextSize(text)
	return FONT_S, textW, textH
end

-- Check and play battery level callouts
local function checkAndPlayCallout(widget, percent)
	if not widget.audioEnabled or not widget.audioReady or widget.voltage <= 2 then return end
	local now = os.clock()
	for level, range in pairs(calloutRanges) do
		if percent >= range.min and percent <= range.max and not widget.playedCallouts[level] then
			system.playFile(string.format("/scripts/aerc/audio/battery%d.wav", level, AUDIO_QUEUE))
			widget.playedCallouts[level] = true
			return
		end
	end
	
	-- Play critical warning if battery is severely discharged
	if percent <= 4 and widget.criticalPlayCount < 2 and (now - widget.criticalLastPlayTime >= 10) then
		system.playFile("/scripts/aerc/audio/battery-critical.wav", AUDIO_QUEUE)
		system.playHaptic(". . . .")
		widget.criticalPlayCount = widget.criticalPlayCount + 1
		widget.criticalLastPlayTime = now
	end
end

-- === Display Drawing ===
local function paint(widget)
	local w, h = lcd.getWindowSize()

	-- Draw background
	if not widget.useDefaultBackground then
		lcd.color(lcd.RGB(0, 0, 0))
		lcd.drawFilledRectangle(0, 0, w, h)
	end

	-- Prepare display text and color
	local displayText = nil
	local displayLine1 = nil
	local displayLine2 = nil
	local color = lcd.RGB(255, 255, 255)

	-- Display Logic
	if not widget.lastTelemetryActive and widget.retainDisplay and os.clock() < widget.holdUntil then
		widget.value = widget.lastGoodValue
		widget.voltage = widget.lastGoodVoltage
		widget.cellCount = widget.lastGoodCellCount
		widget.consumption = widget.lastGoodConsumption or 0
		if widget.cellCount > 0 then
			widget.cellVoltage = widget.voltage / widget.cellCount
		else
			widget.cellVoltage = nil
		end

	-- Show "--" when telemetry is offline and summary expired
	elseif not widget.lastTelemetryActive then
		displayText = "--"

	-- Grace blinking period
	elseif inGrace(widget) then
		if widget.blinkOn then
			displayText = "--"
		else
			return
		end

	-- Telemetry active but required sensors are missing
	elseif not widget.sourceVoltage or not widget.sourceCharge or not widget.sourceCellCount or not widget.sourceConsumption then
		displayText = "Missing Sensor"
	end

	-- Fallback Text Drawing
	if displayText or (displayLine1 and displayLine2) then
		lcd.color(color)
		if displayText then
			local font, textW, textH = selectFont(widget, displayText, w, h)
			lcd.font(font)
			lcd.drawText((w - textW) / 2, (h - textH) / 2, displayText, BOLD)
		else
			local font1, line1W, line1H = selectFont(widget, displayLine1, w, h)
			local font2, line2W, line2H = selectFont(widget, displayLine2, w, h)
			local totalH = line1H + line2H + 4
			local yStart = (h - totalH) / 2

			lcd.font(font1)
			lcd.drawText((w - line1W) / 2, yStart, displayLine1, BOLD)

			lcd.font(font2)
			lcd.drawText((w - line2W) / 2, yStart + line1H + 4, displayLine2)
		end
		return
	end

	-- Battery Bar Drawing
	if widget.value == 0 and not widget.isDischargedPack and not widget.startingValue then
		lcd.color(lcd.RGB(255, 255, 255))
		local fallbackText = "--"
		local font, textW, textH = selectFont(widget, fallbackText, w, h)
		lcd.font(font)
		lcd.drawText((w - textW) / 2, (h - textH) / 2, fallbackText, BOLD)
		return
	end

	local fillColor
	if widget.isDischargedPack then
		fillColor = lcd.RGB(224, 0, 0)
	else
		if widget.value < 5 then
			fillColor = lcd.RGB(224, 0, 0)
		elseif widget.value < 20 then
			fillColor = lcd.RGB(255, 255, 0)
		else
			fillColor = lcd.RGB(0, 200, 0)
		end
	end
	lcd.color(fillColor)
	lcd.drawFilledRectangle(0, 0, math.floor(w * widget.value / 100), h)

	local pctAreaW = widget.showInfoBlock and math.floor(w * 0.60) or w - 20
	local pctText = widget.value .. "%"
	local font, pctW, pctH = selectFont(widget, pctText, pctAreaW, h - 10)
	local pctX = widget.showInfoBlock and math.floor((pctAreaW - pctW) / 2) or math.floor((w - pctW) / 2)

	lcd.font(font)
	if widget.value == 0 then
		lcd.color(lcd.RGB(255, 165, 0))
	else
		lcd.color(lcd.RGB(255, 255, 255))
	end
	lcd.drawText(pctX, (h - pctH) / 2, pctText, BOLD)

	-- Battery Info Block
	if widget.showInfoBlock then
		local infoW = math.floor(w * 0.40)
		local paddingX = 8
		local paddingY = 8
		local availableW = infoW - (2 * paddingX)
		local availableH = h - (2 * paddingY)

		local voltage = widget.voltage or 0
		local cellVoltage = widget.cellVoltage or 0
		local consumption = math.floor(widget.consumption + 0.5)
		local cellCount = widget.cellCount or 0

		local line1 = string.format("V: %.1f / C: %.2f", voltage, cellVoltage)
		local line2 = string.format("Used: %d mah (%dS)", consumption, cellCount)

		local font1, w1, h1 = selectFont(widget, line1, availableW, availableH / 2)
		local font2, w2, h2 = selectFont(widget, line2, availableW, availableH / 2)

		local totalH = h1 + h2 + 2
		local yStart = (h - totalH) / 2
		local infoX = w - infoW + paddingX
		local maxRight = w - 2 -- allows 2px margin from widget edge

		lcd.color(lcd.RGB(255, 255, 255))

		lcd.font(font1)
		lcd.drawText(math.min(infoX, maxRight - w1), yStart, line1, 0)

		lcd.font(font2)
		lcd.drawText(math.min(infoX, maxRight - w2), yStart + h1 + 2, line2, 0)
	end
end

-- === Main Runtime ===
local function wakeup(widget)
	local now = os.clock()

	-- Init telemetry sources
	if not widget.telemetrySource then
		widget.telemetrySource = system.getSource({ category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE })
	end
	if not widget.sourceVoltage then
		local candidates = {
			"Battery Voltage",  -- ELRS + RF Suite (occasionally used)
			"Main Voltage",     -- Sometimes used in custom telemetry mapping
			"VFAS",             -- FrSky SmartPort
			"Vfas",             -- Common FrSky variant
			"Voltage",          -- Generic fallback (typical name for it)
		}

		for _, name in ipairs(candidates) do
			local source = system.getSource({ category = CATEGORY_TELEMETRY, name = name })
			if source then
				widget.sourceVoltage = source
				break
			end
		end
	end
	if not widget.sourceCharge then
		widget.sourceCharge = system.getSource({ category = CATEGORY_TELEMETRY, name = "Charge Level" })
	end
	if not widget.sourceCellCount then
		widget.sourceCellCount = system.getSource({ category = CATEGORY_TELEMETRY, name = "Cell Count" })
	end
	if not widget.sourceConsumption then
		widget.sourceConsumption = system.getSource({ category = CATEGORY_TELEMETRY, name = "Consumption" })
	end

	local telemetryActive = widget.telemetrySource and widget.telemetrySource:state()

	-- Early return if telemetry is inactive
	if not telemetryActive then
		if widget.lastTelemetryActive and widget.hasTelemetryEverBeenActive then
			widget.retainDisplay = true
			widget.holdUntil = now + widget.maxHoldDuration
			lcd.invalidate()
		elseif widget.retainDisplay and now > widget.holdUntil then
			widget.retainDisplay = false
			widget.holdUntil = 0
			lcd.invalidate()
		end
		widget.lastTelemetryActive = false
		return
	end

	-- Telemetry detected
	if not widget.lastTelemetryActive then
		widget.telemetryReconnectTime = now
		widget.hasTelemetryEverBeenActive = true
		widget.doneVoltageCheck = false
		widget.graceUntil = now + GRACE_DELAY
		widget.voltageDialogDismissed = false
		widget.isDischargedPack = false
		widget.voltageDetected = false
		widget.audioReady = false
		widget.playedCallouts = {}
		widget.criticalPlayCount = 0
		widget.criticalLastPlayTime = 0
		widget.value = 0
		widget.voltage = 0
		widget.cellCount = 0
		widget.consumption = 0
		widget.lastGoodValue = 0
		widget.lastGoodVoltage = 0
		widget.lastGoodCellCount = 0
		widget.cellVoltage = nil
		widget.blinkOn = true
		widget.lastBlinkTime = now
		widget.blinkReadyTime = now + GRACE_BLINK_DELAY
		widget.startingValue = nil
	end

	-- Save telemetry state
	widget.lastTelemetryActive = true

	-- Handle blinking during grace
	if inGrace(widget) then
		if now > widget.blinkReadyTime and (now - widget.lastBlinkTime >= BLINK_INTERVAL) then
			widget.blinkOn = not widget.blinkOn
			widget.lastBlinkTime = now
			lcd.invalidate()
		end
		return -- Skip telemetry updates during grace period
	end

	-- After grace: ensure blinkOn is true
	if not widget.blinkOn then
		widget.blinkOn = true
		lcd.invalidate()
	end

	-- Define Cell Count based on telemetry (once per connection)
	local telemetryCount = (widget.sourceCellCount and widget.sourceCellCount:value()) or 0
	local fallbackCount = (widget.userCellCount) or 0
	local resolvedCount = (telemetryCount > 0) and telemetryCount or ((fallbackCount > 0) and fallbackCount or 0)

	if resolvedCount ~= widget.cellCount then
		widget.cellCount = resolvedCount
	end

	-- Read voltage
	local newVoltage = widget.sourceVoltage and widget.sourceVoltage:value()
	if newVoltage and newVoltage ~= widget.voltage then
		widget.voltage = newVoltage
	end

	-- Update cell voltage
	if widget.voltage and widget.cellCount > 0 then
		widget.cellVoltage = widget.voltage / widget.cellCount
	else
		widget.cellVoltage = nil
	end
	
	-- Pack detected
	if widget.voltage and widget.voltage > 2 then
		widget.voltageDetected = true
	end

	-- Read consumption telemetry (mAh used)
	local newConsumption = widget.sourceConsumption and widget.sourceConsumption:value()
	if newConsumption and newConsumption ~= widget.consumption then
		widget.consumption = newConsumption
	end
	
	-- Disable alerts when connected via USB or Battery disconnected
	if widget.cellCount == 0 or widget.voltage < 2 then
		widget.audioReady = false
		widget.value = 0
		widget.startingValue = nil
		lcd.invalidate()
		return
	end

	-- Battery Percentage Calculations
	local percent = computeRemaining(widget)

	if widget.doneVoltageCheck and percent ~= widget.value then
		widget.value = percent
		if widget.cellVoltage and widget.cellVoltage > 3.6 and widget.cellCount > 2 and widget.value > 0 then
			lcd.invalidate()
			checkAndPlayCallout(widget, percent)
		end
	end
	
	if percent > 0 and percent <= 100 and (now - widget.telemetryReconnectTime > 5) then
		widget.audioReady = true
	end

	-- Store last know good values for summary screen
	if widget.cellVoltage and widget.cellVoltage > 3.6 then
		widget.lastGoodValue = widget.value
		widget.lastGoodVoltage = widget.voltage
		widget.lastGoodCellCount = widget.cellCount
		widget.lastGoodConsumption = widget.consumption
	end

	-- Voltage-based discharge alert
	if not widget.doneVoltageCheck and not widget.voltageDialogDismissed then
		local t = now - widget.telemetryReconnectTime
		if t >= 15 and t <= 45 then
			if widget.distCheckEnabled and widget.cellVoltage <= widget.dischargedThreshold then
				widget.isDischargedPack = true

				if widget.audioEnabled then
					system.playHaptic(". . . .")
					system.playFile("/scripts/aerc/audio/dist-batt.wav", AUDIO_QUEUE)
				end

				form.openDialog({
					title = "RF Battery",
					message = string.format("Discharged Battery\n! Please Check !\n%.2fV Per Cell", widget.cellVoltage),
					width = 350,
					buttons = {
						{ label = "OK", action = function()
							widget.voltageDialogDismissed = true
							return true
						end }
					},
					options = TEXT_CENTER
				})
			end
			widget.doneVoltageCheck = true
		elseif t > 45 then
			widget.doneVoltageCheck = true
		end
	end	
end

-- === Configuration Form ===
local function configure(widget)
	-- Display & Audio Options Panel
	local displayPanel = form.addExpansionPanel("Display & Audio Options")
	displayPanel:open(false)

	-- Audio Option
	local line = displayPanel:addLine("Audio Alerts")
	form.addBooleanField(line, nil,
		function() return widget.audioEnabled end,
		function(value) widget.audioEnabled = value end)
	
	-- Show Background toggle
	local line = displayPanel:addLine("Use Ethos Background")
	form.addBooleanField(line, nil,
		function() return widget.useDefaultBackground end,
		function(value) widget.useDefaultBackground = value end)

	-- XXL Font toggle
	local line = displayPanel:addLine("Large Text Display")
		form.addBooleanField(line, nil,
		function() return widget.useXXLFont end,
		function(value) widget.useXXLFont = value end)

	-- Summary Display Duration
	local line = displayPanel:addLine("Summary Display Duration")
	form.addNumberField(line, nil, 5, 120,
		function() return widget.maxHoldDuration end,
		function(value) widget.maxHoldDuration = value end)

	-- Battery Info Enable/Disable
	local line = displayPanel:addLine("Show Battery Info Block")
	form.addBooleanField(line, nil,
		function() return widget.showInfoBlock end,
		function(value) widget.showInfoBlock = value end)
	
	-- Battery Behavior Panel
	local batteryPanel = form.addExpansionPanel("Battery Options")
	batteryPanel:open(false)

	local line = batteryPanel:addLine("Reserve Percent")
	local field = form.addNumberField(line, form.getFieldSlots(line)[0], 0, 50,
		function() return widget.newReserve end,
		function(value) widget.newReserve = value end)
	field:suffix("%")

	local line = batteryPanel:addLine("Use HV LiPo (4.30V Max)")
	form.addBooleanField(line, nil,
		function() return widget.useHvLipo end,
		function(value) widget.useHvLipo = value end)

	local line = batteryPanel:addLine("Discharged Battery Detection")
	form.addBooleanField(line, nil,
		function() return widget.distCheckEnabled end,
		function(value)
			widget.distCheckEnabled = value
			if widget.fieldDischargedVoltage then
				widget.fieldDischargedVoltage:enable(value)
			end
		end)

	local line = batteryPanel:addLine("Discharged Voltage - Per Cell")
	field = form.addNumberField(line, nil, 385, 430,
		function()
			local value = widget.newDischargedThreshold
			return math.floor(value * 100 + 0.5)
		end,
		function(value)
			widget.newDischargedThreshold = value / 100
			lcd.invalidate()
		end)
	field:decimals(2)
	field:suffix("V")
	field:enable(widget.distCheckEnabled)

	-- Cache the field to enable/disable dynamically
	widget.fieldDischargedVoltage = field

	-- Manual Cell Count Panel
	local manualPanel = form.addExpansionPanel("Manual Cell Count (Advanced)")
	manualPanel:open(false)

	manualPanel:addLine("Note: NOT RECOMMENDED")
	manualPanel:addLine("Use when Cell Count telemetry")
	manualPanel:addLine("isn't functional")

	local line = manualPanel:addLine("Fallback Cell Count")
	field = form.addNumberField(line, form.getFieldSlots(line)[0], 0, 14,
		function() return widget.newUserCellCount end,
		function(value) widget.newUserCellCount = value end)
	field:suffix("S")
	field:step(1)
end

-- === Read Function ===
local function read(widget)
	widget.audioEnabled = storage.read("audioEnabled")
	widget.useDefaultBackground = storage.read("useDefaultBackground")
	widget.useXXLFont = storage.read("useXXLFont")
	widget.maxHoldDuration = storage.read("maxHoldDuration")
	widget.showInfoBlock = storage.read("showInfoBlock")
	widget.distCheckEnabled = storage.read("distCheckEnabled")
	widget.useHvLipo = storage.read("useHvLipo")
	widget.reservePercent = storage.read("reservePercent")
	widget.newReserve = widget.reservePercent
	widget.dischargedThreshold = storage.read("dischargedThreshold")
	widget.newDischargedThreshold = widget.dischargedThreshold
	widget.userCellCount = storage.read("userCellCount")
	widget.newUserCellCount = widget.userCellCount
end


-- === Write Function ===
local function write(widget)
	storage.write("audioEnabled", widget.audioEnabled)
	storage.write("useDefaultBackground", widget.useDefaultBackground)
	storage.write("useXXLFont", widget.useXXLFont)
	storage.write("maxHoldDuration", widget.maxHoldDuration)
	storage.write("showInfoBlock", widget.showInfoBlock)
	storage.write("distCheckEnabled", widget.distCheckEnabled)
	storage.write("useHvLipo", widget.useHvLipo)
	storage.write("reservePercent", widget.newReserve)
	widget.reservePercent = widget.newReserve
	storage.write("dischargedThreshold", widget.newDischargedThreshold)
	widget.dischargedThreshold = widget.newDischargedThreshold
	storage.write("userCellCount", widget.newUserCellCount)
	widget.userCellCount = widget.newUserCellCount
end

-- === Return Widget Table ===
return {
	create = create,
	paint = paint,
	wakeup = wakeup,
	configure = configure,
	read = read,
	write = write,
	persistent = true
}
