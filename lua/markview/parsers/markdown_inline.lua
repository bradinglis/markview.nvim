local inline = {};

--- Queried contents
---@type table[]
inline.content = {};

--- Queried contents, but sorted
inline.sorted = {}

inline.insert = function (data)
	table.insert(inline.content, data);

	if not inline.sorted[data.class] then
		inline.sorted[data.class] = {};
	end

	table.insert(inline.sorted[data.class], data);
end

--- Cached stuff
---@type { checkbox: { [integer]: table } }
inline.cache = {
	checkbox = {},
	link_ref = {}
}

--- Checkbox parser.
---@param buffer integer
---@param range markview.parsed.range
inline.checkbox = function (buffer, _, text, range)
	local line = vim.api.nvim_buf_get_lines(buffer, range.row_start, range.row_start + 1, false)[1];

	local before = line:sub(0, range.col_start);
	local inner = line:sub(range.col_start + 1, range.col_end - 1);

	if before:match("^[%s%>]*[%-%+%*]%s$") == nil and before:match("^[%s%>]*%d+[%.%)]%s$") == nil then
		return;
	end

	inline.insert({
		class = "inline_checkbox",
		state = inner:gsub("[%[%]]", ""),

		text = text,
		range = range
	});

	--- Cache the current checkbox.
	--- TODO, Has no use *yet*.
	inline.cache.checkbox[range.row_start] = inline.content[#inline.content];
end

--- Inline code parser.
---@param text string[]
---@param range markview.parsed.range
inline.code_span = function (_, _, text, range)
	inline.insert({
		class = "inline_code_span",

		text = text,
		range = range
	});
end

--- Embed file link parser.
---@param text string[]
---@param range markview.parsed.markdown_inline.block_refs.range | markview.parsed.range
inline.embed_file = function (_, _, text, range)
	if text[1]:match("%#%^(.+)%]%]$") then
		---@cast range markview.parsed.markdown_inline.block_refs.range

		local file, block = text[1]:match("^%!%[%[(.*)%#%^(.+)%]%]$");

		range.label = { range.row_start, range.col_start + 3, range.row_end, range.col_end - 2 };
		range.block = { range.row_start, range.col_start + 3 + #file + 2, range.row_end, range.col_end - 2 };

		if file ~= "" then
			range.file  = { range.row_start, range.col_start + 3, range.row_end, range.col_start + 3 + #file };
		else
			file = nil;
		end

		inline.insert({
			class = "inline_link_block_ref",
			file = file,
			block = block,
			label = string.format("%s#^%s", file, block),

			text = text,
			range = range
		});
	else
		---@cast range markview.parsed.range

		inline.insert({
			class = "inline_link_embed_file",
			label = text[1]:match("%[%[([^%[+])%]%]"),

			text = text,
			range = range
		});
	end
end

--- Email parser.
---@param text string[]
---@param range markview.parsed.markdown_inline.emails.range
inline.email = function (_, _, text, range)
	range.label = { range.row_start, range.col_start + 1, range.row_end, range.col_end - 1 };

	inline.insert({
		class = "inline_link_email",
		label = text[1]:sub(2, #text[1] - 1),

		text = text,
		range = range
	});
end

--- Github like emoji shorthand parser.
---@param range markview.parsed.range
inline.emojis = function (_, TSNode, text, range)
	local parent = TSNode:parent();

	while parent do
		if parent:type() == "inline" then
			return;
		end

		parent = parent:parent();
	end

	local utils = require("markview.utils");
	local lines = text;

	for l, line in ipairs(lines) do
		local col_start = l == 1 and range.col_start or 0;

		local _line = line;
		_line = _line:gsub("%`.-%`", function (s)
			return string.rep("Y", vim.fn.strchars(s));
		end);

		for short_code in _line:gmatch("%:[%a%d%_%+%-]+%:") do
			local c_s, c_e = _line:find(short_code, 0, #_line, true);

			inline.insert({
				class = "inline_emoji",
				name = short_code:gsub(":", ""),
				text = { short_code },

				range = {
					row_start = range.row_start + (l - 1),
					col_start = col_start + c_s - 1,

					row_end = range.row_start + (l - 1),
					col_end = col_start + c_e
				}
			});

			_line = _line:gsub(utils.escape_string(short_code), function (s)
				return string.rep("X", vim.fn.strchars(s));
			end, 1);
		end
	end
end

--- Uri autolink parser.
---@param text string[]
---@param range markview.parsed.range
inline.entity = function (_, _, text, range)
	inline.insert({
		class = "inline_entity",
		name = text[1]:gsub("[^%a%d]", ""),

		text = text,
		range = range
	});
end

--- Uri autolink parser.
---@param text string[]
---@param range markview.parsed.range
inline.escaped = function (_, _, text, range)
	inline.insert({
		class = "inline_escaped",

		text = text[1]:sub(1, 3),
		range = range
	});
end

--- Footnote parser.
---@param text string[]
---@param range markview.parsed.markdown_inline.footnotes.range
inline.footnote = function (_, _, text, range)
	local label = table.concat(text, ""):gsub("^%[%^", ""):gsub("%]$", "");
	range.label = { range.row_start, range.col_start + 2, range.row_end, range.col_end - 1 };

	inline.insert({
		class = "inline_footnote",

		text = text[1],
		label = label,

		range = range
	});
end

--- Highlight parser.
---@param TSNode table
---@param text string[]
---@param range markview.parsed.range
inline.highlights = function (_, TSNode, text, range)
	local parent = TSNode:parent();

	while parent do
		if parent:type() == "inline" then
			return;
		end

		parent = parent:parent();
	end

	local utils = require("markview.utils");
	local lines = text;

	for l, line in ipairs(lines) do
		local col_start = l == 1 and range.col_start or 0;

		local _line = line;
		_line = _line:gsub("%`.-%`", function (s)
			return string.rep("Y", vim.fn.strchars(s));
		end);

		for highlight in _line:gmatch("%=%=[^=]+%=%=") do
			local c_s, c_e = _line:find(highlight, 0, true);

			inline.insert({
				class = "inline_highlight",
				text = { highlight },

				range = {
					row_start = range.row_start + (l - 1),
					col_start = col_start + c_s - 1,

					row_end = range.row_start + (l - 1),
					col_end = col_start + c_e
				}
			});

			_line = _line:gsub(utils.escape_string(highlight), function (s)
				return string.rep("X", vim.fn.strchars(s));
			end, 1);
		end
	end
end

--- Image link parser.
---@param TSNode table
---@param text string[]
---@param range markview.parsed.range | markview.parsed.markdown_inline.images.range
inline.image = function (buffer, TSNode, text, range)
	if text[1]:match("^%!%[%[") and text[1]:match("%]%]$") then
		---@cast range markview.parsed.range

		--- This is an embed file,
		--- Not an image!
		inline.embed_file(buffer, TSNode, text, range);
		return;
	end

	---@cast range markview.parsed.markdown_inline.images.range

	local link_label;
	local link_desc;

	for child in TSNode:iter_children() do
		if child:type() == "image_description" then
			link_label = vim.treesitter.get_node_text(child, buffer):gsub("[%[%]%(%)]", "");
			range.label = { child:range() };
		elseif child:type() == "link_label" or child:type() == "link_destination" then
			link_desc = vim.treesitter.get_node_text(child, buffer):gsub("[%[%]%(%)]", "");
			range.description = { child:range() };
		end
	end

	range.label = range.label or { range.row_start, range.col_start + 2, range.row_end, range.col_start - 3 };

	inline.insert({
		class = "inline_link_image",

		text = text,
		description = link_desc,
		label = link_label,

		range = range
	});
end

--- Hyperlink parser.
---@param buffer integer
---@param text string[]
---@param range markview.parsed.markdown_inline.hyperlinks.range
inline.hyperlink = function (buffer, TSNode, text, range)
	local link_desc;
	local link_label;

	for child in TSNode:iter_children() do
		if child:type() == "link_text" then
			link_label = vim.treesitter.get_node_text(child, buffer):gsub("[%[%]%(%)]", "");
			range.label = { child:range() };
		elseif child:type() == "link_label" or child:type() == "link_destination" then
			link_desc = vim.treesitter.get_node_text(child, buffer):gsub("[%[%]%(%)]", "");
			range.description = { child:range() };
		end
	end

	range.label = range.label or { range.row_start, range.col_start + 1, range.row_end, range.col_start - 1 };

	inline.insert({
		class = "inline_link_hyperlink",

		text = text,
		description = link_desc,
		label = link_label,

		range = range
	});
end

--- URI autolink parser.
---@param text string[]
---@param range markview.parsed.markdown_inline.block_refs.range | markview.parsed.markdown_inline.internal_links.range
inline.internal_link = function (_, _, text, range)
	if string.match(text[1], "%#%^.+$") ~= nil then
		---@cast range markview.parsed.markdown_inline.block_refs.range

		local file, block = text[1]:match("^%[%[(.*)%#%^(.+)$");
		range.label = { range.row_start, range.col_start + 2, range.row_end, range.col_end - 2 };

		range.block = { range.row_start, range.col_start + 2 + #file + 2, range.row_end, range.col_end - 2 };

		if file ~= "" then
			range.file  = { range.row_start, range.col_start + 2, range.row_end, range.col_start + 2 + #file };
		else
			file = nil;
		end

		inline.insert({
			class = "inline_link_block_ref",

			file = file,
			block = block,
			label = string.format("%s#^%s", file, block),

			text = text,

			range = range
		});
	else
		---@cast range markview.parsed.markdown_inline.internal_links.range

		local label = text[1]:match("^%[%[(.+)%]%]");
		local alias_start, alias_end, alias = text[1]:find("%|([^%|]+)%]%]$");

		if type(alias) == "string" and type(alias_start) == "number" and type(alias_end) == "number" then
			range.alias = { range.row_start, range.col_start + alias_start, range.row_end, range.col_end - 1 };
		end

		range.label = { range.row_start, range.col_start + 2, range.row_end, range.col_end - 2 };

		inline.insert({
			class = "inline_link_internal",

			text = text,
			alias = alias,
			label = label,

			range = range
		});
	end
end

--- Reference link parser.
---@param buffer integer
---@param TSNode table
---@param text string[]
---@param range markview.parsed.markdown_inline.hyperlinks.range
inline.reference_link = function (buffer, TSNode, text, range)
	local link_desc;
	local link_label;

	for child in TSNode:iter_children() do
		if child:type() == "link_text" then
			link_label = vim.treesitter.get_node_text(child, buffer):gsub("[%[%]%(%)]", "");
			range.label = { child:range() };
		elseif child:type() == "link_label" or child:type() == "link_destination" then
			link_desc = vim.treesitter.get_node_text(child, buffer):gsub("[%[%]%(%)]", "");
			range.description = { child:range() };
		end
	end

	range.label = range.label or { range.row_start, range.col_start + 1, range.row_end, range.col_end - 3 };

	inline.insert({
		class = "inline_link_hyperlink",

		text = text,
		description = link_desc,
		label = link_label,

		range = range
	});
end

--- Shortcut link parser.
---@param buffer integer
---@param TSNode table
---@param text string[]
---@param range markview.parsed.markdown_inline.internal_links.range | markview.parsed.markdown_inline.hyperlinks.range
inline.shortcut_link = function (buffer, TSNode, text, range)
	local s_line = vim.api.nvim_buf_get_lines(buffer, range.row_start, range.row_start + 1, false)[1];
	local e_line = vim.api.nvim_buf_get_lines(buffer, range.row_end, range.row_end + 1, false)[1];

	local before = s_line:sub(0, range.col_start);
	local after  = e_line:sub(range.col_end);

	if text[1]:match("^%[%^") then
		--- Footnote
		return;
	elseif before:match("^[%s%>]*[%+%-%*]%s+$") and text[1]:match("^%[.%]$") then
		--- Checkbox
		return;
	elseif before:match("^[%s%>]*%d+[%.%)]%s+$") and text[1]:match("^%[.%]$") then
		--- Checkbox (ordered list item)
		return;
	elseif before:match("%>%s*$") then
		--- Callout
		return;
	elseif before:match("%!%[$") and after:match("^%]") then
		--- Embed file
		return;
	elseif before:match("%[$") and after:match("^%]") then
		if range.row_start ~= range.row_end then
			goto invalid_link;
		end

		---@cast range markview.parsed.markdown_inline.internal_links.range

		text[1]     = "[" .. text[1];
		text[#text] = text[#text] .. "]";

		range.col_start = range.col_start - 1;
		range.col_end   = range.col_end + 1;

		--- Obsidian internal link
		inline.internal_link(buffer, TSNode, text, range);
		return;
	end

	::invalid_link::

	---@cast range markview.parsed.markdown_inline.hyperlinks.range

	local link_desc;
	local link_label;

	for child in TSNode:iter_children() do
		if child:type() == "link_text" then
			link_label = vim.treesitter.get_node_text(child, buffer):gsub("[%[%]%(%)]", "");
			range.label = { child:range() };
		elseif child:type() == "link_label" or child:type() == "link_destination" then
			link_desc = vim.treesitter.get_node_text(child, buffer):gsub("[%[%]%(%)]", "");
			range.description = { child:range() };
		end
	end

	range.label = range.label or { range.row_start, range.col_start + 1, range.row_end, range.col_start - 1 };

	inline.insert({
		class = "inline_link_shortcut",
		label = link_label,
		description = link_desc,

		text = text,
		range = range
	});
end

--- Uri autolink parser.
---@param TSNode table
---@param text string[]
---@param range markview.parsed.markdown_inline.uri_autolinks.range
inline.uri_autolink = function (_, TSNode, text, range)
	range.label = { range.row_start, range.col_start + 1, range.row_end, range.col_end - 1 };

	inline.insert({
		class = "inline_link_uri_autolink",
		node = TSNode,

		text = text,
		label = text[1]:sub(2, #text[1] - 1),

		range = range
	});
end

--- Inline markdown parser.
---@param buffer integer
---@param TSTree table
---@param from integer?
---@param to integer?
---@return table[]
---@return table
inline.parse = function (buffer, TSTree, from, to)
	inline.sorted = {};
	inline.content = {};

	local pre_queries = vim.treesitter.query.parse("markdown_inline", [[
		(
			(shortcut_link) @markdown_inline.checkbox
			(#match? @markdown_inline.checkbox "^\\[.\\]$")) ; Fix the match pattern to match literal [ & ]
	]]);

	for capture_id, capture_node, _, _ in pre_queries:iter_captures(TSTree:root(), buffer, from, to) do
		local capture_name = pre_queries.captures[capture_id];
		local r_start, c_start, r_end, c_end = capture_node:range();

		local capture_text = vim.api.nvim_buf_get_lines(buffer, r_start, r_start == r_end and r_end + 1 or r_end, false);

		inline[capture_name:gsub("^markdown_inline%.", "")](buffer, capture_node, capture_text, {
			row_start = r_start,
			col_start = c_start,

			row_end = r_end,
			col_end = c_end
		});
	end

	local scanned_queries = vim.treesitter.query.parse("markdown_inline", [[
		((inline) @markdown_inline.highlights
			(#match? @markdown_inline.highlights "\\=\\=.+\\=\\="))

		((inline) @markdown_inline.emojis
			(#match? @markdown_inline.emojis "\\:.+\\:"))

		((email_autolink) @markdown_inline.email)

		((image) @markdown_inline.image)

		([
			(inline_link)
			(collapsed_reference_link)] @markdown_inline.hyperlink)

		((full_reference_link
			(link_text)
			(link_label)) @markdown_inline.reference_link)

		((shortcut_link
			(link_text) @footnote.text
			(#match? @footnote.text "^\\^")) @markdown_inline.footnote)

		((shortcut_link) @markdown_inline.shortcut_link)

		((uri_autolink) @markdown_inline.uri_autolink)

		((code_span) @markdown_inline.code_span)

		([
			(entity_reference)
			(numeric_character_reference)] @markdown_inline.entity)

		((backslash_escape) @markdown_inline.escaped)
	]]);

	for capture_id, capture_node, _, _ in scanned_queries:iter_captures(TSTree:root(), buffer, from, to) do
		local capture_name = scanned_queries.captures[capture_id];

		if not capture_name:match("^markdown_inline") then
			goto continue;
		end

		---@type string?
		local capture_text = vim.treesitter.get_node_text(capture_node, buffer);
		local r_start, c_start, r_end, c_end = capture_node:range();

		if capture_text == nil then
			goto continue;
		end

		---@type string[]
		local lines = vim.split(capture_text, "\n", {});

		---@type boolean, string
		local success, error = pcall(
			inline[capture_name:gsub("^markdown_inline%.", "")],
			buffer,
			capture_node,
			lines,

			{
				row_start = r_start,
				col_start = c_start,

				row_end = r_end,
				col_end = c_end
			}
		);

		if success == false then
			require("markview.health").notify("trace", {
				level = 4,
				message = error
			});
		end

	   ::continue::
	end

	return inline.content, inline.sorted;
end

return inline;
