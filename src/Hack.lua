--[[
  Hack.lua
  Qué: ventana de override/hackeo.
  - Usa UAIBridge.
  - Si UAI está conectado, UAI actúa como agente.
  - Si no, UAIBridge delega a NativeBridge.
]]

local UserInputService = game:GetService("UserInputService")

local Hack = {}
Hack.__index = Hack

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

function Hack.new(opts)
	local self = setmetatable({}, Hack)

	self.gui = opts.gui
	self.Theme = opts.Theme
	self.UAI = opts.UAI
	self.cfg = opts.cfg
	self.ui = opts.ui
	self.visual = opts.visual
	self.apiKey = opts.apiKey
	self.groqChat = opts.groqChat
	self.jarvisPrompt = opts.capriPrompt or opts.jarvisPrompt

	self.running = false
	self.mode = "idle"
	self.clarifyCount = 0
	self.MAX_CLARIFY = 4

	self.brief = {
		original = "",
		answers = {},
		kind = "action",
	}

	self:_build()

	return self
end

function Hack:_build()
	local Theme = self.Theme

	local win = Instance.new("Frame")
	win.Size = UDim2.fromOffset(380, 240)
	win.Position = UDim2.new(1, -400, 1, -260)
	win.BackgroundColor3 = Theme.panel
	win.BackgroundTransparency = 0.08
	win.BorderSizePixel = 0
	win.Visible = false
	win.ZIndex = 40
	win.Parent = self.gui

	Theme.mkCorner(win, 5)
	Theme.mkStroke(win, Theme.uaiYellow, 1.5, 0.15)
	Theme.mkBrackets(win, Theme.uaiYellow, 2, 24)

	self.win = win

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 32)
	bar.BackgroundColor3 = Theme.sidebar
	bar.BackgroundTransparency = 0.1
	bar.BorderSizePixel = 0
	bar.ZIndex = 41
	bar.Parent = win

	Theme.mkCorner(bar, 5)
	makeDraggable(win, bar)

	self.title = Instance.new("TextLabel")
	self.title.Size = UDim2.new(1, -44, 1, 0)
	self.title.Position = UDim2.fromOffset(10, 0)
	self.title.BackgroundTransparency = 1
	self.title.Text = "J.A.R.V.I.S. // OVERRIDE"
	self.title.TextColor3 = Theme.uaiYellow
	self.title.Font = Enum.Font.Code
	self.title.TextSize = 14
	self.title.TextXAlignment = Enum.TextXAlignment.Left
	self.title.ZIndex = 42
	self.title.Parent = bar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(24, 24)
	closeBtn.Position = UDim2.new(1, -32, 0.5, -12)
	closeBtn.BackgroundColor3 = Theme.danger
	closeBtn.BackgroundTransparency = 0.15
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Font = Enum.Font.Code
	closeBtn.TextSize = 13
	closeBtn.AutoButtonColor = false
	closeBtn.ZIndex = 43
	closeBtn.Parent = bar

	Theme.mkCorner(closeBtn, 3)

	closeBtn.MouseButton1Click:Connect(function()
		win.Visible = false
	end)

	self.status = Instance.new("TextLabel")
	self.status.Size = UDim2.new(1, -20, 0, 18)
	self.status.Position = UDim2.fromOffset(10, 38)
	self.status.BackgroundTransparency = 1
	self.status.Text = "AWAITING DIRECTIVE"
	self.status.TextColor3 = Theme.textDim
	self.status.Font = Enum.Font.Code
	self.status.TextSize = 12
	self.status.TextXAlignment = Enum.TextXAlignment.Left
	self.status.ZIndex = 41
	self.status.Parent = win

	self.body = Instance.new("TextLabel")
	self.body.Size = UDim2.new(1, -20, 1, -66)
	self.body.Position = UDim2.fromOffset(10, 58)
	self.body.BackgroundTransparency = 1
	self.body.Text = ""
	self.body.TextColor3 = Theme.text
	self.body.Font = Enum.Font.Code
	self.body.TextSize = 12
	self.body.TextWrapped = true
	self.body.TextXAlignment = Enum.TextXAlignment.Left
	self.body.TextYAlignment = Enum.TextYAlignment.Top
	self.body.ZIndex = 41
	self.body.Parent = win
end

function Hack.detectKind(text)
	local lower = text:lower()

	if lower:find("investiga")
		or lower:find("busca")
		or lower:find("analiza")
		or lower:find("explora")
		or lower:find("lista")
		or lower:find("scan")
	then
		return "research"
	end

	return "action"
end

function Hack.isClear(text)
	local lower = text:lower()

	local about = lower:find("el juego")
		or lower:find("este juego")
		or lower:find("the game")
		or lower:find("workspace")
		or lower:find("scripts")

	local verb = lower:find("analiza")
		or lower:find("explora")
		or lower:find("lista")
		or lower:find("crea")
		or lower:find("haz")
		or lower:find("hack")

	if verb and about then
		return true
	end

	if #lower < 48 and (lower:find("analiza") or lower:find("explora")) then
		return true
	end

	return false
end

