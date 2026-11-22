local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local UI_Chat = {}
UI_Chat.__index = UI_Chat

local function makeDraggable(frame, handle)
	local dragging, start, startPos
	handle.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging, start, startPos = true, i.Position, frame.Position end end)
	handle.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
	UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + (i.Position - start).X, startPos.Y.Scale, startPos.Y.Offset + (i.Position - start).Y) end end)
end

function UI_Chat.new(opts)
	local self = setmetatable({}, UI_Chat)
	self.gui, self.Theme, self.Config, self.cfg = opts.gui, opts.Theme, opts.Config, opts.cfg
	self.Visual, self.API_KEY, self.onSend = opts.Visual, opts.apiKey, opts.onSend
	self.activeTab = "chats"
	self:_build()
	return self
end

function UI_Chat:persist() self.Config.save(self.cfg) end
function UI_Chat:getActiveChat()
	for _, ch in ipairs(self.cfg.chats) do if ch.id == self.cfg.active_chat then return ch end end
	return self.cfg.chats[1]
end

function UI_Chat:setBorderMode(mode)
	if mode == "uai" then self.Theme.tween(self.windowStroke, { Color = self.Theme.uaiYellow, Transparency = 0.1 }, 0.2)
	else self.Theme.tween(self.windowStroke, { Color = self.Theme.chatGreen, Transparency = 0.2 }, 0.2) end
end

function UI_Chat:setStatus(txt)
	self.statusLbl.Text = string.upper(txt)
	local working = txt:find("hack") or txt:find("espera") or txt:find("afinando") or txt:find("traduc") or txt:find("sistema") or txt:find("override")
	if working then self.titleLbl.Text = "J.A.R.V.I.S. // OVERRIDE" self.titleLbl.TextColor3 = self.Theme.uaiYellow self:setBorderMode("uai")
	else self.titleLbl.Text = "J.A.R.V.I.S." self.titleLbl.TextColor3 = self.Theme.accent self:setBorderMode("chat") end
end

function UI_Chat:_build()
	local Theme = self.Theme
	local WIN_W, WIN_H = 600, 400
	local window = Instance.new("Frame")
	window.Name = "JarvisWorkbench" window.Size = UDim2.fromOffset(WIN_W, WIN_H) window.Position = UDim2.fromScale(0.5, 0.5) window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.BackgroundColor3 = Theme.panel window.BackgroundTransparency = 0.15 window.BorderSizePixel = 0 window.Visible = false window.ZIndex = 20 window.Parent = self.gui
	Theme.mkCorner(window, 4) self.window = window self.windowStroke = Theme.mkStroke(window, Theme.chatGreen, 1.5, 0.2) Theme.mkBrackets(window, Theme.border, 2, 25)

	local titleBar = Instance.new("Frame") titleBar.Size = UDim2.new(1, 0, 0, 36) titleBar.BackgroundColor3 = Theme.sidebar titleBar.BackgroundTransparency = 0.3 titleBar.BorderSizePixel = 0 titleBar.ZIndex = 21 titleBar.Parent = window makeDraggable(window, titleBar)
	self.titleLbl = Instance.new("TextLabel") self.titleLbl.Size = UDim2.new(0.6, 0, 1, 0) self.titleLbl.Position = UDim2.fromOffset(16, 0) self.titleLbl.BackgroundTransparency = 1 self.titleLbl.Text = "J.A.R.V.I.S." self.titleLbl.TextColor3 = Theme.accent self.titleLbl.Font = Enum.Font.Code self.titleLbl.TextSize = 16 self.titleLbl.TextXAlignment = Enum.TextXAlignment.Left self.titleLbl.ZIndex = 22 self.titleLbl.Parent = titleBar
	self.statusLbl = Instance.new("TextLabel") self.statusLbl.Size = UDim2.new(0.4, -50, 1, 0) self.statusLbl.Position = UDim2.new(0.6, 0, 0, 0) self.statusLbl.BackgroundTransparency = 1 self.statusLbl.Text = "SYSTEM ONLINE" self.statusLbl.TextColor3 = Theme.textDim self.statusLbl.Font = Enum.Font.Code self.statusLbl.TextSize = 12 self.statusLbl.TextXAlignment = Enum.TextXAlignment.Right self.statusLbl.ZIndex = 22 self.statusLbl.Parent = titleBar

	local closeBtn = Instance.new("TextButton") closeBtn.Size = UDim2.fromOffset(24, 24) closeBtn.Position = UDim2.new(1, -32, 0.5, -12) closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50) closeBtn.Text = "X" closeBtn.TextColor3 = Color3.new(1, 1, 1) closeBtn.Font = Enum.Font.Code closeBtn.TextSize = 14 closeBtn.AutoButtonColor = false closeBtn.ZIndex = 23 closeBtn.Parent = titleBar Theme.mkCorner(closeBtn, 2) closeBtn.MouseButton1Click:Connect(function() self:close() end)

	local body = Instance.new("Frame") body.Size = UDim2.new(1, -16, 1, -52) body.Position = UDim2.fromOffset(8, 44) body.BackgroundTransparency = 1 body.ZIndex = 21 body.Parent = window
	self.msgScroll = Instance.new("ScrollingFrame") self.msgScroll.Size = UDim2.new(1, 0, 1, -46) self.msgScroll.Position = UDim2.fromOffset(0, 0) self.msgScroll.BackgroundTransparency = 1 self.msgScroll.ScrollBarThickness = 3 self.msgScroll.ScrollBarImageColor3 = Theme.border self.msgScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y self.msgScroll.CanvasSize = UDim2.new(0, 0, 0, 0) self.msgScroll.ZIndex = 22 self.msgScroll.Parent = body
	local lay = Instance.new("UIListLayout", self.msgScroll) lay.Padding = UDim.new(0, 8) lay.SortOrder = Enum.SortOrder.LayoutOrder

	self.inputBar = Instance.new("Frame") self.inputBar.Size = UDim2.new(1, 0, 0, 38) self.inputBar.Position = UDim2.new(0, 0, 1, -38) self.inputBar.BackgroundColor3 = Theme.inputBg self.inputBar.BackgroundTransparency = 0.2 self.inputBar.BorderSizePixel = 0 self.inputBar.ZIndex = 22 self.inputBar.Parent = body Theme.mkCorner(self.inputBar, 4)
	self.inputBox = Instance.new("TextBox") self.inputBox.Size = UDim2.new(1, -60, 1, 0) self.inputBox.Position = UDim2.fromOffset(12, 0) self.inputBox.BackgroundTransparency = 1 self.inputBox.PlaceholderText = "Enter command, Sir..." self.inputBox.PlaceholderColor3 = Theme.textDim self.inputBox.Text = "" self.inputBox.TextColor3 = Theme.text self.inputBox.Font = Enum.Font.Code self.inputBox.TextSize = 14 self.inputBox.TextXAlignment = Enum.TextXAlignment.Left self.inputBox.ZIndex = 23 self.inputBox.Parent = self.inputBar

	local sendBtn = Instance.new("TextButton") sendBtn.Size = UDim2.new(0, 40, 1, -12) sendBtn.Position = UDim2.new(1, -48, 0, 6) sendBtn.BackgroundColor3 = Theme.border sendBtn.Text = ">" sendBtn.TextColor3 = Color3.new(0, 0, 0) sendBtn.Font = Enum.Font.Code sendBtn.TextSize = 18 sendBtn.AutoButtonColor = false sendBtn.ZIndex = 23 sendBtn.Parent = self.inputBar Theme.mkCorner(sendBtn, 4)
	
	local function send() if self.inputBox.Text ~= "" then self.onSend(self.inputBox.Text) end end
	sendBtn.MouseButton1Click:Connect(send)
	self.inputBox.FocusLost:Connect(function(enterPressed) if enterPressed then send() end end)
