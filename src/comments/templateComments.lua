--module for adding API comments and docstring comments for functions and comments for if, for, while constructions
--by Peter Mendel 05/2014
local m = require 'metrics'
local io = require 'io'
local mu = require 'metrics.utils'
local gdu = require 'getdoc.util'
local lfs = require 'lfs'

local pairs, print, type, table,string, assert = pairs, print, type, table, string, assert
local new_text = ""
local text_tag = {
				tag = "",
				text = ""
				}
local stat_table = {}
local comment_style = {
	luadoc = "-- @author\n-- @name ",
	explua = "---\n--% "
}
local return_found = false

module ('comments.templateComments')

-- @param file path to .lua file to comment
-- @param style if function comments are chosen, this is style of them - possible just luadoc, explua styles yet
-- @param func boolean, if true, function comments are added, else docstring comments to logic constructions
-- @param output directory to save lua file with added comments
function processFile(file, style, func, output)
	print("Processing: ",file)
	print(output)
	local f, text
	local ast

	f = io.input(file)
	text = f:read("*a")
	f:close()

	ast = m.processText(text)
	new_ast = ast
	if style == nil then
		style = "luadoc"
	end

	if func == true then
		functionComments(ast,style)
	else
		findConstructions(ast)
		astToString(ast)
		docstringComments()
	end

	local new = io.open(output,"w")
	new:write(new_text)
	new:close()
	new_text = ""
	stat_table = {}
	return_found = false
	text_tag.tag = ""
	text_tag.text = ""
end

--- The main function for handle comment adding
-- @param path file or directory path
-- @param style style of function comment
-- @param func boolean, if true, function comments are added, else docstring comments to logic constructions
-- @param output directory to save lua file with added comments
function addComments(path, style, func, output)

	if (string.find(path, "%.lua") ~= nil) then
		if (string.find(output, "%.lua") ~= nil) then
			output = string.sub(output, 0, string.len(output)-4)
			output = output .. "(1).lua"
		else
			name = string.match(path, "%/%a+%.lua")
			output = output .. name
		end
	    processFile(path, style, func, output)
	else
	    for file in lfs.dir(path) do
	        if file ~= "." and file ~= ".." then
	            local f = path..'/'..file
	            local attr = lfs.attributes (f)
	            assert (type(attr) == "table")
	            if attr.mode == "directory" then
	            	output = output .. '/' .. file
	            	lfs.mkdir(output)
	                addComments(f,style, func,output)
	                output = output .. "/.."
	            else
	            	if string.find(file, "%.lua") ~= nil then
	                	processFile(path .. "/" .. file, style, func, output .. "/" .. file)
	            	end
	            end
	        end
	    end
	end
end


--- Function for finding and adding function comments
-- @param ast ast tree of source code
-- @param style comment style to add
function functionComments(ast,style)

	if ast.tag == "GlobalFunction" or ast.tag == "LocalFunction" or ast.tag == "Function" or ast.tag == "LocalAssign" then

		if ast.tag == "GlobalFunction" or ast.tag == "LocalFunction" or ast.tag == "Function" then

			if text_tag.tag == "Stat" then
				local comment = mu.getComment(ast)
				if comment == nil then
					if string.find(style,"explua") then
						new_text = new_text .. createStyleComment(ast,style) .. text_tag.text

						comment_style.explua = "---\n--% "
						return_found = false
					elseif style == "luadoc" then
						new_text = new_text .. createStyleComment(ast,style) .. text_tag.text
						comment_style.luadoc = "-- @author\n-- @name "
						return_found = false
					end
				else
					new_text = new_text .. text_tag.text
				end
					text_tag.tag = ""
					text_tag.text = ""
			end
		else
			new_text = new_text .. text_tag.text
			text_tag.text = ""
		end
		return
	else
		new_text = new_text .. text_tag.text
		text_tag.text = ""
	end

	if  ast.tag == "IGNORED" or ast.tag == "Stat" or ast.tag == "LastStat" then

		if ast.tag == "Stat" then
			text_tag.tag = "Stat"
			text_tag.text = ast.text
		elseif ast.tag == "LastStat" then
			new_text = new_text .. ast.text
			return
		else
			new_text = new_text .. ast.text
			text_tag.tag = ""
		end
	end


	if type(ast.data) == "table" then

		for k,v in pairs(ast.data) do

			functionComments(v,style)

		end

	end
end

