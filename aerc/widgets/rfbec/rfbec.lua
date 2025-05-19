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
-- Widget Name: RF BEC Voltage

-- === Global Settings ===
local GRACE_DELAY = 15 -- Time (seconds) to blink before showing real BEC Voltage after telemetry connected
local ALERT_INTERVAL = 10 -- Minimum seconds between repeating alerts
local BLINK_INTERVAL = 0.5 -- Blinking toggle interval (seconds)
local GRACE_BLINK_DELAY = 2	-- Delay before blinking starts after telemetry connect

-- === Widget Creation ===
local function create()
	local now = os.clock()
	return {
		telemetrySource = nil, -- Telemetry active source
		becVoltageSource = nil, -- BEC voltage telemetry source
		becVoltage = nil, -- Latest BEC Voltage value
		lastAlertTime = 0, -- Last time an alert was played
		lastTelemetryActive = false, -- Last known telemetry active state
		graceUntil = 0, -- Time until grace period ends
		blinkOn = true, -- Blinking state flag
		lastBlinkTime = now, -- Last time blink toggled
		blinkReadyTime = now + GRACE_BLINK_DELAY, -- Time when blinking should start
		throttleSwitch = nil, -- No throttle switch assigned by default
		becalertThreshold = 6.7, -- Current threshold
		newbecalertThreshold = 6.7, -- Editable in config form
		audioEnabled = true, -- Audio state
		useDefaultBackground = false, -- Default to Black background
		useXXLFont = false, -- Enable XXL font
		showVoltageSuffix = true, -- Show "V" after voltage
		audioActive = false, -- Audio will activate only if BEC voltage > 2V and audio is enabled
	}
end

-- Returns true if still within the grace delay period after reconnect
local function inGrace(widget)
	return os.clock() < (widget.graceUntil or 0)
end

-- === Display Drawing ===
local function paint(widget)
	local w, h = lcd.getWindowSize()
	local displayText = "--"
	local subText = nil
	local color = lcd.RGB(255, 255, 255)

	-- Function to select the largest fitting font with padding
	local function selectFont(text, maxWidth, maxHeight)
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

	-- Draw background
	if not widget.useDefaultBackground then
		lcd.color(lcd.RGB(0, 0, 0))
		lcd.drawFilledRectangle(0, 0, w, h)
	end

	-- When telemetry active, apply appropriate text to display
	if widget.lastTelemetryActive then
		if not widget.becVoltageSource then
			displayText = "Missing Sensor"
		elseif inGrace(widget) then
			if not widget.blinkOn then return end
			displayText = "--"
		elseif widget.becVoltage then
			local v = math.floor(widget.becVoltage * 10 + 0.5) / 10
			local suffix = widget.showVoltageSuffix and " V" or ""
			displayText = string.format("%.1f%s", v, suffix)
			local threshold = widget.becalertThreshold or 6.7
			color = (v >= threshold) and lcd.RGB(0, 255, 0) or lcd.RGB(255, 0, 0)
		end
	end

	-- Show subtext if audio enabled but switch is not configured
	if widget.audioEnabled and type(widget.throttleSwitch) ~= "userdata" then
		subText = "No Switch"
	end

	-- Reserve space for subtext if present
	local subH = 0
	if subText then
		lcd.font(FONT_S)
		_, subH = lcd.getTextSize(subText)
	end

	local bottomMargin = subH > 0 and (subH + 4) or 0
	local availableHeight = h - bottomMargin

	-- Draw main display text
	if displayText then
		local font, textW, textH = selectFont(displayText, w, availableHeight)
		local textY = math.max(0, (availableHeight - textH) / 2)
		lcd.font(font)
		lcd.color(color)
		lcd.drawText((w - textW) / 2, textY, displayText, BOLD)
	end

	-- Draw subtext at bottom
	if subText then
		local subFont, subW, subH = selectFont(subText, w, h / 4)
		local subY = h - subH
		if subY < 0 then subY = 0 end
		lcd.font(subFont)
		lcd.color(lcd.RGB(255, 100, 100))
		lcd.drawText((w - subW) / 2, subY, subText)
	end
end

