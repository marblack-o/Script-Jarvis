--[[
  Explorer.lua
  Qué: explorador tipo Dex.
  - Árbol expandible con colores por clase.
  - Búsqueda incremental segura (sin congelar frames).
  - Panel de propiedades con acciones (copiar path, enfocar cámara).
  - Botón de refresco manual y contador de nodos.
  - Estilo J.A.R.V.I.S.
  v9.1.0
]]

local Explorer = {}

local RunService = game:GetService("RunService")

local MAX_DEPTH = 12
local MAX_SEARCH_RESULTS = 200
local SEARCH_YIELD_EVERY = 150

local ICONS = {
	Folder = "[D]",
	Script = "[S]",
	LocalScript = "[L]",
	ModuleScript = "[M]",
	Model = "[MOD]",
	Workspace = "[W]",
	Player = "[P]",
	Part = "[B]",
	MeshPart = "[B]",
	UnionOperation = "[U]",
	Seat = "[SEAT]",
	VehicleSeat = "[SEAT]",
	ScreenGui = "[GUI]",
	SurfaceGui = "[GUI]",
	BillboardGui = "[GUI]",
	Frame = "[F]",
	ScrollingFrame = "[F]",
	TextLabel = "[T]",
	TextButton = "[BTN]",
	TextBox = "[IN]",
	ImageLabel = "[IMG]",
	ImageButton = "[IMG]",
	Camera = "[CAM]",
	Sound = "[AUD]",
	ParticleEmitter = "[FX]",
	Beam = "[FX]",
	Tool = "[TOOL]",
	Accessory = "[ACC]",
	Humanoid = "[H]",
	Animation = "[ANIM]",
	RemoteEvent = "[REM]",
	RemoteFunction = "[REM]",
	BindableEvent = "[BIND]",
	default = " - ",
}

-- Colores por categoría de clase (se resuelven con Theme al renderizar)
local CLASS_COLOR_KEYS = {
	Script = "uaiYellow",
	LocalScript = "green",
	ModuleScript = "accent",
	Model = "text",
	Workspace = "border",
	Player = "green",
	ScreenGui = "c2",
	SurfaceGui = "c2",
	BillboardGui = "c2",
	Camera = "textDim",
	Sound = "textDim",
	Humanoid = "danger",
	RemoteEvent = "uaiYellow",
	RemoteFunction = "uaiYellow",
	BindableEvent = "uaiYellow",
}

local function clearContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		child:Destroy()
	end
end

local function getIcon(className)
	return ICONS[className] or ICONS.default
end

local function classColorKey(className)
	return CLASS_COLOR_KEYS[className]
end

