
---@class markview.hl
---
---@field group_name? string
---@field value? table

---@class markview.hl.rgb
---
---@field r integer
---@field g integer
---@field b integer

---@class markview.hl.Lab
---
---@field L integer
---@field a integer
---@field b integer

------------------------------------------------------------------------------

--[[
*Dynamic* highlights for `markview.nvim` to match the current `colorscheme`.

Usage,

```lua
require("markview.highlights").setup();
```
]]
local highlights = {};

local function clamp (c)
	return math.min(
		math.max(
			0,
			math.floor(c)
		),
		255
	);
end

--[[ Turns given color into **RGB** color value. ]]
---@param input string | number
---@return markview.hl.rgb
highlights.rgb = function (input)
	---@type table<string, string> Common *color name* to `hex` color code mappings.
	local lookup = {
		["red"] = "#FF0000",        ["lightred"] = "#FFBBBB",      ["darkred"] = "#8B0000",
		["green"] = "#00FF00",      ["lightgreen"] = "#90EE90",    ["darkgreen"] = "#006400",    ["seagreen"] = "#2E8B57",
		["blue"] = "#0000FF",       ["lightblue"] = "#ADD8E6",     ["darkblue"] = "#00008B",     ["slateblue"] = "#6A5ACD",
		["cyan"] = "#00FFFF",       ["lightcyan"] = "#E0FFFF",     ["darkcyan"] = "#008B8B",
		["magenta"] = "#FF00FF",    ["lightmagenta"] = "#FFBBFF",  ["darkmagenta"] = "#8B008B",
		["yellow"] = "#FFFF00",     ["lightyellow"] = "#FFFFE0",   ["darkyellow"] = "#BBBB00",   ["brown"] = "#A52A2A",
		["grey"] = "#808080",       ["lightgrey"] = "#D3D3D3",     ["darkgrey"] = "#A9A9A9",
		["gray"] = "#808080",       ["lightgray"] = "#D3D3D3",     ["darkgray"] = "#A9A9A9",
		["black"] = "#000000",      ["white"] = "#FFFFFF",
		["orange"] = "#FFA500",     ["purple"] = "#800080",        ["violet"] = "#EE82EE"
	};

	---@type table<string, string> Neovim *color name* to `hex` color code mappings.
	local lookup_nvim = {
		["nvimdarkblue"] = "#004C73",    ["nvimlightblue"] = "#A6DBFF",
		["nvimdarkcyan"] = "#007373",    ["nvimlightcyan"] = "#8CF8F7",
		["nvimdarkgray1"] = "#07080D",   ["nvimlightgray1"] = "#EEF1F8",
		["nvimdarkgray2"] = "#14161B",   ["nvimlightgray2"] = "#E0E2EA",
		["nvimdarkgray3"] = "#2C2E33",   ["nvimlightgray3"] = "#C4C6CD",
		["nvimdarkgray4"] = "#4F5258",   ["nvimlightgray4"] = "#9B9EA4",
		["nvimdarkgrey1"] = "#07080D",   ["nvimlightgrey1"] = "#EEF1F8",
		["nvimdarkgrey2"] = "#14161B",   ["nvimlightgrey2"] = "#E0E2EA",
		["nvimdarkgrey3"] = "#2C2E33",   ["nvimlightgrey3"] = "#C4C6CD",
		["nvimdarkgrey4"] = "#4F5258",   ["nvimlightgrey4"] = "#9B9EA4",
		["nvimdarkgreen"] = "#005523",   ["nvimlightgreen"] = "#B3F6C0",
		["nvimdarkmagenta"] = "#470045", ["nvimlightmagenta"] = "#FFCAFF",
		["nvimdarkred"] = "#590008",     ["nvimlightred"] = "#FFC0B9",
		["nvimdarkyellow"] = "#6B5300",  ["nvimlightyellow"] = "#FCE094",
	};

	local hex;

	if type(input) == "string" and (lookup_nvim[input] or lookup[input]) then
		hex = lookup_nvim[input] or lookup[input];
	elseif type(input) == "number" then
		hex = string.format("#%06x", input);
	else
		hex = type(input) == "string" and input or "#FFFFFD";
	end

	return {
		r = tonumber(
			string.sub(hex, 2, 3),
			16
		),
		g = tonumber(
			string.sub(hex, 4, 5),
			16
		),
		b = tonumber(
			string.sub(hex, 6, 7),
			16
		),
	};
