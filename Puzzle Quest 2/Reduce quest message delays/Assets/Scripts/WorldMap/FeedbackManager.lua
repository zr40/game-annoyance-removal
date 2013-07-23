use_safeglobals()

local FX = require("FXContainer")

local FeedbackManager = {}

local MAX_WIDTH = 800

FeedbackManager.feedback   = { }
FeedbackManager.gain_slots = { }

FeedbackManager.pending_objectives = { }

local function FMLOG(...)
	-- this can be commented out to remove debug logging for this file. Handy if you don't want a bunch of extra logging for a build.
	LOGF(...)
end


local function GetAsset(type, text1, text2, icon)
	if type == "gain" then
		local len
		if text2 then
			len = math.max(get_text_length("font_text_yellow", text1), get_text_length("font_text_yellow", text2))
		else
			len = get_text_length("font_text_yellow", text1)
		end
		len = len
		if icon then
			len = len + 85
		end
		if len <= 292 then
			return "img_gainbar_short", math.floor(371/2)
		elseif len <= 420 then
			return "img_gainbar_med", math.floor(509/2)
		elseif len <= 541 then
			return "img_gainbar_long", math.floor(541/2)
		end
	elseif type == "objective" then
		return "img_objbar_short", 580/2
	else
		error("Invalid feedback type!")
	end
end


