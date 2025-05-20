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
-- Widget Name: AERC Flights

-- === Global Settings ===
local GRACE_DELAY = 15 -- Time (seconds) to blink before showing total flights after telemetry connect
local BLINK_INTERVAL = 0.5 -- Blinking toggle interval (seconds)
local GRACE_BLINK_DELAY = 2 -- Delay before blinking starts after telemetry connect

-- IO helper
local rfflyio = require("lib.rfflyio")

-- === Widget Creation ===
local function create()
	local now = os.clock()
	return {
		telemetrySource = nil, -- Telemetry active source
		lastTelemetryActive = false, -- Last known telemetry active state
		graceUntil = 0, -- Time until grace period ends
		newPreset = 0, -- Editable preset value (for configuration form)
		delayStart = 0, -- Timestamp when throttle switch engagement started
		drawState = "white", -- Current visual draw state ("white", "yellow", "green")
		settingsLoaded = false, -- Load model specific settings
		dateFormat = 1, -- 1 = DD-MM-YYYY default
		blinkOn = true, -- Blinking state flag
		lastBlinkTime = now, -- Last time blink toggled
		blinkReadyTime = now + GRACE_BLINK_DELAY, -- Time when blinking should start
		flightsSincePreset = 0, -- Flights recorded since preset was set
		totalFlights = 0, -- Computed total flights (preset + flightsSincePreset)
		flightLogged = false, -- Flag indicating if a flight was just logged (prevents double logging)
		switchEngaged = false, -- Throttle switch engagement status (prevents multiple counts per switch activation)
		useDefaultBackground = false, -- Default to Black background
		useXXLFont = false, -- Enable XXL font
		throttleSwitch = nil, -- No throttle switch assigned by default
		delayValue = 25, -- Delay (seconds) before counting a flight after switch activation
		preset = 0, -- Saved preset flight count baseline
		holdUntil = 0, -- Time to retain flight count after telemetry loss
		retainDisplay = false, -- Whether to draw last known value during hold
		maxHoldDuration = 30, -- Configurable hold duration
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
	if widget.lastTelemetryActive or (widget.retainDisplay and os.clock() < widget.holdUntil) then
		if inGrace(widget) then
			if not widget.blinkOn then return end
			displayText = "--"
		elseif widget.settingsLoaded or (widget.retainDisplay and os.clock() < widget.holdUntil) then
			displayText = tostring(widget.totalFlights)

			if widget.drawState == "green" then
				color = lcd.RGB(0, 255, 0)
			elseif widget.drawState == "yellow" then
				color = lcd.RGB(255, 255, 0)
			end
		end
	end

	-- Show subtext if switch is not configured
	if type(widget.throttleSwitch) ~= "userdata" then
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

	-- Init telemetry source
	if not widget.telemetrySource then
		widget.telemetrySource = system.getSource({ category = CATEGORY_SYSTEM_EVENT, member = TELEMETRY_ACTIVE })
	end

	local telemetryActive = widget.telemetrySource and widget.telemetrySource:state()

	-- Early return if telemetry is inactive
	if not telemetryActive then
		if widget.lastTelemetryActive and widget.totalFlights > 0 and widget.settingsLoaded then
			widget.holdUntil = now + widget.maxHoldDuration
			widget.retainDisplay = true
			lcd.invalidate()
		elseif widget.holdUntil > 0 and now > widget.holdUntil then
			widget.retainDisplay = false
			widget.holdUntil = 0
			lcd.invalidate()
		end
		widget.lastTelemetryActive = false
		return
	end

	-- Telemetry detected
	if not widget.lastTelemetryActive then
		widget.graceUntil = now + GRACE_DELAY
		widget.blinkReadyTime = now + GRACE_BLINK_DELAY
		widget.blinkOn = true
		widget.lastBlinkTime = now
		widget.settingsLoaded = false
		widget.flightLogged = false
		widget.switchEngaged = false
		widget.delayStart = 0
		widget.drawState = "white"
		widget.retainDisplay = false
		widget.holdUntil = 0
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
		return -- Skip updates during grace period
	end

	-- After grace: ensure blink is on
	if not widget.blinkOn then
		widget.blinkOn = true
	end

	-- Load model-specific settings once
	if not widget.settingsLoaded then
		local name = rfsuite and rfsuite.session and rfsuite.session.craftName
		if name then
			rfflyio.loadSettings(widget)
			widget.settingsLoaded = true
			lcd.invalidate()
		end
	end

	-- Handle flight logging using throttle switch
	if widget.settingsLoaded and type(widget.throttleSwitch) == "userdata" then
		if widget.throttleSwitch:state() then
			if not widget.switchEngaged then
				if widget.delayStart == 0 then
					widget.delayStart = math.floor(now)
				end
				local elapsed = math.floor(now) - widget.delayStart

				if not widget.flightLogged and elapsed >= widget.delayValue then
					widget.flightsSincePreset = widget.flightsSincePreset + 1
					widget.totalFlights = widget.newPreset + widget.flightsSincePreset
					widget.flightLogged = true
					widget.switchEngaged = true
					local countPath = rfflyio.getPath("FlightCount")
					rfflyio.writeCount(countPath, widget.flightsSincePreset)
					rfflyio.logFlight(widget, widget.totalFlights)
					widget.drawState = "green"
					lcd.invalidate()
				else
					widget.drawState = widget.flightLogged and "green" or "yellow"
					lcd.invalidate()
				end
			end
		else
			widget.switchEngaged = false
			widget.delayStart = 0
		end
	end
end

-- === Configuration Form ===
local function configure(widget)
	-- Display & Audio Options Panel
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

	-- Flight Tracking Panel
	local flightPanel = form.addExpansionPanel("Flight Tracking")
	flightPanel:open(false)

	-- Throttle Switch
	local line = flightPanel:addLine("Motor On Switch")
	form.addSwitchField(line, nil,
		function() return widget.throttleSwitch end,
		function(value) widget.throttleSwitch = value end)
		
	-- Trigger Delay
	local line = flightPanel:addLine("Trigger Delay (sec)")
	form.addNumberField(line, nil, 0, 1000,
		function() return widget.delayValue end,
		function(value) widget.delayValue = value end)

	-- Preset Flight Count
	local line = flightPanel:addLine("Preset Flight Count")
	form.addNumberField(line, nil, 0, 5120,
		function() return widget.newPreset end,
		function(value)
			widget.newPreset = value
			widget.preset = value
			widget.totalFlights = value + (widget.flightsSincePreset or 0)
			lcd.invalidate()
		end)

	flightPanel:addLine("Choose how dates appear in flight log.")

	-- Log Date Format
	local dateFormatChoices = {
		{ "DD-MM-YYYY", 1 },
		{ "MM-DD-YYYY", 2 },
		{ "YYYY-MM-DD", 3 }
	}
	local line = flightPanel:addLine("Flight Log Date Format")
	form.addChoiceField(line, nil, dateFormatChoices,
		function() return widget.dateFormat end,
		function(value) widget.dateFormat = value end)
end

-- === Read Function ===
local function read(widget)
	widget.useDefaultBackground = storage.read("useDefaultBackground")
	widget.useXXLFont = storage.read("useXXLFont")
	widget.maxHoldDuration = storage.read("maxHoldDuration")
	widget.throttleSwitch = storage.read("throttleSwitch")
	widget.delayValue = storage.read("delayValue")
	widget.dateFormat = tonumber(storage.read("dateFormat"))
	rfflyio.loadSettings(widget)
end

-- === Write Function ===
local function write(widget)
	storage.write("useDefaultBackground", widget.useDefaultBackground)
	storage.write("useXXLFont", widget.useXXLFont)
	storage.write("maxHoldDuration", widget.maxHoldDuration)
	storage.write("throttleSwitch", widget.throttleSwitch)
	storage.write("delayValue", widget.delayValue)
	storage.write("dateFormat", widget.dateFormat)
	rfflyio.saveSettings(widget)
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
