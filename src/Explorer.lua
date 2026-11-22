--[[
  Explorer.lua
  Qué: explorador tipo Dex.
  - Árbol expandible.
  - Búsqueda.
  - Panel de propiedades.
  - Estilo J.A.R.V.I.S.
]]

local Explorer = {}

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
	ScreenGui = "[GUI]",
	Frame = "[F]",
	TextLabel = "[T]",
	TextButton = "[BTN]",
	ImageLabel = "[IMG]",
	Camera = "[CAM]",
	Sound = "[AUD]",
	default = " - ",
}

local function getIcon(className)
	return ICONS[className] or ICONS.default
end

local function clearContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		child:Destroy()
	end
end

function Explorer.render(parent, Theme, _Bridge)
	clearContainer(parent)

	local expanded = {}
	local selectedHighlight = nil
	local selectedInstance = nil
	local searchQuery = ""
	local layoutOrder = 0
	local searchDebounce = false

	pcall(function()
		expanded[game] = true
	end)

	pcall(function()
		expanded[game:GetService("Workspace")] = true
	end)

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.ZIndex = 24
	root.Parent = parent

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
	searchBox.Size = UDim2.new(1, -34, 1, 0)
	searchBox.Position = UDim2.fromOffset(8, 0)
	searchBox.BackgroundTransparency = 1
	searchBox.PlaceholderText = "Buscar instancia..."
	searchBox.PlaceholderColor3 = Theme.textDim
	searchBox.Text = ""
	searchBox.TextColor3 = Theme.text
	searchBox.Font = Enum.Font.Code
	searchBox.TextSize = 12
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.ZIndex = 26
	searchBox.Parent = searchBar

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

	local splitFrame = Instance.new("Frame")
	splitFrame.Size = UDim2.new(1, 0, 1, -36)
	splitFrame.Position = UDim2.fromOffset(0, 34)
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

	local function addPropRow(text, color, size)
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
		row.ZIndex = 27
		row.Parent = propsPanel
	end

	local function showProperties(inst)
		clearContainer(propsPanel)

		-- Recrear layout/padding porque clearContainer los borra
		local newLayout = Instance.new("UIListLayout", propsPanel)
		newLayout.Padding = UDim.new(0, 4)
		newLayout.SortOrder = Enum.SortOrder.LayoutOrder

		local newPadding = Instance.new("UIPadding", propsPanel)
		newPadding.PaddingTop = UDim.new(0, 8)
		newPadding.PaddingLeft = UDim.new(0, 8)
		newPadding.PaddingRight = UDim.new(0, 8)
		newPadding.PaddingBottom = UDim.new(0, 8)

		addPropRow("=== " .. inst.Name .. " ===", Theme.border, 13)
		addPropRow("Class: " .. inst.ClassName)
		addPropRow("Path: " .. inst:GetFullName())
		addPropRow("Parent: " .. tostring(inst.Parent and inst.Parent.Name or "None"))
		addPropRow("Children: " .. tostring(#inst:GetChildren()))

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
		expandBtn.TextColor3 = Theme.text
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
		label.TextColor3 = Theme.text
		label.Font = Enum.Font.Code
		label.TextSize = 11
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.ZIndex = 28
		label.Parent = row

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

	function refreshTree()
		for _, child in ipairs(treePanel:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		layoutOrder = 0

		if searchQuery ~= "" then
			local matches = 0
			local queryLower = searchQuery:lower()

			pcall(function()
				for _, inst in ipairs(game:GetDescendants()) do
					if inst.Name:lower():find(queryLower, 1, true) then
						matches = matches + 1
						createNode(inst, 0, inst:GetFullName())

						if matches >= 200 then
							break
						end
					end
				end
			end)

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

			return
		end

		local function build(inst, depth)
			if depth > 10 then
				return
			end

			createNode(inst, depth)

			if expanded[inst] then
				local children = {}

				pcall(function()
					children = inst:GetChildren()
				end)

				table.sort(children, function(a, b)
					return a.Name:lower() < b.Name:lower()
				end)

				for _, child in ipairs(children) do
					build(child, depth + 1)
				end
			end
		end

		build(game, 0)
	end

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

	refreshTree()
end

return Explorer