-- === Main Runtime ===
local function wakeup(widget)
	local now = os.clock()

	-- Init telemetry sources
	if not widget.telemetrySource then
		widget.telemetrySource = system.getSource({ category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE })
	end
	if not widget.becVoltageSource then
		widget.becVoltageSource = system.getSource({ category = CATEGORY_TELEMETRY, name = "BEC Voltage" })
	end

	local telemetryActive = widget.telemetrySource and widget.telemetrySource:state()

	-- Early return if telemetry is inactive
	if not telemetryActive then
		if widget.lastTelemetryActive then
		end
		widget.lastTelemetryActive = false
		return
	end

	-- Telemetry detected
	if not widget.lastTelemetryActive then
		widget.becVoltage = nil
		widget.graceUntil = now + GRACE_DELAY
		widget.lastAlertTime = 0
		widget.blinkOn = true
		widget.lastBlinkTime = now
		widget.blinkReadyTime = now + GRACE_BLINK_DELAY
		widget.audioActive = false
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

	-- Update BEC Voltage
	if widget.becVoltageSource then
		local val = widget.becVoltageSource:value()
		if val and val ~= widget.becVoltage then
			widget.becVoltage = val
			lcd.invalidate()
		end
	end

	-- Enable or disable audio alerts based on throttle switch state
	if widget.audioEnabled and type(widget.throttleSwitch) == "userdata" then
		if widget.throttleSwitch:state() then
			widget.audioActive = true
		else
			widget.audioActive = false
		end
	else
		widget.audioActive = false
	end

	-- Alert logic
	if widget.audioActive and widget.becalertThreshold and widget.becVoltage < (widget.becalertThreshold - 0.1)
		and (now - widget.lastAlertTime >= ALERT_INTERVAL) then
		system.playFile("/scripts/aerc/audio/bec-voltage.wav", AUDIO_QUEUE)
		system.playHaptic(". . .")
		widget.lastAlertTime = now
	end
end   

-- === Configuration Form ===
local function configure(widget)
	-- Display & Audio Options Panel
	local displayPanel = form.addExpansionPanel("Display & Audio Options")
	displayPanel:open(false)

	-- Show Border toggle
	local line = displayPanel:addLine("Show Border")
	form.addBooleanField(line, nil,
		function() return widget.showBorder end,
		function(value) widget.showBorder = value end)

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

	-- Show Voltage Suffix toggle
	local line = displayPanel:addLine("Show Voltage Suffix")
	form.addBooleanField(line, nil,
		function() return widget.showVoltageSuffix end,
		function(value)
			widget.showVoltageSuffix = value
			lcd.invalidate()
		end)

	-- Audio Alerts toggle
	local line = displayPanel:addLine("Audio Alerts")
	form.addBooleanField(line, nil,
		function() return widget.audioEnabled end,
		function(value)
			widget.audioEnabled = value
			if widget.fieldAlertVoltage then
				widget.fieldAlertVoltage:enable(value)
			end
			if widget.fieldThrottleSwitch then
				widget.fieldThrottleSwitch:enable(value)
			end
			lcd.invalidate()
		end)
	
	-- Motor On Switch field (enabled only when audio is enabled)
	local line = displayPanel:addLine("Motor On Switch")
	local field = form.addSwitchField(line, nil,
		function() return widget.throttleSwitch end,
		function(value) widget.throttleSwitch = value end)
	field:enable(widget.audioEnabled)
	widget.fieldThrottleSwitch = field
		
	-- BEC Alert Voltage field (1 decimal precision, dynamic enable)
	local line = displayPanel:addLine("BEC Alert Voltage (Threshold)")
	local field = form.addNumberField(line, nil, 30, 100,
		function()
			local v = widget.newbecalertThreshold or 6.7
			return math.floor(v * 10 + 0.5)
		end,
		function(v)
			widget.newbecalertThreshold = v / 10
		end)
	field:decimals(1)
	field:suffix("V")
	field:enable(widget.audioEnabled)
	widget.fieldAlertVoltage = field	
end


-- === Read Function ===
local function read(widget)
	widget.useDefaultBackground = storage.read("useDefaultBackground")
	widget.useXXLFont = storage.read("useXXLFont")
	widget.showVoltageSuffix = storage.read("showVoltageSuffix")
	widget.audioEnabled = storage.read("audioEnabled")
	widget.throttleSwitch = storage.read("throttleSwitch")
	widget.becalertThreshold = storage.read("becalertThreshold")
	widget.newbecalertThreshold = widget.becalertThreshold
end

-- === Write Function ===
local function write(widget)
	storage.write("useDefaultBackground", widget.useDefaultBackground)
	storage.write("useXXLFont", widget.useXXLFont)
	storage.write("showVoltageSuffix", widget.showVoltageSuffix)
	storage.write("audioEnabled", widget.audioEnabled)
	storage.write("throttleSwitch", widget.throttleSwitch)
	storage.write("becalertThreshold", widget.newbecalertThreshold)
	widget.becalertThreshold = widget.newbecalertThreshold
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
