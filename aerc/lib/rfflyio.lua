-- RF Flight Counter Helper Library - flightio.lua

local rfflyio = {}

-- Returns the craftName from RF Suite or nil if unavailable
local function getCraftName()
	if rfsuite and rfsuite.session and rfsuite.session.craftName then
		return rfsuite.session.craftName
	end
	return nil
end

-- Build model-specific file path under rffly/models
local function getPath(suffix)
	local name = getCraftName()
	if not name or not suffix then return nil end
	suffix = string.lower(suffix)
	return "/scripts/aerc/widgets/rffly/models/" .. name .. "-" .. suffix .. ".txt"
end

-- Read a stored numeric value
local function readCount(path)
	if not path then return 0 end
	local file = io.open(path, "r")
	if not file then return 0 end
	local line = file:read("*line")
	file:close()
	return tonumber(line) or 0
end

-- Write a numeric value
local function writeCount(path, value)
	if not path then return end
	local file = io.open(path, "w")
	if file then
		file:write(tostring(value))
		file:close()
	end
end

-- Load per-model preset + current flight count
local function loadSettings(widget)
	local presetPath = getPath("Preset")
	local countPath  = getPath("FlightCount")

	widget.preset = readCount(presetPath)
	widget.newPreset = widget.preset
	widget.flightsSincePreset = readCount(countPath)
	widget.totalFlights = widget.preset + widget.flightsSincePreset
	widget.settingsLoaded = true
end

-- Save model-specific preset value
local function saveSettings(widget)
	local presetPath = getPath("Preset")
	if presetPath then
		writeCount(presetPath, widget.newPreset)
	end
end

-- Append entry to the shared flight-log.txt under aerc/flight_log
local function logFlight(widget, total)
	local name = getCraftName()
	if not name then return end

	local path = "/scripts/aerc/flight_log/flight-log.txt"
	local date = os.date("*t")

	local formattedDate
	if widget.dateFormat == 1 then
		formattedDate = string.format("%02d-%02d-%04d", date.day, date.month, date.year)
	elseif widget.dateFormat == 2 then
		formattedDate = string.format("%02d-%02d-%04d", date.month, date.day, date.year)
	elseif widget.dateFormat == 3 then
		formattedDate = string.format("%04d-%02d-%02d", date.year, date.month, date.day)
	else
		formattedDate = string.format("%02d-%02d-%04d", date.day, date.month, date.year)
	end

	local entry = string.format("%s, %s, Flight %d\n", formattedDate, name, total)
	local file = io.open(path, "a")
	if file then
		file:write(entry)
		file:close()
	end
end

-- Expose module functions
rfflyio.getPath       = getPath
rfflyio.readCount     = readCount
rfflyio.writeCount    = writeCount
rfflyio.loadSettings  = loadSettings
rfflyio.saveSettings  = saveSettings
rfflyio.logFlight     = logFlight

return rfflyio
