local M = {}
local common = require("curl.common")
local fprint = require("curl.fprint").fprint

---@class ParserState
---@field lines string[]
---@field idx number
---@field state "START"|"REQ"|"RES"|"END"
local ParserState = {}
ParserState.__index = ParserState

---@param lines string[]
function ParserState.new(lines)
    local self = setmetatable({}, ParserState)
    self.lines = lines
    self.idx = 0
	self.state = "START"
    return self
end

---@return string?
function ParserState:next()
	if self.idx >= #self.lines + 1 then
		return nil
	end

	self.idx = self.idx + 1
	return self.lines[self.idx]
end

---@return string?
function ParserState:next_non_empty_trimmed()
	local cur = self:next()

	while cur ~= nil do
		cur = common.trim(cur)
		if #cur > 0 then
			return cur
		end
		cur = self:next()
	end

	return cur
end

---@param state "START"|"REQ"|"RES"|"END"
---@return boolean
function ParserState:update_state(state)
	if not (state == "REQ" or state == "RES" or state == "END") then
		return false
	end

	if state == "REQ" and self.state ~= "START" then
		return false
	end

	self.state = state
	return true
end

---@param line string
---@return boolean
function ParserState:eval(line)
	if self.state == "REQ" then
		return true
	elseif self.state == "RES" then
		return true
	elseif self.state == "END" then
		return false
	end
	return true
end

---@param lines string[]
function M.parse(lines)
	local parser = ParserState.new(lines)
	local continue = true
	local line = parser:next_non_empty_trimmed()

	while line ~= nil and continue do
		if line[1] == "#" then
			continue = parser:update_state(line.sub(2, #line))
		else
			continue = parser:eval(line)
		end

		line = parser:next()
	end
end

return M
