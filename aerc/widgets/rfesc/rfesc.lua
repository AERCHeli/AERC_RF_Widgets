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

-- RF Widgets - Rotorflight & ETHOS
-- Author: Andy.E (Discord: AJ#9381)
-- Version: 1.0
-- Widget Name: RF ESC Temp

-- === Global Settings ===
local GRACE_DELAY = 15 -- Time (seconds) to blink before showing real ESC temp after telemetry connected
local ALERT_INTERVAL = 10 -- Minimum seconds between repeating alerts
local BLINK_INTERVAL = 0.5 -- Blinking toggle interval (seconds)
local GRACE_BLINK_DELAY = 2 -- Delay before blinking starts after telemetry connect

-- === Widget Creation ===
local function create()
	local now = os.clock()
	return {
		telemetrySource = nil, -- Telemetry active source
		escTempSource = nil, -- ESC Temp telemetry source
		escTemp = nil, -- Latest ESC Temp value
		lastAlertTimeHot = 0, -- Last time hot alert played
		lastAlertTimeCrit = 0, -- Last time critical alert played
		lastTelemetryActive = false, -- Last known telemetry active state
		graceUntil = 0,	-- Time until grace period ends
		blinkOn = true,	-- Blinking state flag
		lastBlinkTime = now, -- Last time blink toggled
		blinkReadyTime = now + GRACE_BLINK_DELAY, -- Time when blinking should start
		audioEnabled = true, -- Audio state
		useDefaultBackground = false, -- Default to Black background
		useXXLFont = false, -- Enable XXL font
		unitDisplayMode = 2, -- 1=Off, 2=°C, 3=°F
		newUnitDisplayMode = 2, -- used in config form
		lastUnitMode = 2, -- tracks previous value for toggle logic
		warningTemp = 70, -- Yellow threshold (warning)
		criticalTemp= 90, -- Red threshold (critical)
		hasTelemetryEverBeenActive = false, -- Tracks if telemetry was ever active
		holdMaxUntil = 0, -- Time to hold max temp after loss
		maxEscTemp = nil, -- Highest ESC temp seen during flight
		showingMaxAfterLoss = false, -- Displaying max after telemetry loss
		maxHoldDuration = 30, -- Seconds to show max after telemetry loss
	}
end

-- Returns true if still within the grace delay period after reconnect
local function inGrace(widget)
	return os.clock() < (widget.graceUntil or 0)
end

-- === Display Drawing ===						  
local function paint(widget)
	local w, h = lcd.getWindowSize()
	local mainText = "--"
	local subText = nil
	local color = lcd.RGB(255, 255, 255)

	-- Function to select the largest fitting font with padding
	local function selectFont(text, maxWidth, maxHeight)
		local fontPaddingW = 8
		local fontPaddingH = 8
		local stripped = text:gsub("°", "") -- Remove ° from width calculation
		local fonts = widget.useXXLFont and { FONT_XXL, FONT_XL, FONT_L, FONT_M, FONT_S } or { FONT_XL, FONT_L, FONT_M, FONT_S }
		for _, font in ipairs(fonts) do
			lcd.font(font)
			local textW, textH = lcd.getTextSize(stripped)
			if textW <= (maxWidth - fontPaddingW) and textH <= (maxHeight - fontPaddingH) then
				return font, textW, textH
			end
		end
		lcd.font(FONT_S)
		local textW, textH = lcd.getTextSize(stripped)
		return FONT_S, textW, textH
	end

	-- Draw background
	if not widget.useDefaultBackground then
		lcd.color(lcd.RGB(0, 0, 0))
		lcd.drawFilledRectangle(0, 0, w, h)
	end

	-- Show max ESC temp for the configured duration after telemetry loss
	if not widget.lastTelemetryActive and widget.showingMaxAfterLoss and widget.maxEscTemp then
		local value = math.floor(widget.maxEscTemp + 0.5)
		local suffix = (widget.unitDisplayMode == 2 and " °C")
			or (widget.unitDisplayMode == 3 and " °F")
			or ""
		mainText = string.format("%d%s", value, suffix)
		subText = "Max Temp"
		color = lcd.RGB(255, 165, 0)
	end

	-- When telemetry active, apply appropriate text to display
	if widget.lastTelemetryActive then
		if not widget.escTempSource then
			mainText = "Missing Sensor"
		elseif inGrace(widget) then
			if not widget.blinkOn then return end
			mainText = "--"
		elseif widget.escTemp then
			local value = math.floor(widget.escTemp + 0.5)
			local suffix = (widget.unitDisplayMode == 2 and " °C")
				or (widget.unitDisplayMode == 3 and " °F")
				or ""
			mainText = string.format("%d%s", value, suffix)

			if value < widget.warningTemp then
				color = lcd.RGB(0, 255, 0) -- Green
			elseif value <= widget.criticalTemp then
				color = lcd.RGB(255, 165, 0) -- Orange
			else
				color = lcd.RGB(255, 0, 0) -- Red
			end
		end
	end

	-- Choose best font and size
	if mainText then
		if subText then
			-- Subtext ("Max") in top third
			local subFont, subW, subH = selectFont(subText, w, h / 3)
			lcd.font(subFont)
			lcd.color(lcd.RGB(255, 255, 255))
			lcd.drawText((w - subW) / 2, h / 6 - subH / 2, subText)

			-- Main text in bottom 2/3
			local mainFont, mainW, mainH = selectFont(mainText, w, h * 2 / 3)
			lcd.font(mainFont)
			lcd.color(color)
			lcd.drawText((w - mainW) / 2, h / 2 + (h / 3 - mainH) / 2, mainText)
		else
			-- Normal text centered in full area
			local font, textW, textH = selectFont(mainText, w, h)
			lcd.font(font)
			lcd.color(color)
			lcd.drawText((w - textW) / 2, (h - textH) / 2, mainText, BOLD)
		end
	end
end

-- === Main Runtime ===
local function wakeup(widget)
	local now = os.clock()

	-- Init telemetry sources
	if not widget.telemetrySource then
		widget.telemetrySource = system.getSource({ category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE })
	end
	if not widget.escTempSource then
		local candidates = {
			"ESC1 Temp",    -- ELRS + RF Suite
			"ESC Temp",     -- General fallback
			"Tmp1",         -- FrSky SmartPort / FPort mapped
			"Tmp2"          -- Alternate FrSky temp
		}

		for _, name in ipairs(candidates) do
			local source = system.getSource({ category = CATEGORY_TELEMETRY, name = name })
			if source then
				widget.escTempSource = source
				break
			end
		end
	end

	local telemetryActive = widget.telemetrySource and widget.telemetrySource:state()

	-- Early return if telemetry is inactive
	if not telemetryActive then
		if widget.lastTelemetryActive and widget.hasTelemetryEverBeenActive then
			widget.holdMaxUntil = now + (widget.maxHoldDuration or 30)
			widget.showingMaxAfterLoss = true
			lcd.invalidate()
		elseif widget.showingMaxAfterLoss and now > widget.holdMaxUntil then
			widget.showingMaxAfterLoss = false
			lcd.invalidate()
		end
		widget.lastTelemetryActive = false
		return
	end

	-- Telemetry detected
	if not widget.lastTelemetryActive then
		widget.escTemp = nil
		widget.graceUntil = now + GRACE_DELAY
		widget.blinkOn = true
		widget.lastBlinkTime = now
		widget.blinkReadyTime = now + GRACE_BLINK_DELAY
		widget.maxEscTemp = nil
		widget.showingMaxAfterLoss = false
		widget.hasTelemetryEverBeenActive = true
		widget.lastAlertTimeHot = 0
		widget.lastAlertTimeCrit = 0
		widget.lastTelemetryActive = true
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
	end

	-- Update ESC Temp and track max
	if widget.escTempSource then
		local val = widget.escTempSource:value()
		if val then
			widget.escTemp = val
			if not widget.maxEscTemp or val > widget.maxEscTemp then
				widget.maxEscTemp = val
			end
			lcd.invalidate()
		end
	end

	-- Alert logic
	if widget.audioEnabled and widget.escTemp then
		if widget.escTemp > widget.criticalTemp then
			if now - widget.lastAlertTimeCrit >= ALERT_INTERVAL then
				system.playFile("/scripts/aerc/audio/esc-crit.wav", AUDIO_QUEUE)
				system.playHaptic(". . .")
				widget.lastAlertTimeCrit = now
			end
		elseif widget.escTemp > widget.warningTemp then
			if now - widget.lastAlertTimeHot >= ALERT_INTERVAL then
				system.playFile("/scripts/aerc/audio/esc-warn.wav", AUDIO_QUEUE)
				widget.lastAlertTimeHot = now
			end
		end
	end
end

-- === Configuration Form ===
local function configure(widget)
	-- Display & Audio Options Panel
	local displayPanel = form.addExpansionPanel("Display & Audio Options")
	displayPanel:open(false)
	
	-- Audio Alerts toggle
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
		
	-- Show Unit Suffix toggle
	local line = displayPanel:addLine("Show Unit Suffix")
	form.addBooleanField(line, nil,
		function() return widget.newUnitDisplayMode ~= 1 end,
		function(value)
			if value then
				widget.newUnitDisplayMode = widget.lastUnitMode or 2
			else
				widget.lastUnitMode = widget.newUnitDisplayMode
				widget.newUnitDisplayMode = 1
			end
			widget.unitDisplayMode = widget.newUnitDisplayMode

			-- Update temp suffixes
			local suffix = (widget.unitDisplayMode == 3) and "°F" or "°C"
			if widget.fieldWarningTemp then widget.fieldWarningTemp:suffix(suffix) end
			if widget.fieldCriticalTemp then widget.fieldCriticalTemp:suffix(suffix) end

			-- Enable/disable unit dropdown
			if widget.fieldUnitChoice then
				widget.fieldUnitChoice:enable(widget.unitDisplayMode ~= 1)
			end

			lcd.invalidate()
		end)

	-- Temp Unit dropdown (enabled only when suffix is on)
	local line = displayPanel:addLine("Temp Unit")
	displayModes = {{ "Celsius (°C)", 2 },{ "Fahrenheit (°F)", 3 }}
	field = form.addChoiceField(line, nil,
		displayModes,
		function() return widget.unitDisplayMode == 3 and 3 or 2 end,
		function(value)
			widget.lastUnitMode = value
			if widget.unitDisplayMode ~= 1 then
				widget.unitDisplayMode = value
				widget.newUnitDisplayMode = value
			end
			local suffix = (value == 3) and "°F" or "°C"
			if widget.fieldWarningTemp then widget.fieldWarningTemp:suffix(suffix) end
			if widget.fieldCriticalTemp then widget.fieldCriticalTemp:suffix(suffix) end
			lcd.invalidate()
		end)
	field:enable(widget.unitDisplayMode ~= 1)
	widget.fieldUnitChoice = field

	-- Warning Temp
	local line = displayPanel:addLine("Warning Temp")
	widget.fieldWarningTemp = form.addNumberField(line, nil, 30, 300,
		function() return widget.warningTemp end,
		function(value) widget.warningTemp = value end)
	widget.fieldWarningTemp:suffix(widget.newUnitDisplayMode == 3 and "°F" or "°C")

	-- Critical Temp
	local line = displayPanel:addLine("Critical Temp")
	widget.fieldCriticalTemp = form.addNumberField(line, nil, 30, 300,
		function() return widget.criticalTemp end,
		function(value) widget.criticalTemp = value end)
	widget.fieldCriticalTemp:suffix(widget.newUnitDisplayMode == 3 and "°F" or "°C")
end

-- === Read Function ===
local function read(widget)
	widget.audioEnabled = storage.read("audioEnabled")
	widget.useDefaultBackground = storage.read("useDefaultBackground")
	widget.useXXLFont = storage.read("useXXLFont")
	widget.maxHoldDuration = storage.read("maxHoldDuration")
	widget.unitDisplayMode = storage.read("unitDisplayMode")
	widget.newUnitDisplayMode = widget.unitDisplayMode
	widget.lastUnitMode = widget.unitDisplayMode
	widget.warningTemp = storage.read("warningTemp")
	widget.criticalTemp = storage.read("criticalTemp")
end

-- === Write Function ===
local function write(widget)
	storage.write("audioEnabled", widget.audioEnabled)
	storage.write("useDefaultBackground", widget.useDefaultBackground)
	storage.write("useXXLFont", widget.useXXLFont)
	storage.write("maxHoldDuration", widget.maxHoldDuration)
	storage.write("unitDisplayMode", widget.unitDisplayMode)
	storage.write("warningTemp", widget.warningTemp)
	storage.write("criticalTemp", widget.criticalTemp)
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