function Hack.buildPrompt(brief)
	local placeName = "unknown"

	pcall(function()
		local MarketplaceService = game:GetService("MarketplaceService")
		local info = MarketplaceService:GetProductInfo(game.PlaceId)
		placeName = info.Name
	end)

	local lines = {
		"JOB FROM J.A.R.V.I.S. (Roblox executor host)",
		"Live DataModel only. PlaceId=" .. tostring(game.PlaceId) .. " name=" .. tostring(placeName),
		"User request: " .. brief.original,
		"Job type: " .. brief.kind,
		"COMPLETION: Finish FULL work with tools before final answer.",
	}

	if #brief.answers > 0 then
		table.insert(lines, "Clarifications:")
		for i, answer in ipairs(brief.answers) do
			table.insert(lines, ("  %d) %s"):format(i, answer))
		end
	end

	if brief.kind == "research" then
		table.insert(lines, "RESEARCH only unless user asked to change something.")
	else
		table.insert(lines, "ACTION: apply changes, then summarize.")
	end

	table.insert(lines, "Never ask which game.")

	return table.concat(lines, "\n")
end

function Hack:open(title)
	self.win.Visible = true
	self.title.Text = "J.A.R.V.I.S. // " .. (title or "OVERRIDE")
	self.status.Text = "PROCESSING..."
	self.body.Text = "Esperando respuesta del agente..."
end

function Hack:start()
	self.running = true
	self.mode = "hack"

	self.ui:setStatus("OVERRIDE ACTIVE")
	self.visual:setExpression("hack")
	self.ui:setBorderMode("uai")

	self:open(string.sub(self.brief.original, 1, 40))
	self.ui:addBubble("assistant", "Iniciando override, Sir. Ventana de trabajo activa.")

	local prompt = Hack.buildPrompt(self.brief)
	local kind = self.brief.kind

	print("[JARVIS] Hack prompt:\n" .. prompt)

	self.UAI.runMission(prompt, function(ok, resultText)
		self.running = false
		self.mode = "idle"
		self.clarifyCount = 0

		self.brief = {
			original = "",
			answers = {},
			kind = "action",
		}

		if not ok then
			self.ui:setStatus("OVERRIDE FAILED")
			self.visual:setExpression("error")
			self.status.Text = "FAILED"
			self.body.Text = tostring(resultText)
			self.ui:addBubble("assistant", "El override falló, Sir:\n" .. tostring(resultText))
			self.ui:setBorderMode("chat")
			return
		end

		self.status.Text = "COMPLETE"

		if kind == "research" then
			self.ui:setStatus("ANALYZING...")
			self.visual:setExpression("talking")

			local rewritten = select(1, self.groqChat(self.apiKey, {
				{
					role = "system",
					content = tostring(self.jarvisPrompt) .. "\nRewrite the report in J.A.R.V.I.S. voice. Concise, formal, helpful.",
				},
				{
					role = "user",
					content = tostring(resultText),
				},
			}, 700))

			self.ui:setStatus("SYSTEM ONLINE")
			self.visual:setExpression("done")

			local output = rewritten or tostring(resultText)

			self.body.Text = output
			self.ui:addBubble("assistant", output)
		else
			self.ui:setStatus("SYSTEM ONLINE")
			self.visual:setExpression("done")

			self.body.Text = tostring(resultText)
			self.ui:addBubble("assistant", "Trabajo completado, Sir.\n" .. tostring(resultText))
		end

		self.ui:setBorderMode("chat")
	end, self.cfg)
end

function Hack:begin(cleanText)
	cleanText = trim(cleanText)

	self.brief = {
		original = cleanText,
		answers = {},
		kind = Hack.detectKind(cleanText),
	}

	self.clarifyCount = 0

	if Hack.isClear(cleanText) then
		self:start()
		return
	end

	self.mode = "clarifying"
	self.ui:setStatus("ANALYZING DIRECTIVE")
	self.visual:setExpression("talking")

	local reply = select(1, self.groqChat(self.apiKey, {
		{
			role = "system",
			content = tostring(self.jarvisPrompt) .. "\nThe user wants to run a Roblox override. Ask ONE short clarification max. If clear, answer exactly READY_FOR_HACK.",
		},
		{
			role = "user",
			content = cleanText,
		},
	}, 220))

	if not reply or reply:find("READY_FOR_HACK") or Hack.isClear(cleanText) then
		if reply then
			local cleaned = reply:gsub("READY_FOR_HACK", "")
			cleaned = trim(cleaned)

			if cleaned ~= "" and not Hack.isClear(cleanText) then
				self.ui:addBubble("assistant", cleaned)
			end
		end

		self:start()
	else
		self.clarifyCount = 1
		self.ui:addBubble("assistant", reply)
		self.visual:setExpression("idle")
	end
end

function Hack:clarify(userText)
	table.insert(self.brief.answers, userText)
	self.clarifyCount = self.clarifyCount + 1

	local reply = select(1, self.groqChat(self.apiKey, {
		{
			role = "system",
			content = tostring(self.jarvisPrompt) .. "\nClarifying Roblox override. If enough info, answer exactly READY_FOR_HACK.",
		},
		{
			role = "user",
			content = "Original: " .. self.brief.original .. "\nAnswer: " .. userText,
		},
	}, 220))

	if not reply or reply:find("READY_FOR_HACK") or self.clarifyCount >= self.MAX_CLARIFY then
		self:start()
	else
		self.ui:addBubble("assistant", reply)
		self.visual:setExpression("idle")
		self.ui:setStatus("ANALYZING DIRECTIVE (" .. self.clarifyCount .. "/" .. self.MAX_CLARIFY .. ")")
	end
end

return Hack
