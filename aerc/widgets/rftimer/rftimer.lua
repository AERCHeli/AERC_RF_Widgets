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
-- Widget Name: AERC Timer

-- === Widget Creation ===
local function create()
	return {
		startTime = nil, -- Timer start time
		elapsedTime = 0, -- Current elapsed time
		running = false, -- Timer running state
		useDefaultBackground = false, -- Default to Black background
		useXXLFont = false, -- Enable XXL font
		timerSwitch = nil, -- Configurable timer switch
		resetSwitch	= nil, -- Optional reset switch
		alertEnabled = true, -- Enable/disable alert
		alertTime = 210, -- Trigger alert when timer reaches this (seconds)
		alertPlayed = false, -- Track if audio has already played
		timerMode = "up", -- "up" or "down"
		countdownDuration = 210, -- Starting time for countdown (in seconds)
		exceededLimit = false, -- Used for color
	}
end

-- Timer Reset Function
local function resetTimer(widget)
	widget.elapsedTime = 0
	widget.startTime = nil
	widget.running = false
	widget.alertPlayed = false
	widget.exceededLimit = false
	lcd.invalidate()
end

-- === Display Drawing ===
local function paint(widget)
	local w, h = lcd.getWindowSize()

	-- Font selection with padding
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

	-- Prepare display text
	local displayText = "--:--"
	local subText = nil
	local color = lcd.RGB(255, 255, 255)

	if not widget.timerSwitch then
		subText = "No Switch"
	else
		local t = widget.elapsedTime or 0
		local isNegative = t < 0
		local absT = math.abs(t)
		local mins = math.floor(absT / 60)
		local secs = absT % 60
		displayText = string.format("%s%02d:%02d", isNegative and "-" or "", mins, secs)

		color = widget.exceededLimit and lcd.RGB(255, 0, 0) or lcd.RGB(255, 255, 255)
	end
	
	-- Reserve space for subtext if present
	local subH = 0
	if subText then
		lcd.font(FONT_S)
		_, subH = lcd.getTextSize(subText)
	end

	local bottomMargin = subH > 0 and (subH + 4) or 0
	local availableHeight = h - bottomMargin

	-- Draw main timer text
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

	-- Reset via Reset Switch
	if widget.resetSwitch and type(widget.resetSwitch) == "userdata" and widget.resetSwitch:state() then
		resetTimer(widget)
		return
	end

	-- Determine if switch is active
	local switchActive = widget.timerSwitch and type(widget.timerSwitch) == "userdata" and widget.timerSwitch:state()

	if switchActive then
		if not widget.running then
			widget.startTime = now - (widget.elapsedTime or 0)
			widget.running = true
		end
	else
		widget.running = false
	end

	local prevElapsed = widget.elapsedTime or 0
	local prevExceeded = widget.exceededLimit or false

	-- Update elapsed time only while running
	if widget.running and widget.startTime then
		local elapsed = now - widget.startTime

		if widget.timerMode == "up" then
			widget.elapsedTime = math.floor(elapsed)
			widget.exceededLimit = (widget.elapsedTime >= widget.alertTime)
		elseif widget.timerMode == "down" then
			widget.elapsedTime = math.floor(widget.countdownDuration - elapsed)
			widget.exceededLimit = (widget.elapsedTime < 0)
		end

		-- Audio alert logic
		if widget.alertEnabled and not widget.alertPlayed and widget.exceededLimit then
			system.playFile("/scripts/aerc/audio/timer1-elapsed.wav", AUDIO_QUEUE)
			widget.alertPlayed = true
		end
	end

	-- Only redraw if changed
	if widget.elapsedTime ~= prevElapsed or widget.exceededLimit ~= prevExceeded then
		lcd.invalidate()
	end
end

-- === Configuration Form ===
local function configure(widget)
	-- Display Options Panel
	local displayPanel = form.addExpansionPanel("Display & Timer Options")
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

	local timerPanel = form.addExpansionPanel("Timer Options")
	timerPanel:open(false)

	-- Timer Switch
	local line = timerPanel:addLine("Timer Switch")
	form.addSwitchField(line, nil,
		function() return widget.timerSwitch end,
		function(value) widget.timerSwitch = value end)

	-- Reset Switch
	local line = timerPanel:addLine("Reset Switch")
	form.addSwitchField(line, nil,
		function() return widget.resetSwitch end,
		function(value) widget.resetSwitch = value end)

	-- Always shown: Audio Alert toggle
	local line = timerPanel:addLine("Enable Audio Alert")
	form.addBooleanField(line, nil,
		function() return widget.alertEnabled end,
		function(value) widget.alertEnabled = value end)

	-- Timer Mode Dropdown
	local line = timerPanel:addLine("Timer Mode")
	modeOptions = {
		{"Count Up", 1},
		{"Count Down", 2}
	}
	form.addChoiceField(line, form.getFieldSlots(line)[0], modeOptions,
		function()
			return (widget.timerMode == "down") and 2 or 1
		end,
		function(value)
			widget.timerMode = (value == 2) and "down" or "up"
			if widget.fieldAlertTime then widget.fieldAlertTime:enable(widget.timerMode == "up") end
			if widget.fieldCountdown then widget.fieldCountdown:enable(widget.timerMode == "down") end
			lcd.invalidate()
		end)

	-- Alert Time (Count Up only)
	local line = timerPanel:addLine("Alert After (sec)")
	alertField = form.addNumberField(line, nil, 10, 3600,
		function() return widget.alertTime end,
		function(value) widget.alertTime = value; lcd.invalidate() end)
	alertField:enable(widget.timerMode == "up")
	widget.fieldAlertTime = alertField

	-- Timer Duration (Count Down only)
	local line = timerPanel:addLine("Timer Duration (sec)")
	countField = form.addNumberField(line, nil, 10, 3600,
		function() return widget.countdownDuration end,
		function(value) widget.countdownDuration = value end)
	countField:enable(widget.timerMode == "down")
	widget.fieldCountdown = countField
end

-- === Read Function ===
local function read(widget)
	widget.useDefaultBackground = storage.read("useDefaultBackground")
	widget.useXXLFont = storage.read("useXXLFont")
	widget.timerSwitch = storage.read("timerSwitch")
	widget.resetSwitch = storage.read("resetSwitch")
	widget.alertEnabled = storage.read("alertEnabled")
	widget.alertTime = storage.read("alertTime")
	widget.timerMode = storage.read("timerMode")
	widget.countdownDuration = storage.read("countdownDuration")
end

-- === Write Function ===
local function write(widget)
	storage.write("useDefaultBackground", widget.useDefaultBackground)
	storage.write("useXXLFont", widget.useXXLFont)
	storage.write("timerSwitch", widget.timerSwitch)
	storage.write("resetSwitch", widget.resetSwitch)
	storage.write("alertEnabled", widget.alertEnabled)
	storage.write("alertTime", widget.alertTime)
	storage.write("timerMode", widget.timerMode)
	storage.write("countdownDuration", widget.countdownDuration)
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