function FeedbackManager.DisplayGain(title, subtitle)
	title = translate_text(title)
	if subtitle then
		subtitle = translate_text(subtitle)
	end

	local text_len_title
	local text_len_sub = 0
	if subtitle then
		text_len_title = get_text_length("font_text_white", title)
		text_len_sub = get_text_length("font_text_yellow", subtitle)
	else
		text_len_title = get_text_length("font_text_yellow", title)
	end

	FMLOG("[FeedbackManager.DisplayGain] title (len %d): %s", text_len_title, title)
	if subtitle then
		FMLOG("[FeedbackManager.DisplayGain] subtitle (len %d): %s", text_len_sub, subtitle)
	else
		FMLOG("[FeedbackManager.DisplayGain] no subtitle")
	end

	local lines = {} -- list of {text, font_tag, line_number, x_pos}. ypos is determined by baseY + (line_number-1)*LINE_HEIGHT.

	local menu = SCREENS.WorldMapMenu

	local function LOGLINE(line, subtitle_linenum)
		if not subtitle_linenum then
			FMLOG("[FeedbackManager.DisplayGain] title line:")
		else
			FMLOG("[FeedbackManager.DisplayGain] subtitle line %d:", subtitle_linenum)
		end
		FMLOG("[FeedbackManager.DisplayGain]       text:%s", line.text)
		FMLOG("[FeedbackManager.DisplayGain]       font:%s", line.font_tag)
		FMLOG("[FeedbackManager.DisplayGain]       line:%d", line.line_number)
		FMLOG("[FeedbackManager.DisplayGain]       xpos:%d", line.x_pos)
	end

	-- Remember, the text is centered around the x_pos not left-justified!
	local X_CENTER = SCREENS.EffectsMenu:get_widget_w("EffectsMenuEffectIcon") / 2 -- EffectsMenu has object with FXContainer attached as a child.
	if subtitle then
		local line_width = text_len_title + text_len_sub + 5
		if line_width > MAX_WIDTH then
			-- not going to fit, break it up.
			FMLOG("FeedbackManager.DisplayGain] title + subtitle won't fit on one line")
			-- title
			local line = {}
				line.text = title
				line.font_tag = "font_text_white"
				line.line_number = 1
				line.x_pos = X_CENTER
			table.insert(lines, line)
			LOGLINE(line)

			-- subtitle lines
			local line_text
			local line_height = WidgetHelpers.get_font_lineheight("font_text_yellow")
			local num_lines = menu.get_num_pages(subtitle, "font_text_yellow", MAX_WIDTH, line_height)
			for i= 1, num_lines do
				line_text = menu.get_page(subtitle, "font_text_yellow", MAX_WIDTH, line_height, i-1)
				line_width = get_text_length("font_text_yellow", line_text)
				line.text = line_text
				line.font_tag = "font_text_yellow"
				line.line_number = i+1
				line.x_pos = X_CENTER
				table.insert(lines, line)
				LOGLINE(line, i)
			end

		else
			-- fits in one line
			FMLOG("[FeedbackManager.DisplayGain] title + subtitle fits on one line")
			local x_start = X_CENTER - line_width/2
			local line = {}
				line.text = title
				line.font_tag = "font_text_white"
				line.line_number = 1
				line.x_pos = x_start + text_len_title/2
			table.insert(lines, line)
			LOGLINE(line)

			local subline = {}
				subline.text = subtitle
				subline.font_tag = "font_text_yellow"
				subline.line_number = 1
				subline.x_pos = x_start + text_len_title + 5 + text_len_sub/2
			table.insert(lines, subline)
			LOGLINE(subline, 0)
		end
	else
		-- no subtitle
		local line = {}
			line.text = title
			line.font_tag = "font_text_yellow"
			line.line_number = 1
			line.x_pos = X_CENTER
		table.insert(lines, line)
		LOGLINE(line)
	end

	local container = FX.CreateContainer(4000, 0)
	local x_offset = _G.GetScreenOffset()
	local y_pos = 80	--GetScreenHeight() - (menu:get_widget_y("str_questtext") + (WidgetHelpers.get_font_lineheight("font_text_yellow") / 2)) -- subtract from screen height because the FX container sees y coords upside down

	local fx_lines = {}
	FMLOG("[FeedbackManager.DisplayGain] Got %d lines", #lines)

	local function LOGFXTEXT(text, font_tag, x, y)
		FMLOG("[FeedbackManager.DisplayGain] Adding Text:%s font:%s, x:%d, y:%d", text, font_tag, x, y)
	end

	for _, line in ipairs(lines) do
		-- line = {text, font_tag, lineNumber, xpos}
		local line_height = WidgetHelpers.get_font_lineheight(line.font_tag)
		local y = y_pos + (line.line_number-1) * line_height
		-- FX.AddText(container,font_tag,"Awesome",x,y,hsc,vsc,rot,alpha,vis)
		LOGFXTEXT(line.text, line.font_tag, line.x_pos, y)
		local element = FX.AddText(container, line.font_tag, line.text, line.x_pos, y, 1.0, 1.0, 0.0, 0.0, true)
		table.insert(fx_lines, element)
	end

	-- lots of looping so the keyframes get added in the correct order
	local num_fx_lines = #fx_lines
	FMLOG("[FeedbackManager.DisplayGain] Got %d fx_lines", #fx_lines)
	-- start
	FMLOG("[FeedbackManager.DisplayGain] fx start")
	local displaytime = 0
	local keytype = FX.KEY_ALPHA
	local alpha_val = 0.0
	local interpolation = FX.DISCRETE

	local function LOGFXKEY(line_num, displaytime, keytype, alpha_val, interpolation)
		FMLOG("[FeedbackManager.DisplayGain] Adding Key for fx_line[%d]:- time:%d, type:%s, alpha:%.1f, interp:%s", line_num, displaytime, keytype, alpha_val, interpolation)
	end

	for i= 1, num_fx_lines do
		LOGFXKEY(i, displaytime, keytype, alpha_val, interpolation)
		FX.AddKey(container, fx_lines[i], displaytime,  keytype, alpha_val, interpolation)
	end

	-- fade in
	FMLOG("[FeedbackManager.DisplayGain] fx fade in")
	displaytime = 50
	alpha_val = 1.0
	interpolation = FX.SMOOTH
	for i= 1, num_fx_lines do
		LOGFXKEY(i, displaytime, keytype, alpha_val, interpolation)
		FX.AddKey(container, fx_lines[i], displaytime, keytype, alpha_val, interpolation)
	end

	-- hold
	FMLOG("[FeedbackManager.DisplayGain] fx hold")
	displaytime = 150
	interpolation = FX.DISCRETE
	for i= 1, num_fx_lines do
		LOGFXKEY(i, displaytime, keytype, alpha_val, interpolation)
		FX.AddKey(container, fx_lines[i], displaytime, keytype, alpha_val, interpolation)
	end

	-- fade out
	FMLOG("[FeedbackManager.DisplayGain] fx fade out")
	alpha_val = 0.0
	displaytime = 200
	interpolation = FX.SMOOTH
	for i= 1, num_fx_lines do
		LOGFXKEY(i, displaytime, keytype, alpha_val, interpolation)
		FX.AddKey(container, fx_lines[i], displaytime, keytype, alpha_val, interpolation)
	end

	local world = SCREENS.EffectsMenu:GetWorld()
	FX.Start(world, container, 0, 368)
	table.insert(FeedbackManager.feedback, 1, {object=world, type="gain"})
	return displaytime, container
end


function FeedbackManager.DisplayObjective(title, subtitle)
	local menu = SCREENS.WorldMapMenu -- why, why, WHY, is get_page a menu function??
	title = translate_text(title)
	local text_len_title = get_text_length("font_text_yellow", title)
	subtitle = translate_text(subtitle)
	local text_len_sub   = get_text_length("font_text_yellow", subtitle)

	FMLOG("[FeedbackManager.DisplayObjective] title (len %d): %s", text_len_title, title)
	FMLOG("[FeedbackManager.DisplayObjective] subtitle (len %d): %s", text_len_sub, subtitle)

	local function LOGLINE(line, subtitle_linenum)
		if not subtitle_linenum then
			FMLOG("[FeedbackManager.DisplayObjective] title line:")
		else
			FMLOG("[FeedbackManager.DisplayObjective] subtitle line %d:", subtitle_linenum)
		end
		FMLOG("[FeedbackManager.DisplayObjective]       text:%s", line.text)
		FMLOG("[FeedbackManager.DisplayObjective]       font:%s", line.font_tag)
		FMLOG("[FeedbackManager.DisplayObjective]       line:%d", line.line_number)
		FMLOG("[FeedbackManager.DisplayObjective]       xpos:%d", line.x_pos)
	end

	local X_CENTER = SCREENS.EffectsMenu:get_widget_w("EffectsMenuEffectIcon") / 2 -- EffectsMenu has object with FXContainer attached as a child.
	local lines = {}
	local single_line_width = text_len_title + text_len_sub + 5
	if single_line_width > MAX_WIDTH then
		-- Not going to fit, break it up. Show title at top then split objective text into however many lines are needed and show them
		-- title
		FMLOG("[FeedbackManager.DisplayObjective] title + subtitle won't fit on one line")
		local line = {}
		line.text = title
		line.font_tag = "font_text_white"
		line.line_number = 1
		line.x_pos = X_CENTER
		table.insert(lines, line)
		LOGLINE(line)

		local line_height = WidgetHelpers.get_font_lineheight("font_text_yellow")
		local num_lines = menu.get_num_pages(subtitle, "font_text_yellow", MAX_WIDTH, line_height)
		for i= 1, num_lines do
			local subline = {}
			subline.text = menu.get_page(subtitle, "font_text_yellow", MAX_WIDTH, line_height, i-1)
			subline.font_tag = "font_text_yellow"
			subline.line_number = i+1
			subline.x_pos = X_CENTER
			table.insert(lines, subline)
			LOGLINE(subline, i)
		end
	else
		-- all fits on one line, show it that way
		local x_start = X_CENTER - single_line_width/2
		local line = {}
			line.text = title
			line.font_tag = "font_text_white"
			line.line_number = 1
			line.x_pos = x_start + text_len_title/2
		table.insert(lines, line)
		LOGLINE(line)

		local subline = {}
			subline.text = subtitle
			subline.font_tag = "font_text_yellow"
			subline.line_number = 1
			subline.x_pos = x_start + text_len_title + 5 + text_len_sub/2
		table.insert(lines, subline)
		LOGLINE(line)
	end

	local container = FX.CreateContainer(1000 + (#lines * 1000), 0) -- 0.5 sec fade in + 2 sec/line + 0.5 sec fade out
	local x_offset = _G.GetScreenOffset()
	local y_pos = 80	--GetScreenHeight() - (menu:get_widget_y("str_questtext") + (WidgetHelpers.get_font_lineheight("font_text_yellow") / 2)) -- subtract from screen height because the FX container sees y coords upside down
	local fx_lines = {}
	FMLOG("[FeedbackManager.DisplayObjective] Got %d lines. Base y_pos=%d", #lines, y_pos)

	local function LOGFXTEXT(text, font_tag, x, y)
		FMLOG("[FeedbackManager.DisplayObjective] Adding Text:%s font:%s, x:%d, y:%d", text, font_tag, x, y)
	end

	for _, line in ipairs(lines) do
		-- line = {text, font_tag, lineNumber, xpos}
		local line_height = WidgetHelpers.get_font_lineheight(line.font_tag)
		local y = y_pos - (line.line_number-1) * line_height
		FMLOG("[FeedbackManager.DisplayObjective] y  =%d(base y_pos) - (%d(line_number) - 1) * %d(line_height)", y_pos, line.line_number, line_height)
		LOGFXTEXT(line.text, line.font_tag, line.x_pos, y)
		local element = FX.AddText(container, line.font_tag, line.text, line.x_pos, y, 1.0, 1.0, 0.0, 0.0, true)
		table.insert(fx_lines, element)
	end

	local num_fx_lines = #fx_lines
	FMLOG("[FeedbackManager.DisplayObjective] Got %d fx_lines", num_fx_lines)

	-- start
	FMLOG("[FeedbackManager.DisplayObjective] fx start")
	local displaytime = 0
	local keytype = FX.KEY_ALPHA
	local alpha_val = 0.0
	local interpolation = FX.DISCRETE

	local function LOGFXKEY(line_num, displaytime, keytype, alpha_val, interpolation)
		LOGF("[FeedbackManager.DisplayObjective] Adding Key for fx_line[%d]:- time:%d, type:%s, alpha:%.1f, interp:%s", line_num, displaytime, keytype, alpha_val, interpolation)
	end

	for i= 1, num_fx_lines do
		LOGFXKEY(i, displaytime, keytype, alpha_val, interpolation)
		FX.AddKey(container, fx_lines[i], displaytime,  keytype, alpha_val, interpolation)
	end

	-- fade in
	FMLOG("[FeedbackManager.DisplayObjective] fx fade in")
	displaytime = 50
	alpha_val = 1.0
	interpolation = FX.SMOOTH
	for i= 1, num_fx_lines do
		LOGFXKEY(i, displaytime, keytype, alpha_val, interpolation)
		FX.AddKey(container, fx_lines[i], displaytime, keytype, alpha_val, interpolation)
	end

	-- hold
	FMLOG("[FeedbackManager.DisplayObjective] fx hold")
	displaytime = displaytime + (num_fx_lines * 100)
	interpolation = FX.DISCRETE
	for i= 1, num_fx_lines do
		LOGFXKEY(i, displaytime, keytype, alpha_val, interpolation)
		FX.AddKey(container, fx_lines[i], displaytime, keytype, alpha_val, interpolation)
	end

	-- fade out
	FMLOG("[FeedbackManager.DisplayObjective] fx fade out")
	alpha_val = 0.0
	displaytime = displaytime + 50
	interpolation = FX.SMOOTH
	for i= 1, num_fx_lines do
		LOGFXKEY(i, displaytime, keytype, alpha_val, interpolation)
		FX.AddKey(container, fx_lines[i], displaytime, keytype, alpha_val, interpolation)
	end

	local world = SCREENS.EffectsMenu:GetWorld()
	FX.Start(world, container, 0, 368)
	FeedbackManager.gain_slots.objective = {object=world, type="gain", slot = "objective" }

	return displaytime, container

end

function FeedbackManager.SetAlpha(alpha)
	-- unused by the current FeedbackManager system
	error("Unused function FeedbackManager.SetAlpha")
end

function FeedbackManager.Update()
	-- unused by the current FeedbackManager system
	error("Unused function FeedbackManager.Update")
end

function FeedbackManager.Insert(title, subtitle, display, icon)
	LOG("[FeedbackManager.Insert]:")
	LOGF("Title:%s", tostring(title))
	LOGF("Subtitle:%s", tostring(subtitle))
	LOGF("Display (type):%s", tostring(display))
	assert(type(title) == "string")
	local time_taken = 0
	local container
	if display == "gain" then
		time_taken, container = FeedbackManager.DisplayGain(title, subtitle, icon)
	elseif display == "objective" then
		time_taken, container = FeedbackManager.DisplayObjective(title, subtitle)
	end
	return time_taken, container
end

return FeedbackManager