end

function UI_Chat:addBubble(role, text)
	local Theme = self.Theme
	local ch = self:getActiveChat()
	table.insert(ch.messages, {role = role, content = text})
	self:persist()

	local bubble = Instance.new("Frame") bubble.Size = UDim2.new(1, -10, 0, 0) bubble.Position = UDim2.fromOffset(5, 0) bubble.BackgroundTransparency = 1 bubble.ZIndex = 23 bubble.AutomaticSize = Enum.AutomaticSize.Y bubble.Parent = self.msgScroll
	local lbl = Instance.new("TextLabel") lbl.Size = UDim2.new(1, -12, 0, 0) lbl.Position = UDim2.fromOffset(6, 4) lbl.BackgroundTransparency = 1 lbl.Text = text lbl.TextColor3 = Theme.text lbl.Font = Enum.Font.Code lbl.TextSize = 13 lbl.TextWrapped = true lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.TextYAlignment = Enum.TextYAlignment.Top lbl.ZIndex = 24 lbl.AutomaticSize = Enum.AutomaticSize.Y lbl.Parent = bubble

	if role == "user" then bubble.BackgroundColor3 = Theme.bubbleUser Theme.mkCorner(bubble, 4) lbl.TextColor3 = Theme.accent
	else bubble.BackgroundColor3 = Theme.bubbleAi Theme.mkCorner(bubble, 4) Theme.mkStroke(bubble, Theme.border, 1, 0.6) end

	local padding = Instance.new("UIPadding", bubble) padding.PaddingTop = UDim.new(0, 6) padding.PaddingBottom = UDim.new(0, 6) padding.PaddingLeft = UDim.new(0, 2) padding.PaddingRight = UDim.new(0, 2)
	self.msgScroll.CanvasPosition = Vector2.new(0, self.msgScroll.AbsoluteCanvasSize.Y)
end

function UI_Chat:toggle()
	if not self.window then return end
	self.window.Visible = not self.window.Visible
	if self.window.Visible then self.window:TweenPosition(UDim2.fromScale(0.5, 0.5), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.2, true)
	else self.window:TweenPosition(UDim2.new(0.5, 0, 1.5, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quart, 0.2, true) end
end

function UI_Chat:close() self:toggle() end
return UI_Chat
