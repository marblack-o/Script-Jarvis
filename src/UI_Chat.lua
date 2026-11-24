--[[
  UI_Chat.lua
  Qué: interfaz principal J.A.R.V.I.S.
  - Chat.
  - Panel API/UAI.
  - Explorer.
  - Compatible con móvil.
  Versión corregida.
]]

local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local UI_Chat = {}
UI_Chat.__index = UI_Chat

local function mk(class, props, parent)
	local obj = Instance.new(class)

	if obj:IsA("GuiObject") then
		obj.BorderSizePixel = 0
	end

	for key, value in pairs(props or {}) do
		obj[key] = value
	end

	obj.Parent = parent
	return obj
end

local function trim(s)
	return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

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
	local color = self.Theme.chatGreen
	local transparency = 0.25

	if mode == "uai" then
		color = self.Theme.uaiYellow
		transparency = 0.1
	end

	self.Theme.tween(self.windowStroke, {
		Color = color,
		Transparency = transparency,
	}, 0.2)
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

	local window = mk("Frame", {
		Name = "JarvisWorkbench",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(760, 460),
		BackgroundColor3 = Theme.panel,
		BackgroundTransparency = 0.08,
		Visible = false,
		ZIndex = 20,
	}, self.gui)

	self.window = window

	Theme.mkCorner(window, 6)
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

	local titleBar = mk("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Theme.sidebar,
		BackgroundTransparency = 0.15,
		ZIndex = 21,
	}, window)

	Theme.mkCorner(titleBar, 6)
	makeDraggable(window, titleBar)

	self.titleLbl = mk("TextLabel", {
		Size = UDim2.new(0.55, 0, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		BackgroundTransparency = 1,
		Text = "J.A.R.V.I.S.",
		TextColor3 = Theme.accent,
		Font = Enum.Font.Code,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
	}, titleBar)

	self.statusLbl = mk("TextLabel", {
		Size = UDim2.new(0.45, -56, 1, 0),
		Position = UDim2.new(0.55, 0, 0, 0),
		BackgroundTransparency = 1,
		Text = "SYSTEM ONLINE",
		TextColor3 = Theme.textDim,
		Font = Enum.Font.Code,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 22,
	}, titleBar)

	local closeBtn = mk("TextButton", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -34, 0.5, -13),
		BackgroundColor3 = Theme.danger,
		BackgroundTransparency = 0.15,
		Text = "X",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.Code,
		TextSize = 14,
		AutoButtonColor = false,
		ZIndex = 23,
	}, titleBar)

	Theme.mkCorner(closeBtn, 4)

	closeBtn.MouseButton1Click:Connect(function()
		self:close()
	end)

	local body = mk("Frame", {
		Size = UDim2.new(1, -16, 1, -50),
		Position = UDim2.fromOffset(8, 44),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, window)

	local sidebar = mk("Frame", {
		Size = UDim2.new(0, 170, 1, 0),
		BackgroundColor3 = Theme.sidebar,
		BackgroundTransparency = 0.12,
		ZIndex = 22,
	}, body)

	Theme.mkCorner(sidebar, 6)
	Theme.mkStroke(sidebar, Theme.border, 1, 0.65)

	local function tabButton(text, y)
		local button = mk("TextButton", {
			Size = UDim2.new(1, -12, 0, 24),
			Position = UDim2.fromOffset(6, y),
			BackgroundColor3 = Theme.row,
			BackgroundTransparency = 0.1,
			Text = text,
			TextColor3 = Theme.text,
			Font = Enum.Font.Code,
			TextSize = 12,
			AutoButtonColor = false,
			ZIndex = 23,
		}, sidebar)

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

	self.sideList = mk("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -132),
		Position = UDim2.fromOffset(6, 92),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ZIndex = 23,
	}, sidebar)

	mk("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.sideList)

	self.newChatBtn = mk("TextButton", {
		Size = UDim2.new(1, -12, 0, 28),
		Position = UDim2.new(0, 6, 1, -34),
		BackgroundColor3 = Theme.row,
		BackgroundTransparency = 0.08,
		Text = "+ NUEVO CHAT",
		TextColor3 = Theme.text,
		Font = Enum.Font.Code,
		TextSize = 12,
		AutoButtonColor = false,
		ZIndex = 23,
	}, sidebar)

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

	local content = mk("Frame", {
		Size = UDim2.new(1, -182, 1, 0),
		Position = UDim2.new(0, 178, 0, 0),
		BackgroundColor3 = Theme.plate,
		BackgroundTransparency = 0.18,
		ZIndex = 22,
	}, body)

	Theme.mkCorner(content, 6)
	Theme.mkStroke(content, Theme.border, 1, 0.65)

	self.content = content

	self.msgScroll = mk("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -56),
		Position = UDim2.fromOffset(6, 6),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ZIndex = 23,
	}, content)

	mk("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.msgScroll)

	self.inputBar = mk("Frame", {
		Size = UDim2.new(1, -12, 0, 40),
		Position = UDim2.new(0, 6, 1, -46),
		BackgroundColor3 = Theme.inputBg,
		BackgroundTransparency = 0.1,
		ZIndex = 23,
	}, content)

	Theme.mkCorner(self.inputBar, 4)
	Theme.mkStroke(self.inputBar, Theme.border, 1, 0.6)

	self.inputBox = mk("TextBox", {
		Size = UDim2.new(1, -64, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		PlaceholderText = "Escribe un comando, Sir...",
		PlaceholderColor3 = Theme.textDim,
		Text = "",
		TextColor3 = Theme.text,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 24,
	}, self.inputBar)

	local sendBtn = mk("TextButton", {
		Size = UDim2.new(0, 44, 1, -12),
		Position = UDim2.new(1, -52, 0, 6),
		BackgroundColor3 = Theme.border,
		Text = ">",
		TextColor3 = Color3.new(0, 0, 0),
		Font = Enum.Font.Code,
		TextSize = 18,
		AutoButtonColor = false,
		ZIndex = 24,
	}, self.inputBar)

	Theme.mkCorner(sendBtn, 4)

	sendBtn.MouseButton1Click:Connect(function()
		self:_sendInput()
	end)

	self.inputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			self:_sendInput()
		end
	end)

	self.providersPane = mk("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -12),
		Position = UDim2.fromOffset(6, 6),
		BackgroundTransparency = 1,
		Visible = false,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ZIndex = 23,
	}, content)

	mk("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.providersPane)

	mk("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	}, self.providersPane)

	self.filesPane = mk("Frame", {
		Size = UDim2.new(1, -12, 1, -12),
		Position = UDim2.fromOffset(6, 6),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 23,
		ClipsDescendants = true,
	}, content)
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
		local button = mk("TextButton", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = chat.id == self.cfg.active_chat and self.Theme.row or self.Theme.plate,
			BackgroundTransparency = 0.08,
			Text = " " .. tostring(chat.title or "Chat"),
			TextColor3 = self.Theme.text,
			Font = Enum.Font.Code,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			LayoutOrder = index,
			ZIndex = 23,
		}, self.sideList)

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

	local bubble = mk("Frame", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = role == "user" and Theme.bubbleUser or Theme.bubbleAi,
		BackgroundTransparency = 0.08,
		LayoutOrder = order or #self.msgScroll:GetChildren(),
		ZIndex = 23,
	}, self.msgScroll)

	Theme.mkCorner(bubble, 5)

	if role ~= "user" then
		Theme.mkStroke(bubble, Theme.border, 1, 0.65)
	end

	mk("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, bubble)

	mk("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = tostring(text),
		TextColor3 = role == "user" and Theme.c2 or Theme.text,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 24,
	}, bubble)

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
		local label = mk("TextLabel", {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = color or Theme.text,
			Font = Enum.Font.Code,
			TextSize = size or 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 24,
		}, self.providersPane)

		return label
	end

	addLabel("API / PUENTE", Theme.border, 14)

	local bridgeStatus = "DESCONOCIDO"
	if self.UAI and type(self.UAI.getStatus) == "function" then
		bridgeStatus = self.UAI.getStatus()
	end

	addLabel(
		"Estado UAI: " .. tostring(bridgeStatus),
		bridgeStatus == "CONECTADO" and Theme.green or Theme.textDim,
		12
	)

	addLabel("Groq API Key", Theme.text, 12)

	local keyBox = mk("TextBox", {
		Size = UDim2.new(1, -8, 0, 34),
		BackgroundColor3 = Theme.inputBg,
		BackgroundTransparency = 0.08,
		PlaceholderText = "gsk_...",
		PlaceholderColor3 = Theme.textDim,
		Text = tostring(self.cfg.groq_key or ""),
		TextColor3 = Theme.text,
		Font = Enum.Font.Code,
		TextSize = 12,
		ZIndex = 24,
	}, self.providersPane)

	Theme.mkCorner(keyBox, 4)
	Theme.mkStroke(keyBox, Theme.border, 1, 0.65)

	local saveBtn = mk("TextButton", {
		Size = UDim2.new(1, -8, 0, 32),
		BackgroundColor3 = Theme.border,
		Text = "GUARDAR KEY",
		TextColor3 = Color3.new(0, 0, 0),
		Font = Enum.Font.Code,
		TextSize = 13,
		AutoButtonColor = false,
		ZIndex = 24,
	}, self.providersPane)

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

	local row = mk("Frame", {
		Size = UDim2.new(1, -8, 0, 28),
		BackgroundTransparency = 1,
		ZIndex = 24,
	}, self.providersPane)

	local function miniButton(text, x, section)
		local button = mk("TextButton", {
			Size = UDim2.new(0.33, -4, 1, 0),
			Position = UDim2.new(x, 0, 0, 0),
			BackgroundColor3 = Theme.row,
			BackgroundTransparency = 0.08,
			Text = text,
			TextColor3 = Theme.text,
			Font = Enum.Font.Code,
			TextSize = 11,
			AutoButtonColor = false,
			ZIndex = 24,
		}, row)

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

	mk("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "Explorer no cargado.",
		TextColor3 = self.Theme.textDim,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextWrapped = true,
		ZIndex = 24,
	}, self.filesPane)
end

function UI_Chat:setTab(tab)
	self.activeTab = tab

	self.msgScroll.Visible = tab == "chats"
	self.inputBar.Visible = tab == "chats"
	self.sideList.Visible = tab == "chats"
	self.newChatBtn.Visible = tab == "chats"

	self.providersPane.Visible = tab == "providers"
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