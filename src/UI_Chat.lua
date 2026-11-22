--[[
  UI_Chat.lua
  Qué: interfaz principal J.A.R.V.I.S.
  - Chat.
  - Panel API/UAI.
  - Explorer.
  - Compatible con móvil.
]]

local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local UI_Chat = {}
UI_Chat.__index = UI_Chat

local function makeDraggable(frame, handle)
	local dragging = false
	local start = nil
	local startPos = nil

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			start = input.Position
			startPos = frame.Position
		end
	end)

	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - start
			frame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

local function trim(s)
	return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function UI_Chat.new(opts)
	local self = setmetatable({}, UI_Chat)

	self.gui = opts.gui
	self.Theme = opts.Theme
	self.Config = opts.Config
	self.cfg = opts.cfg
	self.UAI = opts.UAI
	self.Visual = opts.Visual
	self.API_KEY = opts.apiKey
	self.onSend = opts.onSend

	self.activeTab = "chats"

	self:_build()
	self:setTab("chats")
	self:renderActiveChat()

	return self
end

function UI_Chat:persist()
	self.Config.save(self.cfg)
end

function UI_Chat:getActiveChat()
	for _, chat in ipairs(self.cfg.chats) do
		if chat.id == self.cfg.active_chat then
			return chat
		end
	end

	return self.cfg.chats[1]
end

function UI_Chat:setBorderMode(mode)
	if mode == "uai" then
		self.Theme.tween(self.windowStroke, {
			Color = self.Theme.uaiYellow,
			Transparency = 0.1,
		}, 0.2)
	else
		self.Theme.tween(self.windowStroke, {
			Color = self.Theme.chatGreen,
			Transparency = 0.25,
		}, 0.2)
	end
end

function UI_Chat:setStatus(text)
	text = tostring(text or "SYSTEM")

	self.statusLbl.Text = text:upper()

	local lower = text:lower()
	local working = lower:find("hack")
		or lower:find("override")
		or lower:find("process")
		or lower:find("espera")
		or lower:find("afinando")
		or lower:find("sistema")
		or lower:find("uai")
		or lower:find("trabaj")

	local errorState = lower:find("error") or lower:find("fail")

	if errorState then
		self.titleLbl.Text = "J.A.R.V.I.S. // ERROR"
		self.titleLbl.TextColor3 = self.Theme.danger
		self:setBorderMode("uai")
	elseif working then
		self.titleLbl.Text = "J.A.R.V.I.S. // SISTEMA"
		self.titleLbl.TextColor3 = self.Theme.uaiYellow
		self:setBorderMode("uai")
	else
		self.titleLbl.Text = "J.A.R.V.I.S."
		self.titleLbl.TextColor3 = self.Theme.accent
		self:setBorderMode("chat")
	end
end