end

--[[ Simple RGB color mixer. ]]
---@param c1 markview.hl.rgb | markview.hl.Lab
---@param c2 markview.hl.rgb | markview.hl.Lab
---@param p1 number
---@param p2 number
---@return markview.hl.rgb | markview.hl.Lab
highlights.mix = function (c1, c2, p1, p2)
	local out = {};

	for k, v in pairs(c1) do
		if c2[k] then
			out[k] = (v * p1) + (c2[k] * p2);
		else
			out[k] = v;
		end
	end

	return out;
end

--[[ `RGB` to `hex color code` converter. ]]
---@param color markview.hl.rgb
---@return string
highlights.rgb_to_hex = function (color)
	return string.format(
		"#%02x%02x%02x",
		clamp(color.r),
		clamp(color.g),
		clamp(color.b)
	)
end

---|fS "chunk: sRGB <-> Oklab"

--[[
`sRGB` -> `Oklab` conversion.

Source: https://bottosson.github.io/posts/oklab/#converting-from-linear-srgb-to-oklab
License: https://bottosson.github.io/misc/License.txt
]]
---@param c markview.hl.rgb
---@return markview.hl.Lab
highlights.srgb_to_oklab = function (c)
    local l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
	local m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
	local s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;

    local l_ = math.pow(l, 1 / 3);
    local m_ = math.pow(m, 1 / 3);
    local s_ = math.pow(s, 1 / 3);

    return {
        L = 0.2104542553 *l_ + 0.7936177850 *m_ - 0.0040720468 *s_,
        a = 1.9779984951 *l_ - 2.4285922050 *m_ + 0.4505937099 *s_,
        b = 0.0259040371 *l_ + 0.7827717662 *m_ - 0.8086757660 *s_,
    };
end


