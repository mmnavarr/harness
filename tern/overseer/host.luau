local ui = tern.ui
local Input = require("./input")

local function text(key, value, role)
	return ui.node("text", { key = key, text = value, role = role or "overseer.label" })
end

local function fieldOrder(state)
	return if state.mode == "project" then { "path", "name", "base" } elseif state.mode == "rename" then { "name" } else { "branch", "name" }
end

local function focus(state, cx)
	pcall(function()
		cx:frame({ { "focus", "main." .. state.focus } })
	end)
end

local function finish(state, cancelled)
	if state.submitted then
		return
	end
	local response
	if cancelled then
		response = { cancelled = true }
	elseif state.mode == "project" then
		if not string.find(state.fields.path.text, "%S") then
			state.error = "Enter a repository path."
			state.focus = "path"
			return
		end
		response = {
			mode = "project", path = state.fields.path.text,
			name = state.fields.name.text, base = state.fields.base.text,
		}
	elseif state.mode == "rename" then
		response = { mode = "rename", name = state.fields.name.text }
	else
		if not string.find(state.fields.branch.text, "%S") then
			state.error = "Enter a branch name."
			state.focus = "branch"
			return
		end
		response = { mode = "create", branch = state.fields.branch.text, name = state.fields.name.text }
	end
	local ok, err = pcall(tern.kv.set, "form:" .. state.token, response)
	if not ok then
		state.error = "Could not send form: " .. tostring(err)
		return
	end
	state.submitted, state.cancelled, state.error = true, cancelled, nil
end

tern.block.define("form", {
	init = function(_cx, args, saved)
		local mode = if args[2] == "create" or args[2] == "rename" then args[2] else "project"
		local state = {
			token = args[1] or "", mode = mode, project = args[3] or "",
			base = args[4] or "master", focus = if mode == "project" then "path" elseif mode == "rename" then "name" else "branch",
			fields = {}, submitted = false, cancelled = false, focusScheduled = false,
		}
		state.fields = {
			path = Input.new(if mode == "project" then args[3] or "" else ""),
			name = Input.new(if mode == "rename" then args[4] or "" else ""),
			base = Input.new(args[4] or "master"), branch = Input.new(""),
		}
		if type(saved) == "table" and saved.token == state.token and saved.mode == mode then
			for name, field in pairs(state.fields) do
				if type(saved.fields) == "table" and type(saved.fields[name]) == "string" then
					state.fields[name] = Input.new(saved.fields[name])
				end
			end
			if state.fields[saved.focus] then
				state.focus = saved.focus
			end
			state.submitted = saved.submitted == true
			state.cancelled = saved.cancelled == true
		end
		-- A restarted form must never publish its response a second time.
		if state.token == "" then
			state.error = "Missing form token. Close this pane and reopen the form from Projects."
			state.submitted = true
		else
			local ok, response = pcall(tern.kv.get, "form:" .. state.token)
			if ok and response ~= nil then
				state.submitted = true
				state.cancelled = type(response) == "table" and response.cancelled == true
			end
		end
		return state
	end,
	-- The form occupies the Projects panel's slot, so keep the panel's title.
	title = function()
		return "Projects"
	end,
	view = function(state, cx)
		local heading = if state.mode == "project" then "Add project" elseif state.mode == "rename" then "Rename worktree" else "New worktree"
		local children = {
			-- In a row so the link is only as wide as its text, not the whole pane.
			ui.node("row", { key = "nav" }, {
				ui.el("button", {
					key = "back", role = "overseer.backLink", text = "← Projects",
					title = "Back to Projects (Esc)", actions = { click = "cancel" },
				}),
			}),
			text("heading", heading, "overseer.formHeading"),
		}
		if state.submitted then
			table.insert(children, text("submitted", if state.cancelled then "Returning to Projects…" else "Working…", "overseer.message"))
		else
			table.insert(children, text("help", if state.mode == "project"
				then "Choose an existing Git checkout. Name and base branch are optional."
				elseif state.mode == "rename" then "Display name only. Branch: " .. state.project .. ". Leave blank to use the branch name; Git and the directory stay unchanged."
				else state.project .. " · New branch from " .. state.base .. ". Worktrunk hooks will run.", "overseer.hint"))
			local labels = { path = "Path", name = "Name (optional)", base = "Base (optional)", branch = "Branch name" }
			local placeholders = { path = "/path/to/repository", name = "Repository name", base = "master", branch = "feature/branch-name" }
			if state.mode == "rename" then
				labels.name, placeholders.name = "Display name (optional)", state.project
			elseif state.mode == "create" then
				labels.name, placeholders.name = "Display name (optional)", "e.g. Fix onboarding"
			end
			for _, name in ipairs(fieldOrder(state)) do
				table.insert(children, text(name .. "Label", labels[name], "overseer.fieldLabel"))
				local props = Input.props(state.fields[name])
				props.key, props.role, props.aria = name, "overseer.field", labels[name]
				props.placeholder = placeholders[name]
				table.insert(children, ui.node("input", props))
			end
			table.insert(children, ui.node("row", { key = "buttons", role = "overseer.formButtons" }, {
				ui.el("button", {
					key = "submit", role = "overseer.primaryButton",
					text = if state.mode == "project" then "Add project" elseif state.mode == "rename" then "Save name" else "Create worktree",
					actions = { click = "submit" },
				}),
			}))
			table.insert(children, text("keys", "Enter to submit · Esc to go back · Tab to change fields", "overseer.hint"))
			if not state.focusScheduled then
				state.focusScheduled = true
				-- Timer executes after this view mounts; a closed pane safely ignores focus.
				tern.timer(30, function()
					if not state.submitted then
						focus(state, cx)
					end
				end)
			end
		end
		if state.error then
			table.insert(children, text("error", state.error, "overseer.error"))
		end
		return { main = ui.node("col", { role = "overseer.form" }, children) }
	end,
	key = function(state, key, cx)
		if state.submitted then
			return false
		end
		if key.name == "escape" or key.name == "esc" then
			finish(state, true)
		elseif key.name == "enter" then
			finish(state, false)
			if not state.submitted then focus(state, cx) end
		elseif key.name == "tab" then
			local order = fieldOrder(state)
			local index = table.find(order, state.focus) or 1
			state.focus = order[((index - 1 + (if key.shift then -1 else 1)) % #order) + 1]
			focus(state, cx)
		elseif key.meta and string.lower(key.name) == "c" then
			local selection = Input.selection(state.fields[state.focus])
			if selection == "" then return false end
			cx:copy(selection)
		else
			local handled, err = Input.key(state.fields[state.focus], key)
			if not handled then return false end
			state.error = err
			focus(state, cx)
		end
		return true
	end,
	event = function(state, event, cx)
		if event.ev == "action" and event.act == "retry" then
			state.submitted, state.cancelled = false, false
			state.error = if type(event.value) == "string" then event.value else "Please correct the form and try again."
			state.focusScheduled = false
			return
		end
		if state.submitted then return end
		if event.ev == "focus" then
			for _, name in ipairs(fieldOrder(state)) do
				if event.id == "main." .. name then
					state.focus = name
					focus(state, cx)
					break
				end
			end
		elseif event.ev == "action" then
			if event.act == "submit" then
				finish(state, false)
			elseif event.act == "cancel" then
				finish(state, true)
			end
			if not state.submitted then focus(state, cx) end
		end
	end,
	save = function(state)
		local fields = {}
		for name, field in pairs(state.fields) do fields[name] = field.text end
		return {
			token = state.token, mode = state.mode, focus = state.focus, fields = fields,
			submitted = state.submitted, cancelled = state.cancelled,
		}
	end,
})
