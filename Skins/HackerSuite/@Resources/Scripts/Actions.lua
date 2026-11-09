-- Hacker Suite shared click actions.
-- Loaded once per skin through Common.inc as [MeasureActions].
-- Functions are called with: !CommandMeasure MeasureActions "FunctionName(...)"

function Initialize()
    RES = SKIN:ReplaceVariables('#@#')
    SETTINGS = RES .. 'Settings.inc'
    CUSTOM = RES .. 'Themes\\Custom.inc'
end

local function settingsQuote()
    return '"' .. SETTINGS .. '"'
end

local function writeSetting(key, value)
    SKIN:Bang('!WriteKeyValue', 'Variables', key, value, settingsQuote())
end

function RefreshAll()
    SKIN:Bang('!RefreshApp')
end

-- Weather: Celsius + km/h  <->  Fahrenheit + mph, then reload every skin.
function ToggleUnits()
    local units = SKIN:GetVariable('WeatherUnits', 'metric')
    local temp, wind, params
    if units == 'imperial' then
        units, temp, wind = 'metric', 'C', 'km/h'
        params = '&temperature_unit=celsius&wind_speed_unit=kmh'
    else
        units, temp, wind = 'imperial', 'F', 'mph'
        params = '&temperature_unit=fahrenheit&wind_speed_unit=mph'
    end
    writeSetting('WeatherUnits', units)
    writeSetting('WeatherUnitParams', '"' .. params .. '"')
    writeSetting('TempUnit', temp)
    writeSetting('WindUnit', wind)
    SKIN:Bang('!RefreshApp')
end

-- Copy a value to the clipboard (used by the IP / weather rows).
function Copy(value)
    if value == nil then return end
    value = tostring(value)
    if value == '' or value == '--' then return end
    SKIN:Bang('!SetClip', '"' .. value .. '"')
end

-- Remove every custom colour override and return to the active theme.
function ClearCustom()
    local f = io.open(CUSTOM, 'w')
    if f then
        f:write('[Variables]\n')
        f:close()
    end
    SKIN:Bang('!RefreshApp')
end