function Explorer.render(parent, Theme, _Bridge)
	clearContainer(parent)

	local expanded = {}
	local selectedHighlight = nil
	local selectedInstance = nil
	local searchQuery = ""
	local layoutOrder = 0
	local searchDebounce = false
	local searchToken = 0
	local focusedCamera = false

	pcall(function()
		expanded[game] = true
	end)

	pcall(function()
		expanded[game:GetService("Workspace")] = true
	end)

	-- ============================================================
	-- RAÍZ
	-- ============================================================

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.ZIndex = 24
	root.Parent = parent

	-- ============================================================
	-- BARRA SUPERIOR: búsqueda + refresco + contador
	-- ============================================================

	local searchBar = Instance.new("Frame")
	searchBar.Size = UDim2.new(1, 0, 0, 30)
	searchBar.BackgroundColor3 = Theme.inputBg
	searchBar.BackgroundTransparency = 0.08
	searchBar.BorderSizePixel = 0
	searchBar.ZIndex = 25
	searchBar.Parent = root

	Theme.mkCorner(searchBar, 4)
	Theme.mkStroke(searchBar, Theme.border, 1, 0.55)

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -66, 1, 0)
	searchBox.Position = UDim2.fromOffset(8, 0)
	searchBox.BackgroundTransparency = 1
	searchBox.PlaceholderText = "Buscar instancia..."
	searchBox.PlaceholderColor3 = Theme.textDim
	searchBox.Text = ""
	searchBox.TextColor3 = Theme.text
	searchBox.Font = Enum.Font.Code
	searchBox.TextSize = 12
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.ClearTextOnFocus = false
	searchBox.ZIndex = 26
	searchBox.Parent = searchBar

	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Size = UDim2.fromOffset(22, 22)
	refreshBtn.Position = UDim2.new(1, -56, 0.5, -11)
	refreshBtn.BackgroundColor3 = Theme.row
	refreshBtn.BackgroundTransparency = 0.15
	refreshBtn.Text = "R"
	refreshBtn.TextColor3 = Theme.accent
	refreshBtn.Font = Enum.Font.Code
	refreshBtn.TextSize = 12
	refreshBtn.AutoButtonColor = false
	refreshBtn.ZIndex = 26
	refreshBtn.Parent = searchBar

	Theme.mkCorner(refreshBtn, 3)

	local clearBtn = Instance.new("TextButton")
	clearBtn.Size = UDim2.fromOffset(22, 22)
	clearBtn.Position = UDim2.new(1, -28, 0.5, -11)
	clearBtn.BackgroundTransparency = 1
	clearBtn.Text = "X"
	clearBtn.TextColor3 = Theme.textDim
	clearBtn.Font = Enum.Font.Code
	clearBtn.TextSize = 12
	clearBtn.ZIndex = 26
	clearBtn.Parent = searchBar

	local countLbl = Instance.new("TextLabel")
	countLbl.Size = UDim2.new(1, 0, 0, 14)
	countLbl.Position = UDim2.fromOffset(2, 32)
	countLbl.BackgroundTransparency = 1
	countLbl.Text = ""
	countLbl.TextColor3 = Theme.textDim
	countLbl.Font = Enum.Font.Code
	countLbl.TextSize = 10
	countLbl.TextXAlignment = Enum.TextXAlignment.Left
	countLbl.ZIndex = 25
	countLbl.Parent = root

	-- ============================================================
	-- PANELES
	-- ============================================================

	local splitFrame = Instance.new("Frame")
	splitFrame.Size = UDim2.new(1, 0, 1, -52)
	splitFrame.Position = UDim2.fromOffset(0, 50)
	splitFrame.BackgroundTransparency = 1
	splitFrame.ZIndex = 25
	splitFrame.Parent = root

	local treePanel = Instance.new("ScrollingFrame")
	treePanel.Size = UDim2.new(0.55, -4, 1, 0)
	treePanel.Position = UDim2.fromOffset(0, 0)
	treePanel.BackgroundTransparency = 1
	treePanel.BorderSizePixel = 0
	treePanel.ScrollBarThickness = 3
	treePanel.ScrollBarImageColor3 = Theme.border
	treePanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	treePanel.CanvasSize = UDim2.new(0, 0, 0, 0)
	treePanel.ZIndex = 26
	treePanel.Parent = splitFrame

	local treeLayout = Instance.new("UIListLayout", treePanel)
	treeLayout.Padding = UDim.new(0, 1)
	treeLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local propsPanel = Instance.new("ScrollingFrame")
	propsPanel.Size = UDim2.new(0.45, -4, 1, 0)
	propsPanel.Position = UDim2.new(0.55, 4, 0, 0)
	propsPanel.BackgroundColor3 = Theme.plate
	propsPanel.BackgroundTransparency = 0.2
	propsPanel.BorderSizePixel = 0
	propsPanel.ScrollBarThickness = 3
	propsPanel.ScrollBarImageColor3 = Theme.border
	propsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	propsPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
	propsPanel.ZIndex = 26
	propsPanel.Parent = splitFrame

	Theme.mkCorner(propsPanel, 4)
	Theme.mkStroke(propsPanel, Theme.border, 1, 0.6)

	local propsLayout = Instance.new("UIListLayout", propsPanel)
	propsLayout.Padding = UDim.new(0, 4)
	propsLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local propsPadding = Instance.new("UIPadding", propsPanel)
	propsPadding.PaddingTop = UDim.new(0, 8)
	propsPadding.PaddingLeft = UDim.new(0, 8)
	propsPadding.PaddingRight = UDim.new(0, 8)
	propsPadding.PaddingBottom = UDim.new(0, 8)

	-- ============================================================
	-- PANEL DE PROPIEDADES
	-- ============================================================

	local function addPropRow(text, color, size)
		layoutOrder = layoutOrder + 1

		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -8, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundTransparency = 1
		row.Text = text
		row.TextColor3 = color or Theme.text
		row.Font = Enum.Font.Code
		row.TextSize = size or 11
		row.TextWrapped = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextYAlignment = Enum.TextYAlignment.Top
		row.LayoutOrder = layoutOrder
		row.ZIndex = 27
		row.Parent = propsPanel
		return row
	end

	local function addActionButton(text, callback)
		layoutOrder = layoutOrder + 1

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -8, 0, 24)
		btn.BackgroundColor3 = Theme.row
		btn.BackgroundTransparency = 0.08
		btn.Text = text
		btn.TextColor3 = Theme.accent
		btn.Font = Enum.Font.Code
		btn.TextSize = 11
		btn.AutoButtonColor = false
		btn.LayoutOrder = layoutOrder
		btn.ZIndex = 27
		btn.Parent = propsPanel

		Theme.mkCorner(btn, 3)
		Theme.mkStroke(btn, Theme.border, 1, 0.7)

		btn.MouseEnter:Connect(function()
			Theme.tween(btn, { BackgroundTransparency = 0 }, 0.12)
		end)

		btn.MouseLeave:Connect(function()
			Theme.tween(btn, { BackgroundTransparency = 0.08 }, 0.12)
		end)

		btn.MouseButton1Click:Connect(function()
			local ok, err = pcall(callback)
			if not ok then
				addPropRow("Error: " .. tostring(err), Theme.danger, 10)
			end
		end)

		return btn
	end

	local function restoreCamera()
		if not focusedCamera then
			return
		end

		pcall(function()
			local cam = game:GetService("Workspace").CurrentCamera
			if cam then
				cam.CameraType = Enum.CameraType.Custom
			end
		end)

		focusedCamera = false
	end

	local function focusCamera(inst)
		local cam = game:GetService("Workspace").CurrentCamera
		if not cam then
			return false, "Sin cámara disponible."
		end

		local targetCFrame = nil

		pcall(function()
			if inst:IsA("BasePart") then
				targetCFrame = inst.CFrame
			elseif inst:IsA("Model") then
				local part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
				if part then
					targetCFrame = part.CFrame
				end
			elseif inst:IsA("Attachment") then
				targetCFrame = inst.WorldCFrame
			end
		end)

		if not targetCFrame then
			return false, "La instancia no tiene posición (usa un Part/Model/Attachment)."
		end

		pcall(function()
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = targetCFrame * CFrame.new(0, 6, 14) * CFrame.Angles(math.rad(-20), 0, 0)
		end)

		focusedCamera = true
		return true, "Cámara enfocada. Pulsa RESTAURAR CAM para volver."
	end

	local showProperties

	local function rebuildPropsLayout()
		local newLayout = Instance.new("UIListLayout", propsPanel)
		newLayout.Padding = UDim.new(0, 4)
		newLayout.SortOrder = Enum.SortOrder.LayoutOrder

		local newPadding = Instance.new("UIPadding", propsPanel)
		newPadding.PaddingTop = UDim.new(0, 8)
		newPadding.PaddingLeft = UDim.new(0, 8)
		newPadding.PaddingRight = UDim.new(0, 8)
		newPadding.PaddingBottom = UDim.new(0, 8)
	end

	showProperties = function(inst)
		clearContainer(propsPanel)
		rebuildPropsLayout()

		layoutOrder = 0

		addPropRow("=== " .. inst.Name .. " ===", Theme.border, 13)
		addPropRow("Class: " .. inst.ClassName, Theme.accent)
		addPropRow("Path: " .. inst:GetFullName())
		addPropRow("Parent: " .. tostring(inst.Parent and inst.Parent.Name or "None"))
		addPropRow("Children: " .. tostring(#inst:GetChildren()))

		addActionButton("[ COPIAR PATH ]", function()
			local path = inst:GetFullName()
			if type(setclipboard) == "function" then
				setclipboard(path)
			end
		end)

		if focusedCamera then
			addActionButton("[ RESTAURAR CAM ]", function()
				restoreCamera()
				showProperties(inst)
			end)
		else
			addActionButton("[ ENFOCAR EN CÁMARA ]", function()
				local ok, msg = focusCamera(inst)
				addPropRow(tostring(msg), ok and Theme.green or Theme.danger, 10)
				if ok then
					showProperties(inst)
				end
			end)
		end

		pcall(function()
			if inst:IsA("BasePart") then
				addPropRow("--- BasePart ---", Theme.accent)
				addPropRow("Position: " .. tostring(inst.Position))
				addPropRow("Size: " .. tostring(inst.Size))
				addPropRow("Material: " .. tostring(inst.Material))
				addPropRow("Anchored: " .. tostring(inst.Anchored))
				addPropRow("Transparency: " .. tostring(inst.Transparency))
			elseif inst:IsA("Player") then
				addPropRow("--- Player ---", Theme.accent)
				addPropRow("UserId: " .. tostring(inst.UserId))
				addPropRow("DisplayName: " .. tostring(inst.DisplayName))
			elseif inst:IsA("GuiObject") then
				addPropRow("--- GuiObject ---", Theme.accent)
				addPropRow("Position: " .. tostring(inst.Position))
				addPropRow("Size: " .. tostring(inst.Size))
				addPropRow("Visible: " .. tostring(inst.Visible))
				addPropRow("ZIndex: " .. tostring(inst.ZIndex))
			elseif inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
				addPropRow("--- Script ---", Theme.accent)
				addPropRow("Disabled: " .. tostring(inst.Disabled))

				local source = ""
				pcall(function()
					source = inst.Source
				end)

				addPropRow("Source length: " .. tostring(#source))
			end
		end)

		pcall(function()
			local attributes = inst:GetAttributes()
			if next(attributes) then
				addPropRow("--- Attributes ---", Theme.accent)
				for key, value in pairs(attributes) do
					addPropRow(tostring(key) .. ": " .. tostring(value))
				end
			end
		end)
	end

	-- ============================================================
	-- ÁRBOL
	-- ============================================================

	local refreshTree

	local function createNode(inst, depth, labelOverride)
		layoutOrder = layoutOrder + 1

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 20)
		row.BackgroundTransparency = 1
		row.LayoutOrder = layoutOrder
		row.ZIndex = 26
		row.Parent = treePanel

		local indent = depth * 14

		local highlight = Instance.new("Frame")
		highlight.Name = "Highlight"
		highlight.Size = UDim2.fromScale(1, 1)
		highlight.BackgroundColor3 = Theme.border
		highlight.BackgroundTransparency = 1
		highlight.BorderSizePixel = 0
		highlight.ZIndex = 26
		highlight.Parent = row

		Theme.mkCorner(highlight, 3)

		local expandBtn = Instance.new("TextButton")
		expandBtn.Size = UDim2.fromOffset(16, 16)
		expandBtn.Position = UDim2.fromOffset(indent, 2)
		expandBtn.BackgroundTransparency = 1
		expandBtn.Text = " "
		expandBtn.TextColor3 = Theme.textDim
		expandBtn.Font = Enum.Font.Code
		expandBtn.TextSize = 10
		expandBtn.ZIndex = 28
		expandBtn.Parent = row

		local hasChildren = false
		pcall(function()
			hasChildren = #inst:GetChildren() > 0
		end)

		if hasChildren then
			expandBtn.Text = expanded[inst] and "v" or ">"
		end

		local label = Instance.new("TextButton")
		label.Size = UDim2.new(1, -indent - 20, 1, 0)
		label.Position = UDim2.fromOffset(indent + 18, 0)
		label.BackgroundTransparency = 1
		label.Text = labelOverride or (getIcon(inst.ClassName) .. " " .. inst.Name)
		label.Font = Enum.Font.Code
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.ZIndex = 28
		label.Parent = row

		-- Color del nombre según categoría de clase
		local colorKey = classColorKey(inst.ClassName)
		if colorKey and Theme[colorKey] then
			label.TextColor3 = Theme[colorKey]
		else
			label.TextColor3 = Theme.text
		end

		local function select()
			if selectedHighlight then
				selectedHighlight.BackgroundTransparency = 1
			end

			selectedHighlight = highlight
			selectedInstance = inst
			highlight.BackgroundTransparency = 0.78

			showProperties(inst)
		end

		expandBtn.MouseButton1Click:Connect(function()
			expanded[inst] = not expanded[inst]
			refreshTree()
		end)

		label.MouseButton1Click:Connect(select)

		label.MouseEnter:Connect(function()
			if selectedInstance ~= inst then
				highlight.BackgroundTransparency = 0.9
			end
		end)

		label.MouseLeave:Connect(function()
			if selectedInstance ~= inst then
				highlight.BackgroundTransparency = 1
			end
		end)
	end

	local function updateCount(text)
		countLbl.Text = text
	end

	local function runSearch(query)
		local token = searchToken

		local queryLower = query:lower()
		local matches = 0

		local descendants = nil
		local okDesc = pcall(function()
			descendants = game:GetDescendants()
		end)

		if not okDesc or not descendants then
			updateCount("ERROR DE BÚSQUEDA")
			return
		end

		for i = 1, #descendants do
			-- Invalidar resultados si el usuario siguió escribiendo
			if token ~= searchToken then
				return
			end

			local inst = descendants[i]

			local okName, name = pcall(function()
				return inst.Name
			end)

			if okName and type(name) == "string" and name:lower():find(queryLower, 1, true) then
				local okFull, fullName = pcall(function()
					return inst:GetFullName()
				end)

				matches = matches + 1
				createNode(inst, 0, okFull and fullName or name)

				if matches >= MAX_SEARCH_RESULTS then
					break
				end
			end

			-- Ceder tiempo de frame para no congelar el juego en juegos grandes
			if i % SEARCH_YIELD_EVERY == 0 then
				updateCount("BUSCANDO... (" .. tostring(i) .. ")")
				RunService.Heartbeat:Wait()
			end
		end

		if token ~= searchToken then
			return
		end

		if matches == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 30)
			empty.BackgroundTransparency = 1
			empty.Text = "Sin resultados."
			empty.TextColor3 = Theme.textDim
			empty.Font = Enum.Font.Code
			empty.TextSize = 12
			empty.LayoutOrder = 1
			empty.ZIndex = 26
			empty.Parent = treePanel
		end

		updateCount("RESULTADOS: " .. tostring(matches))
	end

	refreshTree = function()
		searchToken = searchToken + 1
		local token = searchToken

		for _, child in ipairs(treePanel:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		layoutOrder = 0

		if searchQuery ~= "" then
			runSearch(searchQuery)
			return
		end

		local nodeCount = 0

		local function build(inst, depth)
			if token ~= searchToken then
				return
			end

			if depth > MAX_DEPTH then
				return
			end

			nodeCount = nodeCount + 1
			createNode(inst, depth)

			if expanded[inst] then
				local children = {}

				pcall(function()
					children = inst:GetChildren()
				end)

				table.sort(children, function(a, b)
					local okA, nameA = pcall(function() return a.Name:lower() end)
					local okB, nameB = pcall(function() return b.Name:lower() end)
					if not okA then nameA = "" end
					if not okB then nameB = "" end
					return nameA < nameB
				end)

				for _, child in ipairs(children) do
					build(child, depth + 1)
				end
			end
		end

		build(game, 0)
		updateCount("NODOS: " .. tostring(nodeCount))
	end

	-- ============================================================
	-- EVENTOS
	-- ============================================================

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchQuery = searchBox.Text

		if not searchDebounce then
			searchDebounce = true

			task.delay(0.25, function()
				searchDebounce = false
				refreshTree()
			end)
		end
	end)

	clearBtn.MouseButton1Click:Connect(function()
		searchBox.Text = ""
		searchQuery = ""
		refreshTree()
	end)

	refreshBtn.MouseButton1Click:Connect(function()
		refreshTree()
	end)

	-- Limpiar foco de cámara si se cierra el panel raíz
	root.AncestorRemoved:Connect(function(ancestor)
		if ancestor == nil or ancestor == parent then
			restoreCamera()
		end
	end)

	refreshTree()
end

return Explorer