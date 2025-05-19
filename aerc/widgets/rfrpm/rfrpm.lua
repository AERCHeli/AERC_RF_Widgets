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
-- Widget Name: RF RPM

-- === Global Settings ===
local GRACE_DELAY = 15 -- Time (seconds) to blink before showing real BEC Voltage after telemetry connected
local BLINK_INTERVAL = 0.5 -- Blinking toggle interval (seconds)
local GRACE_BLINK_DELAY = 2	-- Delay before blinking starts after telemetry connect

-- === Widget Creation ===
local function create()
	local now = os.clock()
	return {
		telemetrySource = nil, -- Telemetry active source
		rpmSource = nil, -- RPM voltage telemetry source
		rpm = nil, -- Latest RPM value
		lastTelemetryActive = false, -- Last known telemetry active state
		graceUntil = 0, -- Time until grace period ends
		blinkOn = true, -- Blinking state flag
		lastBlinkTime = now, -- Last time blink toggled
		blinkReadyTime = now + GRACE_BLINK_DELAY, -- Time when blinking should start
		minRpm = 1500, -- Current threshold
		showRpmSuffix = false, -- Show "RPM" suffix after value
		useDefaultBackground = false, -- Default to Black background
		useXXLFont = false, -- Enable XXL font
		hasTelemetryEverBeenActive = false, -- Tracks if telemetry was ever active
		holdMaxUntil = 0, -- Time to hold max RPM after telemetry loss
		maxRpm = nil, -- Highest RPM seen during flight
		showingMaxAfterLoss = false, -- Displaying max after telemetry loss
		maxHoldDuration = 30, -- Seconds to show max RPM after telemetry loss
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

	-- Show max RPM for the configured duration after telemetry loss
	if not widget.lastTelemetryActive and widget.showingMaxAfterLoss and widget.maxRpm then
		local value = math.floor(widget.maxRpm + 0.5)
		local suffix = widget.showRpmSuffix and " RPM" or ""
		mainText = string.format("%d%s", value, suffix)
		subText = "Max RPM"
		color = lcd.RGB(255, 165, 0)
	end

	-- When telemetry active, apply appropriate text to display
	if widget.lastTelemetryActive then
		if not widget.rpmSource then
			mainText = "Missing Sensor"
		elseif inGrace(widget) then
			if not widget.blinkOn then return end
			mainText = "--"
		elseif widget.rpm then
			local value = math.floor(widget.rpm + 0.5)
			local suffix = widget.showRpmSuffix and " RPM" or ""
			mainText = string.format("%d%s", value, suffix)
			color = (value < widget.minRpm) and lcd.RGB(255, 0, 0) or lcd.RGB(0, 255, 0)
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
	if not widget.rpmSource then
		widget.rpmSource = system.getSource({ category = CATEGORY_TELEMETRY, name = "Headspeed" })
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
		widget.rpm = nil
		widget.graceUntil = now + GRACE_DELAY
		widget.blinkOn = true
		widget.lastBlinkTime = now
		widget.blinkReadyTime = now + GRACE_BLINK_DELAY
		widget.maxRpm = nil
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

	-- Update RPM and track max
	if widget.rpmSource then
		local val = widget.rpmSource:value()
		if val then
			widget.rpm = val
			if not widget.maxRpm or val > widget.maxRpm then
				widget.maxRpm = val
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
	local line = displayPanel:addLine("Max RPM Display Duration")
	form.addNumberField(line, nil, 5, 120,
		function() return widget.maxHoldDuration end,
		function(value) widget.maxHoldDuration = value end)
		
	-- Show RPM Suffix toggle
	local line = displayPanel:addLine("Show RPM Suffix")
	form.addBooleanField(line, nil,
		function() return widget.showRpmSuffix end,
		function(value) widget.showRpmSuffix = value lcd.invalidate() end)

	-- Minimum RPM setting
	local line = displayPanel:addLine("Minimum RPM (Red Below)")
	field = form.addNumberField(line, nil, 500, 8000,
		function() return widget.minRpm end,
		function(value) widget.minRpm = value end)
	field:suffix("RPM")
end

-- === Read Function ===
local function read(widget)
	widget.useDefaultBackground = storage.read("useDefaultBackground")
	widget.useXXLFont = storage.read("useXXLFont")
	widget.maxHoldDuration = storage.read("maxHoldDuration")
	widget.showRpmSuffix = storage.read("showRpmSuffix")
	widget.minRpm = storage.read("minRpm")
end

-- === Write Function ===
local function write(widget)
	storage.write("useDefaultBackground", widget.useDefaultBackground)
	storage.write("useXXLFont", widget.useXXLFont)
	storage.write("maxHoldDuration", widget.maxHoldDuration)
	storage.write("showRpmSuffix", widget.showRpmSuffix)
	storage.write("minRpm", widget.minRpm)	
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
