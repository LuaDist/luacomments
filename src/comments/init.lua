

local re = require("re")

---
-- Module for lua comment parsing.
--@class module
--@name comments
--@author Peter Kosa
-- @release 2013/04/04, Peter Kosa

module("comments",package.seeall)
local print  = print

local explua = require"comments.explua"		-- parser = "explua"
local luadoc = require"comments.luadoc"		-- parser = "luadoc"
local literate = require"comments.literate"	-- parser = "literate"
local custom = require"comments.custom"		-- parser = "custom"
local ldoc = require"comments.ldoc"			-- parser = "ldoc"
local leg = require"comments.leg"			-- parser = "leg"

local parsers={
	[1]=literate,
	[2]=leg,
	[3]=custom,
	[4]=explua,
	[5]=ldoc,
	[6]=luadoc,
}

---
--% The main parse funcion. Invokes the given parser, or tries all parsers until one succeed.
--@ text (string) multi or simple line comment
--@ parser (string,any) parser type or anything else
--@ extended (any) nil if don't want to use extended explua grammar
--: (table,nil) Return a table with parsed infos


function Parse(text,parser,extended)
	local result,errno

	if(parser=="explua")then
		return explua.parse(text,extended)
	elseif(parser=="luadoc")then
		return	luadoc.parse(text)
	elseif(parser=="literate")then
		return literate.parse(text)
	elseif(parser=="custom")then
		return custom.parse(text)
	elseif(parser=="ldoc")then
		return	ldoc.parse(text)
	elseif(parser=="leg")then
		return leg.parse(text)
	else

		for k,v in ipairs(parsers) do
			result,errno = v.parse(text,extended)
			if(result)then
				return result
			end
		end
	end
	return result,errno
end

-- @author Michal Juranyi
function findDocstring(subtree)
	if type(subtree.data) == "table" then
		for _,v in ipairs(subtree.data) do
			if type(v.data) == "table" and #v.data > 0 then
				if v.key == "Stat" then
					return false
				end
				local res = findDocstring(v)
				if res ~= nil then
					return res
				end
			else
				if v.key == "COMMENT" and v.parsed.style == "literate" and v.parsed.type == "lp" then
					return v.parsed.text
				end
			end
		end
	end
end

-- @author Michal Juranyi
local function hasBlockComment(subtree)
	for _,v in ipairs(subtree.data) do
		if v.key == "COMMENT" and v.parsed.style == "custom" and (v.parsed.type == "startblock" or v.parsed.type == "endblock") then
			return v.parsed.type, v
		end
	end

	return nil
end

-- @author Michal Juranyi
local function markBlockChildren(ast)
	local res, node, tag

	if type(ast.data) == "table" then
		for _,v in ipairs(ast.data) do
			if type(v.data) == "table" and v.key ~= "IGNORED" then
				if tag == true then
					v.comment = node
				end
				markBlockChildren(v)
			elseif v.key == "IGNORED" then
				local res_tmp, node_tmp = hasBlockComment(v)
				if res_tmp == "startblock" then
					res = res_tmp
					node = node_tmp
					tag = true
				end
				if res == "endblock" then
					tag = false
				end
			end
		end
	end

	return ast
end

-- @author Michal Juranyi
local function TagAST(ast)
	if type(ast.data) == "table" and #ast.data > 0 then
		for _,v in ipairs(ast.data) do
			TagAST(v)
		end
	else
		if ast.key == "COMMENT" then
			ast.parsed = Parse(ast.str)
		end
	end

	return ast
end

-- @author Michal Juranyi
function extendAST(ast)
	local extended_ast
	extended_ast = TagAST(ast)
	extended_ast = markBlockChildren(extended_ast)
	return extended_ast
end