function UI_Chat:_build()
	local Theme = self.Theme

	local window = Instance.new("Frame")
	window.Name = "JarvisWorkbench"
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromOffset(760, 460)
	window.BackgroundColor3 = Theme.panel
	window.BackgroundTransparency = 0.08
	window.BorderSizePixel = 0
	window.Visible = false
	window.ZIndex = 20
	window.Parent = self.gui

	Theme.mkCorner(window, 6)
	self.window = window

	self.windowStroke = Theme.mkStroke(window, Theme.chatGreen, 1.5, 0.25)
	Theme.mkBrackets(window, Theme.border, 2, 26)

	local function responsive()
		local abs = self.gui.AbsoluteSize
		if abs.X < 780 or abs.Y < 520 then
			window.Size = UDim2.fromScale(0.96, 0.76)
		else
			window.Size = UDim2.fromOffset(760, 460)
		end
	end

	self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(responsive)
	task.defer(responsive)

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 38)
	titleBar.BackgroundColor3 = Theme.sidebar
	titleBar.BackgroundTransparency = 0.15
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 21
	titleBar.Parent = window

	Theme.mkCorner(titleBar, 6)
	makeDraggable(window, titleBar)

	self.titleLbl = Instance.new("TextLabel")
	self.titleLbl.Size = UDim2.new(0.55, 0, 1, 0)
	self.titleLbl.Position = UDim2.fromOffset(16, 0)
	self.titleLbl.BackgroundTransparency = 1
	self.titleLbl.Text = "J.A.R.V.I.S."
	self.titleLbl.TextColor3 = Theme.accent
	self.titleLbl.Font = Enum.Font.Code
	self.titleLbl.TextSize = 16
	self.titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	self.titleLbl.ZIndex = 22
	self.titleLbl.Parent = titleBar

	self.statusLbl = Instance.new("TextLabel")
	self.statusLbl.Size = UDim2.new(0.45, -56, 1, 0)
	self.statusLbl.Position = UDim2.new(0.55, 0, 0, 0)
	self.statusLbl.BackgroundTransparency = 1
	self.statusLbl.Text = "SYSTEM ONLINE"
	self.statusLbl.TextColor3 = Theme.textDim
	self.statusLbl.Font = Enum.Font.Code
	self.statusLbl.TextSize = 12
	self.statusLbl.TextXAlignment = Enum.TextXAlignment.Right
	self.statusLbl.ZIndex = 22
	self.statusLbl.Parent = titleBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(26, 26)
	closeBtn.Position = UDim2.new(1, -34, 0.5, -13)
	closeBtn.BackgroundColor3 = Theme.danger
	closeBtn.BackgroundTransparency = 0.15
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.Code
	closeBtn.TextSize = 14
	closeBtn.AutoButtonColor = false
	closeBtn.ZIndex = 23
	closeBtn.Parent = titleBar

	Theme.mkCorner(closeBtn, 4)

	closeBtn.MouseButton1Click:Connect(function()
		self:close()
	end)

	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, -16, 1, -50)
	body.Position = UDim2.fromOffset(8, 44)
	body.BackgroundTransparency = 1
	body.ZIndex = 21
	body.Parent = window

	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 170, 1, 0)
	sidebar.BackgroundColor3 = Theme.sidebar
	sidebar.BackgroundTransparency = 0.12
	sidebar.BorderSizePixel = 0
	sidebar.ZIndex = 22
	sidebar.Parent = body

	Theme.mkCorner(sidebar, 6)
	Theme.mkStroke(sidebar, Theme.border, 1, 0.65)

	local function tabButton(text, y)
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -12, 0, 24)
		button.Position = UDim2.fromOffset(6, y)
		button.BackgroundColor3 = Theme.row
		button.BackgroundTransparency = 0.1
		button.Text = text
		button.TextColor3 = Theme.text
		button.Font = Enum.Font.Code
		button.TextSize = 12
		button.AutoButtonColor = false
		button.ZIndex = 23
		button.Parent = sidebar

		Theme.mkCorner(button, 4)

		return button
	end

	self.tabChats = tabButton("CHAT", 6)
	self.tabProviders = tabButton("API / UAI", 34)
	self.tabFiles = tabButton("EXPLORER", 62)

	self.tabChats.MouseButton1Click:Connect(function()
		self:setTab("chats")
	end)

	self.tabProviders.MouseButton1Click:Connect(function()
		self:setTab("providers")
	end)

	self.tabFiles.MouseButton1Click:Connect(function()
		self:setTab("files")
	end)

	self.sideList = Instance.new("ScrollingFrame")
	self.sideList.Size = UDim2.new(1, -12, 1, -132)
	self.sideList.Position = UDim2.fromOffset(6, 92)
	self.sideList.BackgroundTransparency = 1
	self.sideList.BorderSizePixel = 0
	self.sideList.ScrollBarThickness = 3
	self.sideList.ScrollBarImageColor3 = Theme.border
	self.sideList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.sideList.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.sideList.ZIndex = 23
	self.sideList.Parent = sidebar

	local sideLayout = Instance.new("UIListLayout", self.sideList)
	sideLayout.Padding = UDim.new(0, 4)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder

	self.newChatBtn = Instance.new("TextButton")
	self.newChatBtn.Size = UDim2.new(1, -12, 0, 28)
	self.newChatBtn.Position = UDim2.new(0, 6, 1, -34)
	self.newChatBtn.BackgroundColor3 = Theme.row
	self.newChatBtn.BackgroundTransparency = 0.08
	self.newChatBtn.Text = "+ NUEVO CHAT"
	self.newChatBtn.TextColor3 = Theme.text
	self.newChatBtn.Font = Enum.Font.Code
	self.newChatBtn.TextSize = 12
	self.newChatBtn.AutoButtonColor = false
	self.newChatBtn.ZIndex = 23
	self.newChatBtn.Parent = sidebar

	Theme.mkCorner(self.newChatBtn, 4)

	self.newChatBtn.MouseButton1Click:Connect(function()
		local id = HttpService:GenerateGUID(false)

		table.insert(self.cfg.chats, 1, {
			id = id,
			title = "Chat " .. tostring(#self.cfg.chats + 1),
			messages = {},
		})

		self.cfg.active_chat = id
		self:persist()
		self:setTab("chats")
		self:renderActiveChat()
	end)

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -182, 1, 0)
	content.Position = UDim2.new(0, 178, 0, 0)
	content.BackgroundColor3 = Theme.plate
	content.BackgroundTransparency = 0.18
	content.BorderSizePixel = 0
	content.ZIndex = 22
	content.Parent = body

	Theme.mkCorner(content, 6)
	Theme.mkStroke(content, Theme.border, 1, 0.65)

	self.content = content

	self.msgScroll = Instance.new("ScrollingFrame")
	self.msgScroll.Size = UDim2.new(1, -12, 1, -56)
	self.msgScroll.Position = UDim2.fromOffset(6, 6)
	self.msgScroll.BackgroundTransparency = 1
	self.msgScroll.BorderSizePixel = 0
	self.msgScroll.ScrollBarThickness = 4
	self.msgScroll.ScrollBarImageColor3 = Theme.border
	self.msgScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.msgScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.msgScroll.ZIndex = 23
	self.msgScroll.Parent = content

	local msgLayout = Instance.new("UIListLayout", self.msgScroll)
	msgLayout.Padding = UDim.new(0, 6)
	msgLayout.SortOrder = Enum.SortOrder.LayoutOrder

	self.inputBar = Instance.new("Frame")
	self.inputBar.Size = UDim2.new(1, -12, 0, 40)
	self.inputBar.Position = UDim2.new(0, 6, 1, -46)
	self.inputBar.BackgroundColor3 = Theme.inputBg
	self.inputBar.BackgroundTransparency = 0.1
	self.inputBar.BorderSizePixel = 0
	self.inputBar.ZIndex = 23
	self.inputBar.Parent = content

	Theme.mkCorner(self.inputBar, 4)
	Theme.mkStroke(self.inputBar, Theme.border, 1, 0.6)

	self.inputBox = Instance.new("TextBox")
	self.inputBox.Size = UDim2.new(1, -64, 1, 0)
	self.inputBox.Position = UDim2.fromOffset(10, 0)
	self.inputBox.BackgroundTransparency = 1
	self.inputBox.PlaceholderText = "Escribe un comando, Sir..."
	self.inputBox.PlaceholderColor3 = Theme.textDim
	self.inputBox.Text = ""
	self.inputBox.TextColor3 = Theme.text
	self.inputBox.Font = Enum.Font.Code
	self.inputBox.TextSize = 13
	self.inputBox.TextXAlignment = Enum.TextXAlignment.Left
	self.inputBox.ClearTextOnFocus = false
	self.inputBox.ZIndex = 24
	self.inputBox.Parent = self.inputBar

	local sendBtn = Instance.new("TextButton")
	sendBtn.Size = UDim2.new(0, 44, 1, -12)
	sendBtn.Position = UDim2.new(1, -52, 0, 6)
	sendBtn.BackgroundColor3 = Theme.border
	sendBtn.Text = ">"
	sendBtn.TextColor3 = Color3.new(0, 0, 0)
	sendBtn.Font = Enum.Font.Code
	sendBtn.TextSize = 18
	sendBtn.AutoButtonColor = false
	sendBtn.ZIndex = 24
	sendBtn.Parent = self.inputBar

	Theme.mkCorner(sendBtn, 4)

	sendBtn.MouseButton1Click:Connect(function()
		self:_sendInput()
	end)

	self.inputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			self:_sendInput()
		end
	end)

	self.providersPane = Instance.new("ScrollingFrame")
	self.providersPane.Size = UDim2.new(1, -12, 1, -12)
	self.providersPane.Position = UDim2.fromOffset(6, 6)
	self.providersPane.BackgroundTransparency = 1
	self.providersPane.BorderSizePixel = 0
	self.providersPane.Visible = false
	self.providersPane.ScrollBarThickness = 4
	self.providersPane.ScrollBarImageColor3 = Theme.border
	self.providersPane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	self.providersPane.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.providersPane.ZIndex = 23
	self.providersPane.Parent = content

	local providersLayout = Instance.new("UIListLayout", self.providersPane)
	providersLayout.Padding = UDim.new(0, 8)
	providersLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local providersPadding = Instance.new("UIPadding", self.providersPane)
	providersPadding.PaddingTop = UDim.new(0, 4)
	providersPadding.PaddingLeft = UDim.new(0, 4)
	providersPadding.PaddingRight = UDim.new(0, 4)

	self.filesPane = Instance.new("Frame")
	self.filesPane.Size = UDim2.new(1, -12, 1, -12)
	self.filesPane.Position = UDim2.fromOffset(6, 6)
	self.filesPane.BackgroundTransparency = 1
	self.filesPane.Visible = false
	self.filesPane.ZIndex = 23
	self.filesPane.ClipsDescendants = true
	self.filesPane.Parent = content
