local M = {}
local common = require("curl.common")

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
	ARGS = "ARGS",
	COOKIES = "COOKIES",
	QUERY = "QUERY",
	RES = "RES",
	END = "END",
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

---@class HttpPacket
---@field host string?
---@field method Methods?
---@field headers { [string]: string }
---@field cookies { [string]: string }
---@field query { [string]: string }
---@field body string?

---@class ParserState
---@field lines string[]
---@field idx number
---@field state States
---@field cur_section Sections?
---@field error_msg? string
---@field verbose_output boolean
---@field verbose_all boolean
---@field replace_star_slash boolean
---@field output_curl_cmd boolean
---@field http_state HttpPacket
local ParserState = {}
ParserState.__index = ParserState

---@param lines string[]
function ParserState.new(lines)
	local self = setmetatable({}, ParserState)
	self.lines = lines
	self.idx = 0
	self.state = States.START
	self.cur_section = nil
	self.verbose_output = false
	self.verbose_all = false
	self.output_curl_cmd = false
	self.replace_star_slash = true
	self.http_state = {
		headers = {},
		cookies = {},
		query = {},
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

---@param format_str string
function ParserState:set_error(format_str, ...)
	self.error_msg = string.format("Error at line %d: "..format_str, self.idx, ...)
end

---@param section string
---@return boolean
function ParserState:update_section_and_state(section)
	if Sections[section] == nil then
		self:set_error('Unknown section "%s"', section)
		return false
	end

	if self.state == States.BODY and not (section == Sections.END or section == Sections.RES) then
		self:set_error('Unexpected section "%s" after the body', section)
		return false
	elseif self.state == States.RES and section ~= Sections.END then
		self:set_error('Unexpected section "%s" after the response', section)
		return false
	elseif section == Sections.REQ then
		if self.cur_section then
			self:set_error('Unexpected section "%s"', section)
			return false
		end
		self.state = "SECTION"
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
---@return boolean
function ParserState:is_comment(line)
	return vim.trim(line):sub(1, 2) == "//"
end

---@param line string
---@return string
function ParserState:get_section_name(line)
	return line:sub(2, #line):match("%w+")
end

---@param line string
---@return boolean
function ParserState:parse_host(line)
	local method, host = unpack(common.split_delim_once_trimmed(line, " ")) ---@diagnostic disable-line

	if host == nil or #host == 0 then
		self:set_error("Host url not specified")
		return false
	end

	if not HttpMethods[method] then
		self:set_error("Unknown http method")
		return false
	end

	self.http_state.method = method ---@diagnostic disable-line
	self.http_state.host = host

	return true
end

---@param line string
---@return boolean
function ParserState:parse_header(line)
	local key, val = unpack(common.split_delim_once_trimmed(line, ":")) ---@diagnostic disable-line

	if val == nil or val == "" then
		self:set_error('empty value not allowed as value for header key "%s"', key)
		return false
	end

	if key == nil or #key == 0 then
		self:set_error('empty key not allowed for header value "%s"', val)
		return false
	end

	self.http_state.headers[key] = val

	return true
end

---@param line string
---@return boolean
function ParserState:eval_REQ(line)
	if self.http_state.host == nil then
		return self:parse_host(line)
	end
	return self:parse_header(line)
end

---@param line string
---@return boolean
function ParserState:eval_COOKIES(line)
	local key, val = unpack(common.split_delim_once_trimmed(line, "=")) ---@diagnostic disable-line

	if val == nil or val == "" then
		self:set_error('empty value not allowed as value for cookie key "%s"', key)
		return false
	end

	if key == nil or #key == 0 then
		self:set_error('empty key not allowed for cookie value "%s"', val)
		return false
	end

	self.http_state.cookies[key] = val

	return true
end

---@param line string
---@return boolean
function ParserState:eval_QUERY(line)
	local key, val = unpack(common.split_delim_once_trimmed(line, "=")) ---@diagnostic disable-line

	if val == nil or val == "" then
		self:set_error('empty value not allowed as value for query key "%s"', key)
		return false
	end

	if key == nil or #key == 0 then
		self:set_error('empty key not allowed for query value "%s"', val)
		return false
	end

	self.http_state.query[key] = val

	return true
end

---@param arg string
---@return boolean
function ParserState:eval_long_arg(arg)
	local l, r = unpack(vim.split(arg:sub(3, #arg), "=")) ---@diagnostic disable-line
	if l == nil then
		self:set_error("Invalid empty arg")
		return false
	end

	if l == "verbose" then
		self.verbose_output = true
	elseif l == "out-curl-cmd" then
		self.output_curl_cmd = true
	elseif l == "all" then
		self.verbose_all = true
		self.verbose_output = true
	elseif l == "replace-star-slash" then
		if r == nil then
			self:set_error("Missing value for arg '%s'", l)
			return false
		end

		if r ~= "false" and r ~= "true" then
			self:set_error("Invalid value for arg '%s'. Must be either true or false.", l)
			return false
		end

		self.replace_star_slash = false
	else
		self:set_error("Unknown arg '%s'", arg)
		return false
	end

	return true
end

---@param arg string
---@return boolean
function ParserState:eval_short_arg(arg)
	local l, r = unpack(vim.split(arg:sub(2, #arg), "=")) ---@diagnostic disable-line
	if l == nil then
		self:set_error("Invalid empty arg")
		return false
	end

	if l == "v" then
		self.verbose_output = true
	end

	return true
end

---@param line string
---@return boolean
function ParserState:eval_ARGS(line)
	---@type string[]
	local args = vim.split(line, " ") ---@diagnostic disable-line
	local ret = true

	for _, v in ipairs(args) do
		if v == "" then goto continue end
		if v:sub(1, 2) == "--" then
			ret = ret and self:eval_long_arg(v)
		elseif v:sub(1, 1) == "-" then
			ret = ret and self:eval_short_arg(v)
		end
	    ::continue::
	end
	return true
end

local eval_map = {
	[Sections.REQ] = ParserState.eval_REQ,
	[Sections.COOKIES] = ParserState.eval_COOKIES,
	[Sections.QUERY] = ParserState.eval_QUERY,
	[Sections.ARGS] = ParserState.eval_ARGS,
}

---@param og_line string
---@return boolean
function ParserState:eval(og_line)
	local line = common.trim(og_line)

	if self.state == States.SECTION then
		if #line == 0 then
			local peeked = self:peek_line()
			if peeked == nil then
				self:set_error("Unexpected end of request")
				return false
			end
			peeked = common.trim(peeked)
			if not self:is_section(peeked) and peeked ~= "" then
				self.state = States.BODY
			end
			self.cur_section = nil
			return true
		end
		return eval_map[self.cur_section](self, line)
	elseif self.state == States.BODY then
		if self.http_state.body == nil then
			self.http_state.body = og_line
		else
			self.http_state.body = self.http_state.body .. "\n" .. og_line
		end
		return true
	elseif self.state == States.RES then
		return true
	elseif self.state == States.END then
		return false
	end
	return true
end

---@return string[]
function ParserState:to_curl_cmd()
	if self.error_msg then
		return {}
	end

	local cmd = {"curl"}
	local url = self.http_state.host

	if self.verbose_output then
		common.table_insert_multi(cmd, "-v")
	end

	common.table_insert_multi(cmd, "-X", self.http_state.method)

	if common.table_size(self.http_state.headers) > 0 then
		common.table_insert_multi(cmd, "-H")
		local str = ""
		for k, v in pairs(self.http_state.headers) do
			str = str..k..":"..v..";"
		end

		str = str:sub(0, #str - 1)
		common.table_insert_multi(cmd, str)
	end

	if common.table_size(self.http_state.cookies) > 0 then
		common.table_insert_multi(cmd, "--cookie")
		local str = ""
		for k, v in pairs(self.http_state.cookies) do
			str = str..k.."="..v..";"
		end

		str = str:sub(0, #str - 1)
		common.table_insert_multi(cmd, str)
	end

	if common.table_size(self.http_state.query) > 0 then
		local str = ''
		for k, v in pairs(self.http_state.query) do
			str = str..k.."="..v:gsub(" ", "+").."&"
		end

		url = url.."?"..str:sub(0, #str - 1)
	end

	if self.http_state.body ~= nil then
		common.table_insert_multi(cmd, "--data", self.http_state.body)
	end

	common.table_insert_multi(cmd, "--url", url)

	return cmd
end

---@param lines string[]|string
function M.parse(lines)
	if type(lines) == "string" then
		lines = vim.split(lines:gsub("\r\n", "\n"), "\n", {})
	end

	local parser = ParserState.new(lines)
	local continue = true
	local line = parser:next_line_non_empty_trimmed()

	while line ~= nil and continue do
		if parser:is_comment(line) then
			-- do nothing
		elseif parser:is_section(line) then
			continue = parser:update_section_and_state(parser:get_section_name(line))
		else
			continue = parser:eval(line)
		end

		line = parser:next_line()
	end

	if parser.error_msg == nil then
		if HttpMethods[parser.http_state.method] == nil then
			parser:set_error("Method name not specified")
		end
	end

	local e = parser.error_msg
	if e then return { cmd = nil, error_msg = e } end
	return {
		cmd = parser:to_curl_cmd(),
		error_msg = e,
		replace_star_slash = parser.replace_star_slash,
		verbose_all = parser.verbose_all,
		output_curl_cmd = parser.output_curl_cmd
	}
end

return M
