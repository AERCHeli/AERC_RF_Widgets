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
-- Widget Name: AERC Altitude

-- === Global Settings ===
local GRACE_DELAY = 15 -- Time (seconds) to blink before showing real Altitude after telemetry connected
local BLINK_INTERVAL = 0.5 -- Blinking toggle interval (seconds)
local GRACE_BLINK_DELAY = 2 -- Delay before blinking starts after telemetry connect

-- === Widget Creation ===
local function create()
	local now = os.clock()
	return {
		telemetrySource = nil, -- Telemetry active source
		altitudeSource = nil, -- Altitude telemetry source
		altitude = nil, -- Latest Altitude value
		lastTelemetryActive = false, -- Last known telemetry active state
		graceUntil = 0, -- Time until grace period ends
		blinkOn = true, -- Blinking state flag
		lastBlinkTime = now, -- Last time blink toggled
		blinkReadyTime = now + GRACE_BLINK_DELAY, -- Time when blinking should start
		useDefaultBackground = false, -- Default to Black background
		showAltSuffix = true, -- Toggle suffix on or off
		altitudeSuffix = "", -- Cached suffix
		lastUnitSuffix = nil, -- Tracks last telemetry unit for suffix redraw
		useXXLFont = false, -- Enable XXL font
		hasTelemetryEverBeenActive = false, -- Tracks if telemetry was ever active
		holdMaxUntil = 0, -- Time to hold max altitude after loss
		maxAltitude = nil, -- Highest altitude seen during flight
		showingMaxAfterLoss = false, -- Displaying max after telemetry loss
		maxHoldDuration = 30, -- Seconds to show max altitude after telemetry loss
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

	-- Show max altitude for the configured duration after telemetry loss
	if not widget.lastTelemetryActive and widget.showingMaxAfterLoss and widget.maxAltitude then
		local value = math.floor(widget.maxAltitude * 10 + 0.5) / 10
		local suffix = widget.showAltSuffix and widget.altitudeSuffix or ""
		mainText = string.format("%.1f%s", value, suffix)
		subText = "Max Alt"
		color = lcd.RGB(255, 165, 0)
	end

	-- When telemetry active, apply appropriate text to display
	if widget.lastTelemetryActive then
		if not widget.altitudeSource then
			mainText = "Missing Sensor"
		elseif inGrace(widget) then
			if not widget.blinkOn then return end
			mainText = "--"
		elseif widget.altitude then
			local value = math.floor(widget.altitude * 10 + 0.5) / 10
			local suffix = widget.showAltSuffix and widget.altitudeSuffix or ""
			mainText = string.format("%.1f%s", value, suffix)
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
	if not widget.altitudeSource then
		widget.altitudeSource = system.getSource({ category = CATEGORY_TELEMETRY, name = "Altitude" })
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
		widget.altitude = nil
		widget.lastUnitSuffix = nil
		widget.graceUntil = now + GRACE_DELAY
		widget.blinkOn = true
		widget.lastBlinkTime = now
		widget.blinkReadyTime = now + GRACE_BLINK_DELAY
		widget.maxAltitude = nil
		widget.showingMaxAfterLoss = false
		widget.hasTelemetryEverBeenActive = true
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

	-- After telemetry is valid and after grace:
	if widget.lastTelemetryActive and widget.altitudeSource then
		local unit = widget.altitudeSource:unit()
		if unit == UNIT_METER then
			widget.altitudeSuffix = " m"
		elseif unit == UNIT_FOOT then
			widget.altitudeSuffix = " ft"
		else
			widget.altitudeSuffix = ""
		end
		lcd.invalidate()
	end

	-- Update Altitude
	if widget.altitudeSource then
		local val = widget.altitudeSource:value()
		if val then
			widget.altitude = val
			if not widget.maxAltitude or val > widget.maxAltitude then
				widget.maxAltitude = val
			end
			lcd.invalidate()
		end
	end

	-- Update display if telemetry sensor unit is changed
	if widget.altitudeSource and widget.showAltSuffix then
		local currentUnit = widget.altitudeSource:unit()
		if currentUnit ~= widget.lastUnitSuffix then
			widget.lastUnitSuffix = currentUnit
			if currentUnit == UNIT_METER then
				widget.altitudeSuffix = " m"
			elseif currentUnit == UNIT_FOOT then
				widget.altitudeSuffix = " ft"
			else
				widget.altitudeSuffix = ""
			end
			lcd.invalidate()
		end
	end	
end

-- === Configuration Form ===
local function configure(widget)
	-- Display Options Panel
	local displayPanel = form.addExpansionPanel("Display Options")
	displayPanel:open(false)

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
	local line = displayPanel:addLine("Show Altitude Suffix")
	form.addBooleanField(line, nil,
		function() return widget.showAltSuffix end,
		function(value) widget.showAltSuffix = value lcd.invalidate() end)
end

-- === Read Function ===
local function read(widget)
	widget.useDefaultBackground = storage.read("useDefaultBackground")
	widget.useXXLFont = storage.read("useXXLFont")
	widget.maxHoldDuration = storage.read("maxHoldDuration")
	widget.showAltSuffix = storage.read("showAltSuffix")
end

-- === Write Function ===
local function write(widget)
	storage.write("useDefaultBackground", widget.useDefaultBackground)
	storage.write("useXXLFont", widget.useXXLFont)
	storage.write("maxHoldDuration", widget.maxHoldDuration)
	storage.write("showAltSuffix", widget.showAltSuffix)
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
