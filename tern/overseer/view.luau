local ui = tern.ui
local View = {}

local function safeKey(value)
	return (string.gsub(value, ".", function(byte)
		return string.format("%02x", string.byte(byte))
	end))
end

local function unhex(hex)
	if not hex or #hex % 2 ~= 0 then return nil end
	return (string.gsub(hex, "..", function(byte)
		return string.char(tonumber(byte, 16))
	end))
end

-- Tern labels menu entries with the whole action string, including any =value.
-- Keep menu actions plain and recover their target from our keyed row node.
function View.worktreePath(node)
	return unhex(type(node) == "string" and node:match("%.w(%x+)%.row$") or nil)
end

function View.projectId(node)
	return unhex(type(node) == "string" and node:match("%.p(%x+)%.header$") or nil)
end

local function text(key, value, role, props)
	props = props or {}
	props.key, props.text, props.role = key, value, role or "overseer.label"
	return ui.node("text", props)
end

local function button(key, label, action, title, role)
	return ui.el("button", {
		key = key, text = label, role = role or "overseer.button",
		title = title, actions = { click = action },
	})
end

local PR_STATES = {
	draft = { role = "overseer.prDraft", label = "Draft" },
	open = { role = "overseer.prOpen", label = "Open" },
	merged = { role = "overseer.prMerged", label = "Merged" },
	closed = { role = "overseer.prClosed", label = "Closed" },
}

local function dot(key, role)
	return ui.el("div", { key = key, role = role })
end

local function basename(path)
	return path:match("([^/]+)/*$") or path
end

local function worktreeNode(worktree, activePath)
	local branch = worktree.branch or "Detached HEAD"
	local label = worktree.displayName or branch
	local active = activePath == worktree.path
	local menu = {}
	if not worktree.deleting then
		table.insert(menu, "rename")
		-- Plain-text actions appear verbatim in the menu.
		if not worktree.is_main then
			table.insert(menu, if worktree.iced then "Remove from Ice Box" else "Add to Ice Box")
		end
		if worktree.session then table.insert(menu, "close-session") end
		if not worktree.is_main then table.insert(menu, "delete-worktree") end
	end
	local status
	if worktree.iced then
		status = text("status", "🧊", "overseer.iceMark", { title = "In the Ice Box" })
	else
		local role, title = "overseer.dotIdle", "No session"
		if worktree.deleting then
			role, title = "overseer.dotBusy", "Deleting"
		elseif worktree.agent == "waiting" then
			role, title = "overseer.dotWaiting", "Agent waiting for you"
		elseif worktree.agent == "working" then
			role, title = "overseer.dotAgent", "Agent working"
		elseif worktree.session then
			role, title = "overseer.dotOpen", "Session open"
		end
		status = ui.el("div", { key = "status", role = role, title = title })
	end
	local head = {
		status,
		text("branch", label, "overseer.branch"),
	}
	if worktree.is_main then
		table.insert(head, text("primary", "Primary", "overseer.badge"))
	end
	-- Pushes the remaining badges to the row's right edge.
	table.insert(head, ui.el("div", { key = "spacer", grow = 1 }))
	if worktree.dirty then
		table.insert(head, text("dirty", "modified", "overseer.badgeWarn"))
	end
	if worktree.deleting then
		table.insert(head, text("deleting", "deleting", "overseer.badgeWarn"))
	elseif not worktree.session then
		table.insert(head, text("open", "Open", "overseer.openHint"))
	end
	local pr = worktree.pr and PR_STATES[worktree.pr.state]
	if pr then
		local summary = "#" .. tostring(worktree.pr.number) .. " · " .. pr.label
		table.insert(head, ui.el("button", {
			key = "pr", role = pr.role, title = summary .. " — open on GitHub", href = worktree.pr.url,
			aria = "Pull request " .. summary, actions = { click = "open" },
		}))
	end
	-- A renamed row keeps its branch visible; otherwise the directory helps
	-- tell apart worktrees whose branch names share a long ticket prefix.
	local subtitle = if worktree.displayName then branch
		elseif worktree.is_main then "primary checkout · " .. basename(worktree.path)
		else basename(worktree.path)
	local summary = ui.node("col", {
		key = "row", role = "overseer.worktreeRow", title = branch .. "\n" .. worktree.path,
		aria = label .. (if worktree.agent == "waiting" then ", agent waiting for you"
				elseif worktree.agent == "working" then ", agent working"
				elseif worktree.session then ", session open"
				else ", open session")
			.. (if worktree.iced then ", in the Ice Box" else ""),
		actions = { click = if worktree.deleting then nil else "open=" .. worktree.path, menu = menu },
	}, {
		ui.node("row", { key = "head", role = "overseer.worktreeHead" }, head),
		text("subtitle", subtitle, "overseer.worktreeSubtitle"),
	})
	local children = { summary }
	for _, tab in ipairs(worktree.tabs or {}) do
		local tabChildren = {
			dot("dot", if tab.agent == "waiting" then "overseer.dotTabWaiting"
				elseif tab.agent == "working" then "overseer.dotTabAgent"
				elseif tab.busy then "overseer.dotBusy"
				else "overseer.dotTab"),
			text("name", tab.name, "overseer.tabName", { grow = 1 }),
		}
		-- The pulsing dot already says an agent is working; waiting needs you, so it is spelled out.
		if tab.agent == "waiting" then
			table.insert(tabChildren, text("state", "waiting", "overseer.waiting"))
		elseif not tab.agent and tab.busy then
			table.insert(tabChildren, text("busy", "running", "overseer.busy"))
		end
		if not tab.pane then
			table.insert(tabChildren, text("unavailable", "no pane", "overseer.marker"))
		end
		table.insert(children, ui.node("row", {
			key = "tab" .. tostring(tab.id), role = "overseer.tabRow",
			title = if tab.pane then "Focus " .. tab.name else "This tab has no focusable pane",
			actions = if tab.pane then { click = "tab=" .. tostring(tab.pane) } else nil,
		}, tabChildren))
	end
	return ui.node("col", {
		key = "w" .. safeKey(worktree.path), role = "overseer.worktree",
		mark = if active then "pick" else nil,
	}, children)