--[[
`Oklab` -> `sRGB` conversion.

Source: https://bottosson.github.io/posts/oklab/#converting-from-linear-srgb-to-oklab
License: https://bottosson.github.io/misc/License.txt
]]
highlights.oklab_to_srgb = function (c)
    local l_ = c.L + 0.3963377774 * c.a + 0.2158037573 * c.b;
    local m_ = c.L - 0.1055613458 * c.a - 0.0638541728 * c.b;
    local s_ = c.L - 0.0894841775 * c.a - 1.2914855480 * c.b;

    local l = l_*l_*l_;
    local m = m_*m_*m_;
    local s = s_*s_*s_;

    return {
		r = clamp( 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
		g = clamp(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
		b = clamp(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
    };
end

--- Wrapper function for `nvim_set_hl()`.
---@param name string
---@param value table
highlights.set_hl = function (name, value)
	local found, v = pcall(vim.api.nvim_get_hl, 0, { name = name, create = false, link = false });

	if found and vim.tbl_isempty(v) == false then
		return;
	end

	value.default = true;
	local success, err = pcall(vim.api.nvim_set_hl, 0, name, value);

	if success == false and err then
		require("markview.health").notify("hl", {
			group = name,
			value = value,

			message = err
		});
	end
end

--- Creates highlight groups from an array of tables
---@param array { [string]: markview.hl | fun(): markview.hl }
highlights.create = function (array)
	if type(array) == "string" then
		if not highlights[array] then
			return;
		end

		array = highlights[array];
	end

	local hls = vim.tbl_keys(array) or {};
	table.sort(hls);

	for _, hl in ipairs(hls) do
		local _value = array[hl];
		local value;

		if type(_value) == "function" then
			local s, v = pcall(_value);

			if s then
				value = v;
			else
				value = {};
			end
		else
			value = _value;
		end

		if not hl:match("^Markview") then
			hl = "Markview" .. hl;
		end

		if vim.islist(value) and #value > 0 then
			---@cast value table[]
			for _, entry in ipairs(value) do
				highlights.set_hl(entry.group_name, entry.value);
			end
		elseif type(value) == "table" then
			---@cast value table
			highlights.set_hl(hl, value);
		end
	end
end

--- Is the background "dark"?
--- Returns values based on this condition(when provided).
---@param on_light any
---@param on_dark any
---@return any
local is_dark = function (on_light, on_dark)
	return vim.o.background == "dark" and on_dark or on_light;
end

--[[ Gets `property` from a list of `highlight group`s. ]]
---@param property string
---@param groups string[]
---@param light any
---@param dark any
---@return any
---@private
highlights.get_property = function (property, groups, light, dark)
	local val;

	for _, item in ipairs(groups) do
		local hl = vim.api.nvim_get_hl(0, { name = item, link = false, create = false });

		if vim.fn.hlexists(item) == 1 and hl[property] then
			val = hl[property];
			break;
		end
	end

	local fallback = is_dark(light, dark);

	if property == "fg" or property == "bg" or property == "sp" then
		if val then
			return highlights.rgb(val);
		else
			return fallback;
		end
	else
		return val ~= nil and val or fallback;
	end
end

------------------------------------------------------------------------------

highlights.create_pallete = function (n, src, light, dark)
	---@type markview.hl.rgb
	local nr = highlights.get_property(
		"bg",
		{ "LineNr" },
		nil,
		nil
	);

	local bg = highlights.srgb_to_oklab(highlights.get_property(
		"bg",
		{ "Normal" },
		"#EFF1F5",
		"#1E1E2E"
	));
	local fg = highlights.srgb_to_oklab(highlights.get_property(
		"fg",
		src,
		light or "#1E1E2E",
		dark or "#EFF1F5"
	));

	if not nr then
		nr = highlights.oklab_to_srgb(bg);
	end;

	---@type number
	local alpha = vim.g.markview_alpha or ( bg.L >= 0.5 and 0.15 or 0.25 );

	local _mix = highlights.mix(
		bg,
		fg,
		(1 - alpha),
		alpha
	) --[[ @as markview.hl.Lab ]];

	local mix = highlights.oklab_to_srgb(_mix);
	local _fg = highlights.oklab_to_srgb(fg);

	return {
		{
			group_name = string.format("MarkviewPalette%d", n),
			value = {
				bg = highlights.rgb_to_hex(mix),
				fg = highlights.rgb_to_hex(_fg)
			}
		},
		{
			group_name = string.format("MarkviewPalette%dSign", n),
			value = {
				bg = highlights.rgb_to_hex(nr),
				fg = highlights.rgb_to_hex(_fg)
			}
		},
		{
			group_name = string.format("MarkviewPalette%dFg", n),
			value = {
				fg = highlights.rgb_to_hex(_fg)
			}
		},
		{
			group_name = string.format("MarkviewPalette%dBg", n),
			value = {
				bg = highlights.rgb_to_hex(mix),
			}
		},
	};
end

highlights.inherit = function (from, with, properties)
	local _from = vim.api.nvim_get_hl(0, { name = from, link = false, create = false }) or {};
	local output = {};

	if properties and vim.islist(properties) then
		for _, property in ipairs(properties) do
			output[property] = _from[property];
		end
	else
		output = _from;
	end

	return vim.tbl_extend("force", output, with);
end

highlights.icon_hl = function (n)
	return highlights.inherit(
		"MarkviewCode",
		{
			fg = vim.api.nvim_get_hl(0, {
				name = string.format("MarkviewPalette%d", n),
				link = false, create = false
			}).fg
		}
	);
end


highlights.groups = {
	["0"] = function ()
		return highlights.create_pallete(
			0,
			{ "Comment" },
			"#9CA0B0",
			"#6C7086"
		);
	end,
	["1"] = function ()
		return highlights.create_pallete(
			1,
			{ "@markup.heading.1.markdown", "@markup.heading", "markdownH1"  },
			"#D20F39",
			"#F38BA8"
		);
	end,
	["2"] = function ()
		return highlights.create_pallete(
			2,
			{ "@markup.heading.2.markdown", "@markup.heading", "markdownH2"  },
			"#FAB387",
			"#FE640B"
		);
	end,
	["3"] = function ()
		return highlights.create_pallete(
			3,
			{ "@markup.heading.3.markdown", "@markup.heading", "markdownH3"  },
			"#DF8E1D",
			"#F9E2AF"
		);
	end,
	["4"] = function ()
		return highlights.create_pallete(
			4,
			{ "@markup.heading.4.markdown", "@markup.heading", "markdownH4"  },
			"#40A02B",
			"#A6E3A1"
		);
	end,
	["5"] = function ()
		return highlights.create_pallete(
			5,
			{ "@markup.heading.5.markdown", "@markup.heading", "markdownH5"  },
			"#209FB5",
			"#74C7EC"
		);
	end,
	["6"] = function ()
		return highlights.create_pallete(
			6,
			{ "@markup.heading.6.markdown", "@markup.heading", "markdownH6"  },
			"#7287FD",
			"#B4BEFE"
		);
	end,
	["7"] = function ()
		return highlights.create_pallete(
			7,
			{ "@conditional", "@keyword.conditional", "Conditional" },
			"#8839EF",
			"#CBA6F7"
		);
	end,

	["8"] = function ()
		local bg = highlights.srgb_to_oklab(highlights.get_property(
			"bg",
			{ "Normal" },
			"#EFF1F5",
			"#1E1E2E"
		));

		---@type number
		local alpha = vim.g.markview_code_alpha or ( bg.L >= 4 and 0.025 or 0.15 );

		local mix = {
			L = bg.L * (1 + (bg.L >= 4 and (-1 * alpha) or alpha)),
			a = bg.a,
			b = bg.b
		};

		return {
			{
				group_name = "MarkviewCode",
				value = {
					bg = highlights.rgb_to_hex(
						highlights.oklab_to_srgb(mix)
					)
				}
			},
		};
	end,
	["9"] = function ()
		local bg = highlights.srgb_to_oklab(highlights.get_property(
			"bg",
			{ "Normal" },
			"#EFF1F5",
			"#1E1E2E"
		));

		---@type number
		local alpha = vim.g.markview_inline_code_alpha or ( bg.L >= 4 and 0.025 or 0.2 );

		local mix = {
			L = bg.L * (1 + (bg.L >= 4 and (-1 * alpha) or alpha)),
			a = bg.a,
			b = bg.b
		};

		return {
			{
				group_name = "MarkviewInlineCode",
				value = {
					bg = highlights.rgb_to_hex(
						highlights.oklab_to_srgb(mix)
					)
				}
			},
		};
	end,

	["BlockQuoteDefault"] = { link = "MarkviewPalette0Fg" },
	["BlockQuoteError"] = { link = "MarkviewPalette1Fg" },
	["BlockQuoteNote"] = { link = "MarkviewPalette5Fg" },
	["BlockQuoteOk"] = { link = "MarkviewPalette4Fg" },
	["BlockQuoteSpecial"] = { link = "MarkviewPalette3Fg" },
	["BlockQuoteWarn"] = { link = "MarkviewPalette2Fg" },

	["CheckboxCancelled"] = { link = "MarkviewPalette0Fg" },
	["CheckboxChecked"] = { link = "MarkviewPalette4Fg" },
	["CheckboxPending"] = { link = "MarkviewPalette2Fg" },
	["CheckboxProgress"] = { link = "MarkviewPalette6Fg" },
	["CheckboxUnchecked"] = { link = "MarkviewPalette1Fg" },
	["CheckboxStriked"] = function ()
		return highlights.inherit(
			"MarkviewPalette0Fg",
			{
				strikethrough = true,
			}
		);
	end,

	["CodeInfo"] = function ()
		local fg = highlights.get_property(
			"fg",
			{ "Comment" },
			"#9CA0B0",
			"#6C7086"
		);

		return highlights.inherit(
			"MarkviewCode",
			{
				fg = highlights.rgb_to_hex(fg)
			}
		);
	end,
	["CodeFg"] = function ()
		local fg = highlights.get_property(
			"bg",
			{ "MarkviewCode" },
			"#ccced2",
			"#2d2d42"
		);

		return {
			fg = highlights.rgb_to_hex(fg)
		};
	end,

	["Icon0"] = function ()
		return highlights.icon_hl(0);
	end,
	["Icon1"] = function ()
		return highlights.icon_hl(1);
	end,
	["Icon2"] = function ()
		return highlights.icon_hl(2);
	end,
	["Icon3"] = function ()
		return highlights.icon_hl(3);
	end,
	["Icon4"] = function ()
		return highlights.icon_hl(4);
	end,
	["Icon5"] = function ()
		return highlights.icon_hl(5);
	end,
	["Icon6"] = function ()
		return highlights.icon_hl(6);
	end,

	["heading"] = function ()
		local output = {};

		for h = 1, 6, 1 do
			table.insert(output, {
				group_name = string.format("MarkviewHeading%d", h),
				value = { link = string.format("MarkviewPalette%d", h) }
			});
			table.insert(output, {
				group_name = string.format("MarkviewHeading%dSign", h),
				value = { link = string.format("MarkviewPalette%dSign", h) }
			});
		end

		return output;
	end,

	["Gradient"] = function ()
		local from = highlights.srgb_to_oklab(highlights.get_property(
			"bg",
			{ "Normal" },
			"#CDD6F4",
			"#1E1E2E"
		));
		local to   = highlights.srgb_to_oklab(highlights.get_property(
			"fg",
			{ "Title" },
			"#1e66f5",
			"#89b4fa"
		));

		local output = {};

		for i = 0, 9, 1 do
			local step = highlights.mix(
				from,
				to,
				1 - ( i / 9),
				i / 9
			);

			table.insert(output, {
				group_name = string.format("MarkviewGradient%d", i),
				value = {
					fg = highlights.rgb_to_hex(
						highlights.oklab_to_srgb(step)
					)
				}
			})
		end

		return output;
	end,

	["Hyperlink"] = { link = "@markup.link.label.markdown_inline" },
	["Image"] = { link = "@markup.link.label.markdown_inline" },
	["Email"] = { link = "@markup.link.url.markdown_inline" },
	["Subscript"] = { link = "MarkviewPalette3Fg" },
	["Superscript"] = { link = "MarkviewPalette6Fg" },

	["ListItemMinus"] = { link = "MarkviewPalette2Fg" },
	["ListItemPlus"] = { link = "MarkviewPalette4Fg" },
	["ListItemStar"] = { link = "MarkviewPalette6Fg" },

	["TableHeader"] = { link = "@markup.heading" },
	["TableBorder"] = { link = "MarkviewPalette5Fg" },
	["TableAlignLeft"] = { link = "@markup.heading" },
	["TableAlignCenter"] = { link = "@markup.heading" },
	["TableAlignRight"] = { link = "@markup.heading" },
};

--- Setup function.
---@param opt { [string]: markview.hl }?
highlights.setup = function (opt)
	if type(opt) == "table" then
		highlights.groups = vim.tbl_extend("force", highlights.groups, opt);
	end

	highlights.create(highlights.groups);
end

return highlights;
--- vim:foldmethod=indent:
