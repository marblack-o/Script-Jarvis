--[[
  NativeBridge.lua
  Qué: motor nativo de análisis/comandos dentro de Roblox.
  Sirve como fallback si UAI no está disponible.
]]

local Players = game:GetService("Players")

local NativeBridge = {}

-- ============ UTILIDADES ============

local function trim(s)
	return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function splitByDot(path)
	local tokens = {}
	for token in tostring(path or ""):gmatch("[^%.]+") do
		table.insert(tokens, token)
	end
	return tokens
end

local function resolvePath(path)
	path = trim(path)
	if path == "" then
		path = "game"
	end

	local tokens = splitByDot(path)
	if #tokens == 0 then
		return game, nil
	end

	local first = tokens[1]
	local current = nil
	local startIndex = 1

	local lowerFirst = first:lower()

	if first == "game" then
		current = game
		startIndex = 2
	elseif lowerFirst == "workspace" then
		current = game:GetService("Workspace")
		startIndex = 2
	elseif lowerFirst == "players" then
		current = game:GetService("Players")
		startIndex = 2
	elseif lowerFirst == "lighting" then
		current = game:GetService("Lighting")
		startIndex = 2
	elseif lowerFirst == "replicatedstorage" then
		current = game:GetService("ReplicatedStorage")
		startIndex = 2
	elseif lowerFirst == "serverstorage" then
		current = game:GetService("ServerStorage")
		startIndex = 2
	elseif lowerFirst == "serverscriptservice" then
		current = game:GetService("ServerScriptService")
		startIndex = 2
	elseif lowerFirst == "startergui" then
		current = game:GetService("StarterGui")
		startIndex = 2
	elseif lowerFirst == "starterplayer" then
		current = game:GetService("StarterPlayer")
		startIndex = 2
	else
		current = game
		startIndex = 1
	end

	for i = startIndex, #tokens do
		local token = tokens[i]
		local nextObject = nil

		pcall(function()
			nextObject = current[token]
		end)

		if nextObject == nil then
			pcall(function()
				nextObject = current:FindFirstChild(token)
			end)
		end

		if nextObject == nil then
			return nil, token
		end

		current = nextObject
	end

	return current, nil
end

local function scanGame(cap)
	local stats = {
		total = 0,
		scripts = 0,
		localScripts = 0,
		moduleScripts = 0,
		parts = 0,
		models = 0,
		capped = false,
	}

	pcall(function()
		for _, inst in ipairs(game:GetDescendants()) do
			stats.total = stats.total + 1

			if inst:IsA("Script") then
				stats.scripts = stats.scripts + 1
			elseif inst:IsA("LocalScript") then
				stats.localScripts = stats.localScripts + 1
			elseif inst:IsA("ModuleScript") then
				stats.moduleScripts = stats.moduleScripts + 1
			elseif inst:IsA("BasePart") then
				stats.parts = stats.parts + 1
			elseif inst:IsA("Model") then
				stats.models = stats.models + 1
			end

			if stats.total >= cap then
				stats.capped = true
				break
			end
		end
	end)

	return stats
end

-- ============ COMANDOS NATIVOS ============

local Commands = {}

function Commands.analyze()
	local lines = {
		"=== J.A.R.V.I.S. SYSTEM ANALYSIS ===",
	}

	pcall(function()
		local MarketplaceService = game:GetService("MarketplaceService")
		local info = MarketplaceService:GetProductInfo(game.PlaceId)

		table.insert(lines, "Place: " .. tostring(info.Name))
		table.insert(lines, "PlaceId: " .. tostring(game.PlaceId))

		if info.Creator then
			table.insert(lines, "Creator: " .. tostring(info.Creator.Name or "Unknown"))
		end
	end)

	table.insert(lines, "Players online: " .. tostring(#Players:GetPlayers()))

	local services = game:GetChildren()
	table.insert(lines, "Root services: " .. tostring(#services))

	for i = 1, math.min(20, #services) do
		table.insert(lines, "  " .. services[i].ClassName .. " | " .. services[i].Name)
	end

	if #services > 20 then
		table.insert(lines, "  ... (" .. (#services - 20) .. " more)")
	end

	local stats = scanGame(20000)

	table.insert(lines, "Instances scanned: " .. stats.total .. (stats.capped and "+" or ""))
	table.insert(lines, "Scripts: " .. stats.scripts .. " | LocalScripts: " .. stats.localScripts .. " | Modules: " .. stats.moduleScripts)
	table.insert(lines, "Parts: " .. stats.parts .. " | Models: " .. stats.models)

	return table.concat(lines, "\n")
end

function Commands.list(path)
	path = trim(path)
	if path == "" then
		path = "game"
	end

	local target, failedToken = resolvePath(path)
	if not target then
		return "No pude resolver la ruta: " .. path .. (failedToken and (" (token fallido: " .. failedToken .. ")") or "")
	end

	local children = target:GetChildren()

	table.sort(children, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)

	local lines = {
		"=== CHILDREN OF " .. path .. " ===",
		"Total: " .. tostring(#children),
	}

	for i = 1, math.min(80, #children) do
		local child = children[i]
		table.insert(lines, string.format("  [%s] %s", child.ClassName, child.Name))
	end

	if #children > 80 then
		table.insert(lines, "  ... (" .. (#children - 80) .. " more)")
	end

	return table.concat(lines, "\n")
end

function Commands.search(query)
	query = trim(query)

	if query == "" then
		return "Indica qué instancia quieres buscar."
	end

	local results = {}
	local queryLower = query:lower()

	pcall(function()
		for _, inst in ipairs(game:GetDescendants()) do
			if inst.Name:lower():find(queryLower, 1, true) then
				table.insert(results, inst)
				if #results >= 100 then
					break
				end
			end
		end
	end)

	local lines = {
		"=== SEARCH: " .. query .. " ===",
		"Results: " .. tostring(#results),
	}

	for i, inst in ipairs(results) do
		table.insert(lines, string.format("  [%d] %s (%s) - %s", i, inst.Name, inst.ClassName, inst:GetFullName()))
	end

	if #results == 0 then
		table.insert(lines, "  Sin resultados.")
	end

	return table.concat(lines, "\n")
end

function Commands.properties(path)
	path = trim(path)
	if path == "" then
		path = "game.Workspace"
	end

	local target, failedToken = resolvePath(path)
	if not target then
		return "No pude resolver la ruta: " .. path .. (failedToken and (" (token fallido: " .. failedToken .. ")") or "")
	end

	local lines = {
		"=== PROPERTIES OF " .. path .. " ===",
		"Name: " .. tostring(target.Name),
		"ClassName: " .. tostring(target.ClassName),
		"FullName: " .. tostring(target:GetFullName()),
		"Parent: " .. tostring(target.Parent and target.Parent.Name or "None"),
		"Children: " .. tostring(#target:GetChildren()),
	}

	pcall(function()
		local attrs = target:GetAttributes()
		if next(attrs) then
			table.insert(lines, "--- Attributes ---")
			for k, v in pairs(attrs) do
				table.insert(lines, "  " .. k .. " = " .. tostring(v))
			end
		end
	end)

	pcall(function()
		if target:IsA("BasePart") then
			table.insert(lines, "--- BasePart ---")
			table.insert(lines, "  Position: " .. tostring(target.Position))
			table.insert(lines, "  Size: " .. tostring(target.Size))
			table.insert(lines, "  Material: " .. tostring(target.Material))
			table.insert(lines, "  Color: " .. tostring(target.Color))
			table.insert(lines, "  Anchored: " .. tostring(target.Anchored))
			table.insert(lines, "  Transparency: " .. tostring(target.Transparency))
		elseif target:IsA("Player") then
			table.insert(lines, "--- Player ---")
			table.insert(lines, "  UserId: " .. tostring(target.UserId))
			table.insert(lines, "  DisplayName: " .. tostring(target.DisplayName))
			table.insert(lines, "  Team: " .. tostring(target.Team and target.Team.Name or "N/A"))
		elseif target:IsA("GuiObject") then
			table.insert(lines, "--- GuiObject ---")
			table.insert(lines, "  Position: " .. tostring(target.Position))
			table.insert(lines, "  Size: " .. tostring(target.Size))
			table.insert(lines, "  Visible: " .. tostring(target.Visible))
			table.insert(lines, "  ZIndex: " .. tostring(target.ZIndex))
		elseif target:IsA("Script") or target:IsA("LocalScript") or target:IsA("ModuleScript") then
			table.insert(lines, "--- Script ---")
			table.insert(lines, "  Disabled: " .. tostring(target.Disabled))

			local source = ""
			pcall(function()
				source = target.Source
			end)

			table.insert(lines, "  Source length: " .. tostring(#source))

			local lineCount = 0
			for line in source:gmatch("[^\n]+") do
				lineCount = lineCount + 1
				table.insert(lines, "    " .. line:sub(1, 100))
				if lineCount >= 12 then
					table.insert(lines, "    ...")
					break
				end
			end
		end
	end)

	return table.concat(lines, "\n")
end

function Commands.scripts()
	local found = {}

	pcall(function()
		for _, inst in ipairs(game:GetDescendants()) do
			if inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
				table.insert(found, inst)
				if #found >= 150 then
					break
				end
			end
		end
	end)

	local lines = {
		"=== SCRIPTS FOUND ===",
		"Total: " .. tostring(#found),
	}

	for i = 1, math.min(100, #found) do
		local script = found[i]
		local sourceLength = 0

		pcall(function()
			sourceLength = #script.Source
		end)

		table.insert(lines, string.format(
			"  [%s] %s | %d chars | %s",
			script.ClassName,
			script.Name,
			sourceLength,
			script:GetFullName()
		))
	end

	if #found > 100 then
		table.insert(lines, "  ... (" .. (#found - 100) .. " more)")
	end

	return table.concat(lines, "\n")
end

function Commands.players()
	local players = Players:GetPlayers()

	local lines = {
		"=== PLAYERS ===",
		"Total: " .. tostring(#players),
	}

	for _, player in ipairs(players) do
		table.insert(lines, string.format(
			"  %s | UserId: %d | Character: %s",
			player.Name,
			player.UserId,
			tostring(player.Character and player.Character.Name or "N/A")
		))
	end

	if #players == 0 then
		table.insert(lines, "  No players found.")
	end

	return table.concat(lines, "\n")
end

function Commands.workspace()
	local workspace = game:GetService("Workspace")
	local children = workspace:GetChildren()

	local lines = {
		"=== WORKSPACE OVERVIEW ===",
		"Root objects: " .. tostring(#children),
		"Gravity: " .. tostring(workspace.Gravity),
		"CurrentCamera: " .. tostring(workspace.CurrentCamera and "Active" or "N/A"),
	}

	local partCount = 0
	local modelCount = 0
	local capped = false

	pcall(function()
		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst:IsA("BasePart") then
				partCount = partCount + 1
			elseif inst:IsA("Model") then
				modelCount = modelCount + 1
			end

			if partCount + modelCount >= 20000 then
				capped = true
				break
			end
		end
	end)

	table.insert(lines, "Parts: " .. tostring(partCount) .. (capped and "+" or ""))
	table.insert(lines, "Models: " .. tostring(modelCount) .. (capped and "+" or ""))

	table.sort(children, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)

	for i = 1, math.min(40, #children) do
		table.insert(lines, "  [" .. children[i].ClassName .. "] " .. children[i].Name)
	end

	if #children > 40 then
		table.insert(lines, "  ... (" .. (#children - 40) .. " more)")
	end

	return table.concat(lines, "\n")
end

-- ============ INTERPRETADOR ============

local function extractRequest(prompt)
	local request = tostring(prompt or ""):match("User request: ([^\n]*)")
	if request and trim(request) ~= "" then
		return trim(request)
	end
	return trim(prompt)
end

local function extractPath(text)
	local candidate = tostring(text or ""):match("([%w_%.]+)%s*$")
	if not candidate then
		return nil
	end

	local lower = candidate:lower()

	if lower:find("game") == 1
		or candidate:find("%.")
		or lower:find("workspace")
		or lower:find("players")
		or lower:find("lighting")
		or lower:find("replicatedstorage")
		or lower:find("serverstorage")
		or lower:find("serverscriptservice")
		or lower:find("startergui")
		or lower:find("starterplayer")
	then
		return candidate
	end

	return nil
end

local function extractSearchQuery(text)
	text = tostring(text or "")

	local q = text:match("busca%s+(.+)")
		or text:match("buscar%s+(.+)")
		or text:match("search%s+(.+)")
		or text:match("find%s+(.+)")

	if q then
		return trim(q)
	end

	return trim(text)
end

function NativeBridge.runMission(prompt, callback, _cfg)
	task.spawn(function()
		local ok, result = pcall(function()
			local request = extractRequest(prompt)
			local lower = request:lower()

			if lower:find("analiza") or lower:find("analizar") or lower:find("analysis") or lower:find("analyze") or lower:find("resumen") or lower:find("overview") then
				return Commands.analyze()
			end

			if lower:find("lista") or lower:find("list") or lower:find("hijos") or lower:find("children") then
				local path = extractPath(request) or "game"
				return Commands.list(path)
			end

			if lower:find("busca") or lower:find("buscar") or lower:find("search") or lower:find("find") or lower:find("encuentra") then
				local query = extractSearchQuery(request)
				return Commands.search(query)
			end

			if lower:find("propiedades") or lower:find("properties") or lower:find("props") then
				local path = extractPath(request) or "game.Workspace"
				return Commands.properties(path)
			end

			if lower:find("scripts") or lower:find("código") or lower:find("codigo") then
				return Commands.scripts()
			end

			if lower:find("jugadores") or lower:find("players") then
				return Commands.players()
			end

			if lower:find("workspace") or lower:find("mundo") or lower:find("world") then
				return Commands.workspace()
			end

			return Commands.analyze() .. "\n\n[NativeBridge] Comando no reconocido. Ejecutando análisis general."
		end)

		task.wait(0.05)

		if type(callback) == "function" then
			callback(ok, ok and result or tostring(result))
		end
	end)
end

function NativeBridge.ensure(_force)
	return true
end

function NativeBridge.show(_section)
	return false, "UAI no conectado. Modo nativo activo."
end

function NativeBridge.injectProvider(_provider, _key)
	return true, "Guardado localmente. UAI no conectado."
end

function NativeBridge.getStatus()
	return "NATIVO"
end

NativeBridge.sessions = {
	open = function()
		return true
	end,
	request = function()
		return true
	end,
}

return NativeBridge