end

function UI_Chat:_sendInput()
	local text = trim(self.inputBox.Text)
	if text == "" then
		return
	end

	self.inputBox.Text = ""

	if type(self.onSend) == "function" then
		self.onSend(text)
	end
end

function UI_Chat:refreshChatList()
	for _, child in ipairs(self.sideList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for index, chat in ipairs(self.cfg.chats) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, 0, 0, 26)
		button.BackgroundColor3 = chat.id == self.cfg.active_chat and self.Theme.row or self.Theme.plate
		button.BackgroundTransparency = 0.08
		button.Text = " " .. tostring(chat.title or "Chat")
		button.TextColor3 = self.Theme.text
		button.Font = Enum.Font.Code
		button.TextSize = 12
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.AutoButtonColor = false
		button.LayoutOrder = index
		button.ZIndex = 23
		button.Parent = self.sideList

		self.Theme.mkCorner(button, 4)

		button.MouseButton1Click:Connect(function()
			self.cfg.active_chat = chat.id
			self:persist()
			self:refreshChatList()
			self:renderActiveChat()
		end)
	end
end

function UI_Chat:_appendBubble(role, text, order)
	local Theme = self.Theme

	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.new(1, -10, 0, 0)
	bubble.AutomaticSize = Enum.AutomaticSize.Y
	bubble.BackgroundColor3 = role == "user" and Theme.bubbleUser or Theme.bubbleAi
	bubble.BackgroundTransparency = 0.08
	bubble.BorderSizePixel = 0
	bubble.LayoutOrder = order or #self.msgScroll:GetChildren()
	bubble.ZIndex = 23
	bubble.Parent = self.msgScroll

	Theme.mkCorner(bubble, 5)

	if role ~= "user" then
		Theme.mkStroke(bubble, Theme.border, 1, 0.65)
	end

	local padding = Instance.new("UIPadding", bubble)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Text = tostring(text)
	label.TextColor3 = role == "user" and Theme.c2 or Theme.text
	label.Font = Enum.Font.Code
	label.TextSize = 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.ZIndex = 24
	label.Parent = bubble

	return bubble
