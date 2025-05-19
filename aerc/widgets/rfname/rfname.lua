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
-- Widget Name: RF Model Name

-- === Global Settings ===
local GRACE_DELAY = 10 -- Time (seconds) to blink after telemetry connected
local BLINK_INTERVAL = 0.5 -- Blinking toggle interval (seconds)
local GRACE_BLINK_DELAY = 2	-- Delay before blinking starts after telemetry connect

-- === Widget Creation ===
local function create()
	local now = os.clock()
	return {
		telemetrySource = nil, -- Telemetry active source
		lastCraftName = nil, -- Last known craftName loaded
		craftNameChecked = false, -- Flag to ensure name update logic only runs once after grace
		lastTelemetryActive = false, -- Last known telemetry active state
		graceUntil = 0,	-- Time until grace period ends
		blinkOn = true,	-- Blinking state flag
		lastBlinkTime = now, -- Last time blink toggled
		blinkReadyTime = now + GRACE_BLINK_DELAY, -- Time when blinking should start
		useDefaultBackground = false, -- Default to Black background
		useXXLFont = false, -- Enable XXL font
		holdUntil = 0, -- Time until fallback expires
		maxHoldDuration = 30, -- Seconds to hold last name after telemetry loss
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

	-- Determine what to display
	if widget.lastTelemetryActive then
		if inGrace(widget) then
			if not widget.blinkOn then return end
			displayText = "--"
		else
			if widget.lastCraftName and #widget.lastCraftName > 0 then
				displayText = widget.lastCraftName
			else
				displayText = "No Craftname"
			end

			if not rfsuite or not rfsuite.session then
				subText = "No RF Suite"
			end
		end
	elseif widget.lastCraftName and os.clock() < widget.holdUntil then
		displayText = widget.lastCraftName
	else
		displayText = "--"
	end

	-- Choose best font and size
	if displayText then
		if subText then
			-- Subtext in top third
			local subFont, subW, subH = selectFont(subText, w, h / 3)
			lcd.font(subFont)
			lcd.color(lcd.RGB(255, 100, 100))
			lcd.drawText((w - subW) / 2, h / 6 - subH / 2, subText)

			-- Main text in bottom 2/3
			local mainFont, mainW, mainH = selectFont(displayText, w, h * 2 / 3)
			lcd.font(mainFont)
			lcd.color(color)
			lcd.drawText((w - mainW) / 2, h / 2 + (h / 3 - mainH) / 2, displayText, BOLD)
		else
			-- Normal text centered
			local font, textW, textH = selectFont(displayText, w, h)
			lcd.font(font)
			lcd.color(color)
			lcd.drawText((w - textW) / 2, (h - textH) / 2, displayText, BOLD)
		end
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
		if widget.lastTelemetryActive and widget.lastCraftName then
			widget.holdUntil = now + widget.maxHoldDuration
			lcd.invalidate()
		elseif widget.holdUntil > 0 and now > widget.holdUntil then
			widget.lastCraftName = nil
			widget.holdUntil = 0
			lcd.invalidate()
		end
		widget.lastTelemetryActive = false
		return
	end

	-- Telemetry detected
	if not widget.lastTelemetryActive then
		widget.graceUntil = now + GRACE_DELAY
		widget.blinkOn = true
		widget.lastBlinkTime = now
		widget.blinkReadyTime = now + GRACE_BLINK_DELAY
		widget.craftNameChecked = false
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
	
	-- Update Model Name once based on rfsuite.craftName
	if not widget.craftNameChecked then
		local newName = rfsuite and rfsuite.session and rfsuite.session.craftName
		if newName and newName ~= widget.lastCraftName then
			widget.lastCraftName = newName
			lcd.invalidate()
		end
		widget.craftNameChecked = true
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
end

-- === Read Function ===
local function read(widget)
	widget.useDefaultBackground = storage.read("useDefaultBackground")
	widget.useXXLFont = storage.read("useXXLFont")
	widget.maxHoldDuration = storage.read("maxHoldDuration")
end

-- === Write Function ===
local function write(widget)
	storage.write("useDefaultBackground", widget.useDefaultBackground)
	storage.write("useXXLFont", widget.useXXLFont)
	storage.write("maxHoldDuration", widget.maxHoldDuration)
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
