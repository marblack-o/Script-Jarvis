local UserInputService = game:GetService("UserInputService")
local Hack = {}
Hack.__index = Hack

local function makeDraggable(frame, handle)
	local dragging, start, startPos
	handle.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging, start, startPos = true, i.Position, frame.Position end end)
	handle.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
	UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + (i.Position - start).X, startPos.Y.Scale, startPos.Y.Offset + (i.Position - start).Y) end end)
end

function Hack.new(opts)
	local self = setmetatable({}, Hack)
	self.gui, self.Theme, self.UAI, self.cfg = opts.gui, opts.Theme, opts.UAI, opts.cfg
	self.ui, self.visual, self.apiKey = opts.ui, opts.visual, opts.apiKey
	self.groqChat, self.capriPrompt = opts.groqChat, opts.capriPrompt
	self.running, self.mode, self.clarifyCount = false, "idle", 0
	self.brief = { original = "", answers = {}, kind = "action" }
	self.MAX_CLARIFY = 4
	self:_build()
	return self
end

function Hack:_build()
	local Theme = self.Theme
	local win = Instance.new("Frame") win.Size = UDim2.fromOffset(380, 240) win.Position = UDim2.new(1, -400, 1, -260) win.BackgroundColor3 = Theme.panel win.BackgroundTransparency = 0.1 win.Visible = false win.ZIndex = 40 win.Parent = self.gui
	Theme.mkCorner(win, 4) Theme.mkStroke(win, Theme.uaiYellow, 1.5, 0.1) Theme.mkBrackets(win, Theme.uaiYellow, 2, 25) self.win = win
	local bar = Instance.new("Frame") bar.Size = UDim2.new(1, 0, 0, 32) bar.BackgroundColor3 = Theme.sidebar bar.BackgroundTransparency = 0.15 bar.ZIndex = 41 bar.Parent = win makeDraggable(win, bar)
	self.title = Instance.new("TextLabel") self.title.Size = UDim2.new(1, -40, 1, 0) self.title.Position = UDim2.fromOffset(10, 0) self.title.BackgroundTransparency = 1 self.title.Text = "J.A.R.V.I.S. // OVERRIDE" self.title.TextColor3 = Theme.uaiYellow self.title.Font = Enum.Font.Code self.title.TextSize = 14 self.title.TextXAlignment = Enum.TextXAlignment.Left self.title.ZIndex = 42 self.title.Parent = bar
	local close = Instance.new("TextButton") close.Size = UDim2.fromOffset(24, 24) close.Position = UDim2.new(1, -32, 0.5, -12) close.BackgroundColor3 = Color3.fromRGB(255, 50, 50) close.Text = "X" close.TextColor3 = Color3.new(1, 1, 1) close.Font = Enum.Font.Code close.TextSize = 14 close.AutoButtonColor = false close.ZIndex = 43 close.Parent = bar Theme.mkCorner(close, 2) close.MouseButton1Click:Connect(function() win.Visible = false end)
	self.status = Instance.new("TextLabel") self.status.Size = UDim2.new(1, -20, 0, 18) self.status.Position = UDim2.fromOffset(10, 38) self.status.BackgroundTransparency = 1 self.status.Text = "AWAITING DIRECTIVE" self.status.TextColor3 = Theme.textDim self.status.Font = Enum.Font.Code self.status.TextSize = 12 self.status.TextXAlignment = Enum.TextXAlignment.Left self.status.ZIndex = 41 self.status.Parent = win
	self.body = Instance.new("TextLabel") self.body.Size = UDim2.new(1, -20, 1, -66) self.body.Position = UDim2.fromOffset(10, 58) self.body.BackgroundTransparency = 1 self.body.Text = "" self.body.TextColor3 = Theme.text self.body.Font = Enum.Font.Code self.body.TextSize = 12 self.body.TextWrapped = true self.body.TextXAlignment = Enum.TextXAlignment.Left self.body.TextYAlignment = Enum.TextYAlignment.Top self.body.ZIndex = 41 self.body.Parent = win
end

function Hack.detectKind(text) local l = string.lower(text) if l:find("investiga") or l:find("busca") or l:find("analiza") or l:find("explora") or l:find("lista") or l:find("scan") then return "research" end return "action" end
function Hack.isClear(text) local l = string.lower(text) local about = l:find("el juego") or l:find("este juego") or l:find("the game") or l:find("workspace") or l:find("scripts") local verb = l:find("analiza") or l:find("explora") or l:find("lista") or l:find("crea") or l:find("haz") or l:find("hack") if verb and about then return true end if #l < 48 and (l:find("analiza") or l:find("explora")) then return true end return false end