end

function UI_Chat:renderActiveChat()
	for _, child in ipairs(self.msgScroll:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local chat = self:getActiveChat()

	for index, message in ipairs(chat.messages or {}) do
		self:_appendBubble(message.role, message.content, index)
	end

	task.defer(function()
		self.msgScroll.CanvasPosition = Vector2.new(0, self.msgScroll.AbsoluteCanvasSize.Y)
	end)
end

function UI_Chat:addBubble(role, text)
	local chat = self:getActiveChat()

	table.insert(chat.messages, {
		role = role,
		content = tostring(text),
	})

	self:persist()
	self:_appendBubble(role, text, #chat.messages)

	task.defer(function()
		self.msgScroll.CanvasPosition = Vector2.new(0, self.msgScroll.AbsoluteCanvasSize.Y)
	end)
end

function UI_Chat:buildProviders()
	for _, child in ipairs(self.providersPane:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	local Theme = self.Theme

	local function addLabel(text, color, size)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -8, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color or Theme.text
		label.Font = Enum.Font.Code
		label.TextSize = size or 12
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 24
		label.Parent = self.providersPane
		return label
	end

	addLabel("API / PUENTE", Theme.border, 14)

	local bridgeStatus = "DESCONOCIDO"
	if self.UAI and type(self.UAI.getStatus) == "function" then
		bridgeStatus = self.UAI.getStatus()
	end

	addLabel(
		"Estado UAI: " .. bridgeStatus,
		bridgeStatus == "CONECTADO" and Theme.green or Theme.textDim,
		12
	)

	addLabel("Groq API Key", Theme.text, 12)

	local keyBox = Instance.new("TextBox")
	keyBox.Size = UDim2.new(1, -8, 0, 34)
	keyBox.BackgroundColor3 = Theme.inputBg
	keyBox.BackgroundTransparency = 0.08
	keyBox.PlaceholderText = "gsk_..."
	keyBox.PlaceholderColor3 = Theme.textDim
	keyBox.Text = tostring(self.cfg.groq_key or "")
	keyBox.TextColor3 = Theme.text
	keyBox.Font = Enum.Font.Code
	keyBox.TextSize = 12
	keyBox.ZIndex = 24
	keyBox.Parent = self.providersPane

	Theme.mkCorner(keyBox, 4)
	Theme.mkStroke(keyBox, Theme.border, 1, 0.65)

	local saveBtn = Instance.new("TextButton")
	saveBtn.Size = UDim2.new(1, -8, 0, 32)
	saveBtn.BackgroundColor3 = Theme.border
	saveBtn.Text = "GUARDAR KEY"
	saveBtn.TextColor3 = Color3.new(0, 0, 0)
	saveBtn.Font = Enum.Font.Code
	saveBtn.TextSize = 13
	saveBtn.AutoButtonColor = false
	saveBtn.ZIndex = 24
	saveBtn.Parent = self.providersPane

	Theme.mkCorner(saveBtn, 4)

	local saveStatus = addLabel("", Theme.textDim, 11)

	saveBtn.MouseButton1Click:Connect(function()
		local key = trim(keyBox.Text)

		if key == "" then
			saveStatus.Text = "Introduce una key válida."
			saveStatus.TextColor3 = Theme.danger
			return
		end

		self.cfg.groq_key = key
		self.cfg.provider_keys = self.cfg.provider_keys or {}
		self.cfg.provider_keys.groq_key = key
		self.API_KEY = key
		self:persist()

		saveStatus.Text = "Guardado localmente."
		saveStatus.TextColor3 = Theme.green

		if self.UAI and type(self.UAI.injectProvider) == "function" then
			task.spawn(function()
				local ok, message = self.UAI.injectProvider({
					id = "groq",
					name = "Groq",
					keyField = "groq_key",
				}, key)

				saveStatus.Text = ok and ("UAI: " .. tostring(message)) or ("UAI error: " .. tostring(message))
				saveStatus.TextColor3 = ok and Theme.green or Theme.danger
			end)
		end
	end)

	addLabel("Paneles UAI (si está conectado)", Theme.text, 12)

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -8, 0, 28)
	row.BackgroundTransparency = 1
	row.ZIndex = 24
	row.Parent = self.providersPane

	local function miniButton(text, x, section)
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0.33, -4, 1, 0)
		button.Position = UDim2.new(x, 0, 0, 0)
		button.BackgroundColor3 = Theme.row
		button.BackgroundTransparency = 0.08
		button.Text = text
		button.TextColor3 = Theme.text
		button.Font = Enum.Font.Code
		button.TextSize = 11
		button.AutoButtonColor = false
		button.ZIndex = 24
		button.Parent = row

		Theme.mkCorner(button, 4)

		button.MouseButton1Click:Connect(function()
			local ok, message = false, "UAI no conectado."

			if self.UAI and type(self.UAI.show) == "function" then
				ok, message = self.UAI.show(section)
			end

			saveStatus.Text = ok and ("Abriendo " .. section .. "...") or ("No disponible: " .. tostring(message))
			saveStatus.TextColor3 = ok and Theme.green or Theme.danger
		end)
	end

	miniButton("CHAT", 0, "chat")
	miniButton("PROV", 0.33, "providers")
	miniButton("LOGS", 0.66, "logs")
end

function UI_Chat:buildFiles()
	for _, child in ipairs(self.filesPane:GetChildren()) do
		child:Destroy()
	end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Explorer no cargado."
	label.TextColor3 = self.Theme.textDim
	label.Font = Enum.Font.Code
	label.TextSize = 13
	label.TextWrapped = true
	label.ZIndex = 24

	label.Font = Enum.Font.Code
					keyField = "groq_key",
	label.Text = "Explorer no cargado."
	label.Parent = self.filesPane

	local function miniButton(text, x, section)
		local key = trim(keyBox.Text)

function UI_Chat:setTab(tab)
	Theme.mkCorner(keyBox, 4)
			end
	miniButton("CHAT", 0, "chat")
	label.BackgroundTransparency = 1
		self.cfg.groq_key = key
					id = "groq",
end
	self.newChatBtn.Visible = tab == "chats"

	keyBox.Parent = self.providersPane
		button.BackgroundColor3 = Theme.row
			saveStatus.Text = "Introduce una key válida."
	row.Size = UDim2.new(1, -8, 0, 28)
		button.Position = UDim2.new(x, 0, 0, 0)
	Theme.mkCorner(saveBtn, 4)
			task.spawn(function()

		button.TextColor3 = Theme.text
			saveStatus.TextColor3 = ok and Theme.green or Theme.danger
		button.AutoButtonColor = false
	local label = Instance.new("TextLabel")

	saveBtn.AutoButtonColor = false
		self.API_KEY = key
	saveBtn.BackgroundColor3 = Theme.border
	saveBtn.TextColor3 = Color3.new(0, 0, 0)
			end)
	label.TextWrapped = true
	keyBox.TextSize = 12

		child:Destroy()

				saveStatus.Text = ok and ("UAI: " .. tostring(message)) or ("UAI error: " .. tostring(message))
	local saveBtn = Instance.new("TextButton")
		end
	end)
		button.MouseButton1Click:Connect(function()
	saveBtn.Parent = self.providersPane
	addLabel("Paneles UAI (si está conectado)", Theme.text, 12)
function UI_Chat:buildFiles()
			if self.UAI and type(self.UAI.show) == "function" then
				}, key)
	local row = Instance.new("Frame")
		local button = Instance.new("TextButton")

	Theme.mkStroke(keyBox, Theme.border, 1, 0.65)

	miniButton("PROV", 0.33, "providers")
		self.cfg.provider_keys = self.cfg.provider_keys or {}
					name = "Groq",

		saveStatus.Text = "Guardado localmente."

		button.BackgroundTransparency = 0.08
			saveStatus.TextColor3 = Theme.danger

				local ok, message = self.UAI.injectProvider({
		button.Font = Enum.Font.Code
		end)
		button.ZIndex = 24
		Theme.mkCorner(button, 4)
		self:persist()
	keyBox.ZIndex = 24
		if self.UAI and type(self.UAI.injectProvider) == "function" then
	end
	saveBtn.MouseButton1Click:Connect(function()

			local ok, message = false, "UAI no conectado."
				ok, message = self.UAI.show(section)
		button.Size = UDim2.new(0.33, -4, 1, 0)
		if key == "" then
			saveStatus.Text = ok and ("Abriendo " .. section .. "...") or ("No disponible: " .. tostring(message))
	miniButton("LOGS", 0.66, "logs")
	self.providersPane.Visible = tab == "providers"
		button.Text = text
		button.TextSize = 11

end
	self.filesPane.Visible = tab == "files"

	local function paintTab(button, active)
		button.BackgroundColor3 = active and self.Theme.accent or self.Theme.row
		button.TextColor3 = active and Color3.new(0, 0, 0) or self.Theme.text
	end

	paintTab(self.tabChats, tab == "chats")
	paintTab(self.tabProviders, tab == "providers")
	paintTab(self.tabFiles, tab == "files")

	if tab == "chats" then
		self:refreshChatList()
	elseif tab == "providers" then
		self:buildProviders()
	elseif tab == "files" then
		self:buildFiles()
	end
end

function UI_Chat:toggle()
	self.window.Visible = not self.window.Visible

	if self.Visual and self.Visual.setChatOpen then
		self.Visual:setChatOpen(self.window.Visible)
	end
end

function UI_Chat:close()
	self.window.Visible = false

	if self.Visual and self.Visual.setChatOpen then
		self.Visual:setChatOpen(false)
	end
end

return UI_Chat
