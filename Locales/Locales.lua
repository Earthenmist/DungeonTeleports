local _, addon = ...
addon.L = { }

local localizations = addon.L

local locale = GetLocale()
if(locale == 'enGB') then
	locale = 'enUS'
end

setmetatable(addon.L, {
	__call = function(_, newLocale)
		localizations[newLocale] = {}
		return localizations[newLocale]
	end,
	__index = function(_, key)
		local localeTable = rawget(localizations, locale)
		local englishTable = rawget(localizations, 'enUS')
		return (localeTable and localeTable[key])
			or (englishTable and englishTable[key])
			or tostring(key)
	end
})