function Hack.buildPrompt(brief)
	local placeName = "unknown" pcall(function() placeName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
	local lines = { "JARVIS OVERRIDE DIRECTIVE (Roblox executor host)", "Live DataModel only. PlaceId=" .. tostring(game.PlaceId) .. " name=" .. tostring(placeName), "User request: " .. brief.original, "Job type: " .. brief.kind, "COMPLETION: Finish FULL work with tools before final answer." }
	if #brief.answers > 0 then table.insert(lines, "Clarifications:") for i, a in ipairs(brief.answers) do table.insert(lines, ("  %d) %s"):format(i, a)) end end
	if brief.kind == "research" then table.insert(lines, "RESEARCH only unless user asked to change something.") else table.insert(lines, "ACTION: apply changes, then summarize.") end
	table.insert(lines, "Never ask which game.") return table.concat(lines, "\n")
end

function Hack:open(title) self.win.Visible = true self.title.Text = "J.A.R.V.I.S. // " .. (title or "OVERRIDE") self.status.Text = "PROCESSING..." self.body.Text = "Awaiting UAI completion sequence..." end
function Hack:start()
	self.running, self.mode = true, "hack"
	self.ui:setStatus("OVERRIDE ACTIVE") self.visual:setExpression("hack") self.ui:setBorderMode("uai")
	self:open(string.sub(self.brief.original, 1, 40)) self.ui:addBubble("assistant", "Initiating system override, Sir. Directive window active.")
	local prompt = Hack.buildPrompt(self.brief) local kind = self.brief.kind print("[JARVIS] Hack:\n" .. prompt)
	self.UAI.runMission(prompt, function(ok, resultText)
		self.running, self.mode, self.clarifyCount = false, "idle", 0 self.brief = { original = "", answers = {}, kind = "action" }
		if not ok then self.ui:setStatus("OVERRIDE FAILED") self.visual:setExpression("error") self.status.Text = "FAILED" self.body.Text = tostring(resultText) self.ui:addBubble("assistant", "The hack has failed, Sir:\n" .. tostring(resultText)) self.ui:setBorderMode("chat") return end
		self.status.Text = "COMPLETE"
		if kind == "research" then self.ui:setStatus("ANALYZING...") self.visual:setExpression("talking")
			local rewritten = select(1, self.groqChat(self.apiKey, { { role = "system", content = self.capriPrompt .. "\nRetell report in JARVIS voice. Concise." }, { role = "user", content = tostring(resultText) } }, 700))
			self.ui:setStatus("SYSTEM ONLINE") self.visual:setExpression("done") local out = rewritten or tostring(resultText) self.body.Text = out self.ui:addBubble("assistant", out)
		else self.ui:setStatus("SYSTEM ONLINE") self.visual:setExpression("done") self.body.Text = tostring(resultText) self.ui:addBubble("assistant", "Task complete, Sir.\n" .. tostring(resultText)) end
		self.ui:setBorderMode("chat")
	end, self.cfg)
end

function Hack:begin(cleanText)
	self.brief = { original = cleanText, answers = {}, kind = Hack.detectKind(cleanText) } self.clarifyCount = 0
	if Hack.isClear(cleanText) then self:start() return end
	self.mode = "clarifying" self.ui:setStatus("ANALYZING DIRECTIVE") self.visual:setExpression("talking")
	local reply = select(1, self.groqChat(self.apiKey, { { role = "system", content = self.capriPrompt .. "\n!hack in THIS Roblox game. ONE question max. Never ask which game. If clear: READY_FOR_HACK" }, { role = "user", content = cleanText } }, 220))
	if not reply or reply:find("READY_FOR_HACK") or Hack.isClear(cleanText) then if reply then local s = reply:gsub("READY_FOR_HACK", ""):gsub("^%s+", ""):gsub("%s+$", "") if s ~= "" and not Hack.isClear(cleanText) then self.ui:addBubble("assistant", s) end end self:start()
	else self.clarifyCount = 1 self.ui:addBubble("assistant", reply) self.visual:setExpression("idle") end
end

function Hack:clarify(userText)
	table.insert(self.brief.answers, userText) self.clarifyCount = self.clarifyCount + 1
	local reply = select(1, self.groqChat(self.apiKey, { { role = "system", content = self.capriPrompt .. "\nClarifying hack THIS game. READY_FOR_HACK if enough." }, { role = "user", content = "Original: " .. self.brief.original .. "\nAnswer: " .. userText } }, 220))
	if not reply or reply:find("READY_FOR_HACK") or self.clarifyCount >= self.MAX_CLARIFY then self:start()
	else self.ui:addBubble("assistant", reply) self.visual:setExpression("idle") self.ui:setStatus("ANALYZING DIRECTIVE (" .. self.clarifyCount .. "/" .. self.MAX_CLARIFY .. ")") end
end
return Hack
