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


-- AERC Widgets & Layout Registration - ETHOS
-- Author: Andy.E

local compiler = require("lib.compile")

local widgets = {
	{ name = "AERC Altitude", key = "rfalt", path = "widgets/rfalt/rfalt.lua" },
	{ name = "AERC Battery", key = "rfbatt", path = "widgets/rfbatt/rfbatt.lua" },
	{ name = "AERC BEC", key = "rfbec", path = "widgets/rfbec/rfbec.lua" },
	{ name = "AERC Current", key = "rfcurr", path = "widgets/rfcurr/rfcurr.lua" },
	{ name = "AERC ESC Temp", key = "rfesc", path = "widgets/rfesc/rfesc.lua" },
	{ name = "AERC Flights", key = "rffly", path = "widgets/rffly/rffly.lua" },
	{ name = "AERC Model Image", key = "rfimage", path = "widgets/rfimage/rfimage.lua" },
	{ name = "AERC Model Name", key = "rfname", path = "widgets/rfname/rfname.lua" },
	{ name = "AERC RPM", key = "rfrpm", path = "widgets/rfrpm/rfrpm.lua" },
	{ name = "AERC Throttle", key = "rfthro", path = "widgets/rfthro/rfthro.lua" },
	{ name = "AERC Timer", key = "rftimer", path = "widgets/rftimer/rftimer.lua" },	
}

local function init()
  -- Register widgets
  for _, w in ipairs(widgets) do
    local ok, mod = pcall(compiler.loadfile, w.path)
    if ok and type(mod) == "function" then
      local success, widget = pcall(mod)
      if success and widget and widget.create and widget.paint then
        system.registerWidget({
          key = w.key,
          name = w.name,
          create = widget.create,
          paint = widget.paint,
          wakeup = widget.wakeup,
          configure = widget.configure,
          read = widget.read,
          write = widget.write,
          persistent = widget.persistent or false
        })
      end
    end
  end

  -- Register layouts
  local env = system.getVersion()
  local radio = env.board

  -- Layout for FrSky X14 Series
  if string.find(radio, "14") then
    system.registerLayout({key = "AERC1", widgets={
      {x=0, y=36, w=192, h=84},			-- 0: Model Name
      {x=0, y=150, w=192, h=100},		-- 1: Model Image
      {x=0, y=254, w=96, h=70},			-- 2: Timer
      {x=104, y=254, w=88, h=70},		-- 3: Flights
      {x=200, y=36, w=440, h=84},		-- 4: Battery
      {x=200, y=150, w=142, h=84},		-- 5: Sensor 1
      {x=350, y=150, w=142, h=84},		-- 6: Sensor 2
      {x=500, y=150, w=140, h=84},		-- 7: Sensor 3
      {x=200, y=238, w=142, h=86},		-- 8: Sensor 4
      {x=350, y=238, w=142, h=86},		-- 9: Sensor 5
      {x=500, y=238, w=140, h=86},		-- 10: Sensor 6
    }})
  end

  -- Layouts for X20 and X18R(S) Series
  if string.match(radio, "^X20") or string.match(radio, "^X18R[S]?") then
    system.registerLayout({key = "AERC2", widgets={
      {x=8, y=95, w=256, h=106},		-- 0: Model Name
      {x=8, y=209, w=256, h=130},		-- 1: Model Image
      {x=8, y=347, w=256, h=80},		-- 2: Timer
      {x=272, y=95, w=520, h=106},		-- 3: Battery
      {x=272, y=209, w=168, h=106},		-- 4: Sensor 1
      {x=272, y=321, w=168, h=106},		-- 5: Sensor 2
      {x=448, y=209, w=168, h=106},		-- 6: Sensor 3
      {x=448, y=321, w=168, h=106},		-- 7: Sensor 4
      {x=624, y=209, w=168, h=106},		-- 8: Sensor 5
      {x=624, y=321, w=168, h=106},		-- 9: Sensor 6
    }})

    system.registerLayout({key = "AERC3", widgets={
      {x=8, y=95, w=256, h=106},		-- 0: Model Name
      {x=8, y=209, w=256, h=130},		-- 1: Model Image
      {x=8, y=347, w=138, h=80},		-- 2: Timer
      {x=154, y=347, w=108, h=80},		-- 3: Flights
      {x=272, y=95, w=520, h=106},		-- 4: Battery
      {x=272, y=209, w=168, h=106},		-- 5: Sensor 1
      {x=272, y=321, w=168, h=106},		-- 6: Sensor 2
      {x=448, y=209, w=168, h=106},		-- 7: Sensor 3
      {x=448, y=321, w=168, h=106},		-- 8: Sensor 4
      {x=624, y=209, w=168, h=106},		-- 9: Sensor 5
      {x=624, y=321, w=168, h=106},		-- 10: Sensor 6
    }})
  end
end

return { init = init }