end

function View.render(model)
	local children = {
		ui.node("row", { key = "header", role = "overseer.header" }, {
			ui.node("row", { key = "titleGroup", role = "overseer.titleGroup", grow = 1 }, {
				text("title", "Projects", "overseer.heading"),
				ui.el("button", {
					key = "help", role = "overseer.infoButton",
					title = "How Projects works", aria = "How Projects works",
					actions = { click = "help" },
				}),
			}),
			button("add", "+", "add", "Add an existing Git repository", "overseer.iconButton"),
			button("refresh", "↻", "refresh", "Refresh worktrees and sessions", "overseer.iconButton"),
			button("icebox", "🧊", "toggle-icebox",
				if model.showIcebox then "Hide Ice Box worktrees" else "Show Ice Box worktrees",
				if model.showIcebox then "overseer.iconButtonOn" else "overseer.iconButton"),
		}),
	}
	if model.confirmation then
		local request = model.confirmation
		local deleting = request.kind == "delete"
		local buttons = {
			button("cancel", "Cancel", "cancel=" .. request.id, "Keep this worktree and session"),
		}
		if not request.checking then
			table.insert(buttons, button("confirm", if deleting then "Delete worktree" else "Close session",
				"confirm=" .. request.id, "Confirm " .. request.label, "overseer.dangerButton"))
		end
		table.insert(children, ui.node("col", { key = "confirmation", role = "overseer.confirmation" }, {
			text("title", if deleting then "Delete worktree?" else "Close session?", "overseer.formHeading"),
			text("name", request.label, "overseer.branch"),
			text("path", request.path, "overseer.hint"),
			text("detail", if deleting
				then "Removes this directory, including ignored files. Keeps Git branches. Its session closes after successful removal. Stop file-writing tasks first."
				else "Stops all running programs and closes this session's tabs. Keeps the worktree files and Git branches.", "overseer.hint"),
			text("status", if request.checking then "Checking worktree..." else "", "overseer.hint"),
			ui.node("row", { key = "buttons", role = "overseer.formButtons" }, buttons),
		}))
	end
	if #model.projects == 0 then
		table.insert(children, ui.node("col", { key = "empty", role = "overseer.empty" }, {
			text("title", "Your repositories, in one place.", "overseer.emptyTitle"),
			text("help", "Add a project to see every worktree and its Tern tabs. Existing worktrees stay as they are.", "overseer.hint"),
			button("add", "Add your first project", "add", "Choose a Git repository"),
		}))
	end
	for _, project in ipairs(model.projects) do
		local collapsed = model.collapsed and model.collapsed[project.id]
		local projectChildren = {
			ui.node("row", {
				key = "header", role = "overseer.projectHeader",
				actions = { menu = { "Change base branch" } },
			}, {
				button("collapse", (if collapsed then "▸  " else "▾  ") .. project.name,
					"collapse=" .. project.id, (if collapsed then "Expand " else "Collapse ") .. project.name,
					"overseer.projectToggle"),
				text("count", tostring(project.total), "overseer.count"),
				ui.node("row", { key = "spacer", grow = 1 }, {}),
				button("create", "New Worktree", "create=" .. project.id, "Create a worktree from " .. project.base),
			}),
			text("path", project.path, "overseer.projectPath", { title = project.path }),
		}
		if project.error then
			table.insert(projectChildren, text("error", project.error, "overseer.error"))
		end
		if project.loading and #(project.worktrees or {}) == 0 then
			table.insert(projectChildren, text("loading", "Loading worktrees...", "overseer.hint"))
		end
		if not collapsed then
			for _, worktree in ipairs(project.worktrees or {}) do
				table.insert(projectChildren, worktreeNode(worktree, model.activePath))
			end
			if project.hiddenIced > 0 then
				-- In a row so the hint is only as wide as its text.
				table.insert(projectChildren, ui.node("row", { key = "icedRow" }, {
					button("iced", "🧊 " .. tostring(project.hiddenIced) .. " in the Ice Box",
						"toggle-icebox", "Show Ice Box worktrees", "overseer.icedHint"),
				}))
			end
			if not project.loading and not project.error and #(project.worktrees or {}) == 0 and project.hiddenIced == 0 then
				table.insert(projectChildren, text("empty", "No worktrees found. Refresh to check this repository.", "overseer.hint"))
			end
		end
		table.insert(children, ui.node("col", {
			key = "p" .. safeKey(project.id), role = "overseer.project",
		}, projectChildren))
	end
	return ui.node("col", { key = "overseer", role = "overseer.navigator" }, children)
end

return View