--- This function creates template comment for function
-- @param ast ast tree of function
-- @style comment style to add
function createStyleComment(ast,style)

	if ast.tag == "ParList" then

		for part in string.gmatch(ast.text, "([^,%s]+)") do
			if style == "luadoc" then
				comment_style.luadoc = comment_style.luadoc .. "-- @param " .. part .. "\n"
			elseif style == "explua" then
				comment_style.explua = comment_style.explua .. "--@ " .. part .. " ()\n"
			end
		end
	elseif ast.text == "return" or ast.tag == "LastStat"then

		if return_found == false then
			if ast.text == "return" then
				return_found = true
			else
				local ret = findReturnValue(ast)
				return_found = true
				if ret == nil then
					ret = ""
					return_found = false
				end
				if style == "explua" then
					comment_style.explua = comment_style.explua .. "--: ".. ret .. " ()\n"
				elseif style == "luadoc" then
					comment_style.luadoc = comment_style.luadoc .. "-- @return ".. ret .. "\n"
				end
			end
		end

	elseif ast.tag == "FuncName" then
		if style == "luadoc" then
			comment_style.luadoc =  "-- The " .. ast.text .. " function\n" .. comment_style.luadoc .. "\n"
		elseif style == "explua" then
			comment_style.explua = comment_style.explua .. "The " .. ast.text .. " function\n---\n"
		end
	end
	if type(ast.data) == "table" then

		for k,v in pairs(ast.data) do

			createStyleComment(v,style)

		end

	end
	if style == "luadoc" then
		return comment_style.luadoc
	elseif style == "explua" then
		return comment_style.explua
	end
end

--- This function finds return statement in ast tree of function body
-- @param ast ast tree of function body
-- @return ret name of return value
function findReturnValue(ast)
		local ret = nil
		if ast.tag == "ExpList" then
			return ast.text
		end
		for k,v in pairs(ast.data) do

			ret = findReturnValue(v)

		end
	return ret
end


--- This function does string from ast tree
-- @param ast ast tree of source code
function astToString(ast)

	if ast.tag == "GlobalFunction" or ast.tag == "LocalFunction" or ast.tag == "Function" or ast.tag == "LocalAssign" then
		return
	end

	if  ast.tag == "IGNORED" or ast.tag == "Stat" or ast.tag == "LastStat" then
		new_text = new_text .. ast.text
	end


	if type(ast.data) == "table" then
		for k,v in pairs(ast.data) do
			astToString(v)
		end
	end
end


--- This function finds programming constructions (if, for, while) from given ast tree
-- @param ast ast tree of source code
function findConstructions(ast)

	if ast.tag == "If" then
		local info = {}
		local comm = mu.getComment(ast)

		if comm == nil then
			info.com = nil
		elseif (string.match(comm,"--_")) == "--_" then
			info.comm = 1
		else
			info.comm = nil
		end
		info.stat = "If"
		info.len = string.len(ast.text)
		info.pos = ast.position
		table.insert(stat_table,info)
	end

	if ast.tag == "GenericFor" or ast.tag == "NumericFor" or ast.tag == "While" then
		local info = {}
		local comm = mu.getComment(ast)

		if comm == nil then
			info.com = nil
		elseif (string.match(comm,"--_")) == "--_" then
			info.comm = 1
		else
			info.comm = nil
		end
		info.stat = "For"
		info.len = string.len(ast.text)
		info.pos = ast.position
		table.insert(stat_table,info)
	end

	if ast.tag == "FuncBody" then
		local info = {}
		local text = string.len(string.match(ast.text,"%([^%)]*%)"))
		local comm = string.match(string.sub(ast.text,string.len(text)),"%s%-%-%[%[") --matching --[[ at the start of function

		if comm ~= nil then
			info.comm = 1
		else
			info.comm = nil
		end
		info.stat = "FuncBody"
		info.len = string.len(ast.text)
		info.pos = ast.position + text + 1
		table.insert(stat_table,info)
	end

	if type(ast.data) == "table" then

		for k,v in pairs(ast.data) do

			findConstructions(v)

		end

	end
end


--- This function adds template comments to function body
function docstringComments()
	local shift = 0

	for k,v in pairs(stat_table) do
		if(stat_table[k].len > 100 and stat_table[k].comm == nil) then
			local part1 = string.sub(new_text,0,stat_table[k].pos+shift)
			local part2 = string.sub(new_text,stat_table[k].pos+shift+1)
			if stat_table[k].stat ~= "FuncBody" then
				local space = string.match(part1,"[^\n]*$")
				new_text = part1 .. "--_write comment\n" .. space .. part2
				shift = shift + 17 + string.len(space)
			elseif stat_table[k].stat == "FuncBody" then
				new_text = part1 .. "\t--[[\n\twrite docstring comment\n\t--]]\n" .. part2
				shift = shift + 37
			end
		end
	end
end
