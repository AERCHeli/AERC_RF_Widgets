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
-- Widget Name: RF Model Image

-- === Global Settings ===
local GRACE_DELAY = 10 -- Time (seconds) to blink after telemetry connected
local DEFAULT_IMAGE = "/scripts/aerc/images/rf2.bmp" -- Default Image to display

-- === Widget Creation ===
local function create()
	local now = os.clock()
	return {
		telemetrySource = nil, -- Telemetry active source
		bitmapPtr = lcd.loadBitmap(DEFAULT_IMAGE), -- Image File
		bitmapPtrPath = DEFAULT_IMAGE, -- Image File Path
		lastTelemetryActive = false, -- Last known telemetry active state
		graceUntil = 0, -- Time until grace period ends
		lastCraftName = nil, -- Last known craftName loaded
		craftNameChecked = false, -- Flag to ensure name update logic only runs once after grace
		useDefaultBackground = false, -- Default to Black background
	}
end

-- Returns true if still within the grace delay period after reconnect
local function inGrace(widget)
	return os.clock() < (widget.graceUntil or 0)
end

-- Load default image
local function defaultImage(widget)
	if widget.bitmapPtrPath ~= DEFAULT_IMAGE then
		widget.bitmapPtr = lcd.loadBitmap(DEFAULT_IMAGE)
		widget.bitmapPtrPath = DEFAULT_IMAGE
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

	-- Determine padding based on border state
	local padding = widget.showBorder and 4 or 2

	-- Draw image if available
	if widget.bitmapPtr then
		local imageWidth = math.floor(w - 2 * padding)
		local imageHeight = math.floor(h - 2 * padding)
		lcd.drawBitmap(padding, padding, widget.bitmapPtr, imageWidth, imageHeight)
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
		if widget.lastTelemetryActive then
			defaultImage(widget)
			lcd.invalidate()
		end
		widget.lastTelemetryActive = false
		widget.lastCraftName = nil
		return
	end

	-- Telemetry detected
	if not widget.lastTelemetryActive then
		widget.graceUntil = now + GRACE_DELAY
		widget.craftNameChecked = false
	end
	-- Save telemetry state					
	widget.lastTelemetryActive = true

	-- After grace: try to load image once
	if not inGrace(widget) and not widget.craftNameChecked then
		local newName = rfsuite and rfsuite.session and rfsuite.session.craftName

		if newName and newName ~= widget.lastCraftName then
			local imgPath = "/scripts/aerc/images/" .. newName .. ".bmp"
			local loaded = lcd.loadBitmap(imgPath)
			if loaded then
				widget.bitmapPtr = loaded
				widget.bitmapPtrPath = imgPath
			else
				defaultImage(widget)
			end
			widget.lastCraftName = newName
			lcd.invalidate()
		elseif not newName then
			defaultImage(widget)
			widget.lastCraftName = nil
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
end

-- === Read Function ===
local function read(widget)
	widget.showBorder = storage.read("showBorder")
	widget.useDefaultBackground = storage.read("useDefaultBackground")
end

-- === Write Function ===
local function write(widget)
	storage.write("showBorder", widget.showBorder)
	storage.write("useDefaultBackground", widget.useDefaultBackground)
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
