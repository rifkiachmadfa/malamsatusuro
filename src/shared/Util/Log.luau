--!strict
-- Log: format log seragam supaya mudah dicari di Output.

local Log = {}

local function format(tag: string, message: string): string
	return string.format("[%s] %s", tag, message)
end

function Log.info(tag: string, message: string)
	print(format(tag, message))
end

function Log.warn(tag: string, message: string)
	warn(format(tag, message))
end

return table.freeze(Log)