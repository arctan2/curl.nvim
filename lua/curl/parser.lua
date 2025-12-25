local M = {}
local common = require("curl.common")
local bufprint = require("curl.bufprint").bufprint

---@enum States
local States = {
	START = "START",
	SECTION = "SECTION",
	BODY = "BODY",
	RES = "RES",
	END = "END"
}

---@enum Sections
local Sections = {
	REQ = "REQ",
	RES = "RES",
	END = "END"
}

---@enum Methods
local HttpMethods = {
	GET = true,
	POST = true,
	PUT = true,
	PATCH = true,
	DELETE = true,
	HEAD = true,
	OPTIONS = true
}

---@type { [Sections]: States }
local SectionToStateMap = {
	[Sections.REQ] = States.SECTION,
	[Sections.RES] = States.RES,
	[Sections.END] = States.END
}

---@class HttpPacket
---@field host string?
---@field method Methods?
---@field headers { [string]: string }
---@field body string?

---@class ParserState
---@field lines string[]
---@field idx number
---@field state States
---@field cur_section Sections?
---@field httpState HttpPacket
---@field error_msg? string
local ParserState = {}
ParserState.__index = ParserState

---@param lines string[]
function ParserState.new(lines)
	local self = setmetatable({}, ParserState)
	self.lines = lines
	self.idx = 0
	self.state = States.START
	self.cur_section = nil
	self.httpState = {
		headers = {}
	}
	return self
end

---@return string?
function ParserState:next_line()
	if self.idx >= #self.lines + 1 then
		return nil
	end

	self.idx = self.idx + 1
	return self.lines[self.idx]
end

---@return string?
function ParserState:peek_line()
	return self.lines[self.idx + 1]
end

---@return string?
function ParserState:next_line_non_empty_trimmed()
	local cur = self:next_line()

	while cur ~= nil do
		cur = common.trim(cur)
		if #cur > 0 then
			return cur
		end
		cur = self:next_line()
	end

	return cur
end

---@param section string
---@return boolean
function ParserState:update_section_and_state(section)
	if Sections[section] == nil then
		self.error_msg = string.format('Unknown section "%s"', section)
		return false
	end

	if section == Sections.REQ then
		if self.cur_section then
			self.error_msg = string.format('Unexpected section "%s"', section)
			return false
		end
		self.state = "SECTION"
	elseif self.state == States.BODY then
		self.error_msg = string.format('Unexpected section "%s" after the body', section)
		return false
	elseif self.state == States.RES then
		self.error_msg = string.format('Unexpected section "%s" after the response', section)
		return false
	end

	if section == Sections.END then
		self.state = States.END
	elseif section == Sections.RES then
		self.state = States.RES
	end

	self.cur_section = section

	return true
end

---@param line string
---@return boolean
function ParserState:is_section(line)
	return line:sub(1, 1) == "#"
end

---@param line string
---@return string
function ParserState:get_section_name(line)
	return line:sub(2, #line):match("%w+")
end

---@param line string
---@return boolean
function ParserState:parse_host(line)
	local method = ""
	local i = 1
	while i <= #line do
		local c = line:sub(i, i)
		if c == " " then
			i = i + 1
			break
		end
		i = i + 1
	end

	method = line:sub(1, i - 2)

	if not HttpMethods[method] then
		self.error_msg = "Unknown http method"
		return false
	end

	if i > #line then
		self.error_msg = "Host url not specified"
		return false
	end

	self.httpState.method = method
	self.httpState.host = line:sub(i, #line)

	return true
end

---@param line string
---@return boolean
function ParserState:eval_REQ(line)
	if self.httpState.host == nil then
		return self:parse_host(line)
	end
	return true
end

local eval_map = {
	[Sections.REQ] = ParserState.eval_REQ,
}

---@param og_line string
---@return boolean
function ParserState:eval(og_line)
	local line = common.trim(og_line)

	if self.state == States.SECTION then
		if #line == 0 then
			local peeked = self:peek_line()
			if peeked == nil then
				self.error_msg = string.format("Unexpected end of request")
				return false
			end
			peeked = common.trim(peeked)
			if not self:is_section(peeked) then
				self.state = States.BODY
			end
			self.cur_section = nil
			return true
		end
		return eval_map[self.cur_section](self, line)
	elseif self.state == States.BODY then
		if self.httpState.body == nil then
			self.httpState.body = og_line
		else
			self.httpState.body = self.httpState.body .. "\n" .. og_line
		end
		return true
	elseif self.state == States.RES then
		return true
	elseif self.state == States.END then
		return false
	end
	return true
end

---@param lines string[]|string
function M.parse(lines)
	if type(lines) == "string" then
		lines = common.split_lines(lines)
	end

	local parser = ParserState.new(lines)
	local continue = true
	local line = parser:next_line_non_empty_trimmed()

	while line ~= nil and continue do
		if parser:is_section(line) then
			continue = parser:update_section_and_state(parser:get_section_name(line))
		else
			continue = parser:eval(line)
		end

		line = parser:next_line()
	end

	bufprint(parser.httpState.method, parser.httpState.host)
	bufprint(parser.error_msg)
end

M.parse([[#REQ
POST http://localhost:3000/register
Content-Type: application/json

{
	"email": "abc@gmail.com",
	"password": "pwdpwd"
}
#REQ
#END
]])

return M
