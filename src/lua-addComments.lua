-- comment.templateComments launcher, by Peter Mendel, 05/2014


local tc = require "comments.templateComments"
local string = string
local style = ""
local func = false
local path = ""
local output
-- Print usage message.

local function print_help ()
print ("Usage: "..arg[0]..[[ 
Add function comments or docstring comments to given file or directory of files. 
Available options are:
  -p path                      	input directory or file path
  -f 				add function comments
  -d  				add docstring comments
  -s style                     	style of comments you want to add (explua, luadoc)
  -o path			output directory (optional)
  -h, --help                   	print this help and exit]])
end
-------------------------------------------------------------------------------
-- Process options.
-- @class table
-- @name OPTIONS

local OPTIONS = {
	p = function (arg, i)
		local dir = arg[i+1]
		path = dir
		return 1
	end,
	f = function (arg, i)
		func = true
		return 1
	end,
	d = function (arg, i)
		func = false
		return 1
	end,
	s = function (arg, i)
		if string.find(arg[i+1],"explua") then
			style = "explua"
		elseif string.find(arg[i+1],"luadoc") then
			style = "luadoc"
		end
		return 1
	end,
	o = function (arg, i)
		local dir2 = arg[i+1]
		output = dir2
		return 1
	end,
	h = print_help,
	help = print_help,
}

-------------------------------------------------------------------------------

local function process_options (arg)
	
	local i = 1
	while i < #arg or i == #arg do
		local argi = arg[i]		
		if string.sub (argi, 1, 1) == '-' then

			local opt = string.sub (argi, 2)

			if string.sub (opt, 1, 1) == '-' then
				opt = string.gsub (opt, "%-", "")

			end
			if OPTIONS[opt] then
				if OPTIONS[opt] (arg, i) then
					i = i + 1
				else i = i + 1
				end
			else i = i + 1
			end
		else i = i + 1
		end
	end
end 

-- Main function. Process command-line parameters and call comments.templateComments addComments function.

function main (arg)

	local argc = #arg
	if argc < 1 then
		print_help ()
		return
	end
	process_options (arg)
	if style == "" then
		style = "luadoc"
	end
	if path ~= "" then
		if output == nil then
			output = path
		end
		return tc.addComments(path, style, func, output)
	end
end

main(arg)
