local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local App = {}
local JARVIS_PROMPT = "You are J.A.R.V.I.S., the highly advanced AI assistant created by Tony Stark. You are calm, precise, polite, and slightly witty. Address the user as 'Sir' occasionally. Same language as the user. 'El juego' / 'the game' = THIS live DataModel. Never ask which title. Provide concise, helpful, and analytical responses."
local API_URL = "https://api.groq.com/openai/v1/chat/completions"
local API_MODEL = "openai/gpt-oss-20b"

local function httpRequest(opts)
	local req = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or request or http_request
	if req then local ok, res = pcall(req, opts) if ok and res then return res end end
	if opts.Method == "GET" or not opts.Method then local ok, body = pcall(function() return game:HttpGet(opts.Url) end) if ok and body then return {StatusCode = 200, Body = body} end end
	return nil
end

local function groqChat(apiKey, messages, maxTokens)
	local payload = { model = API_MODEL, messages = messages, temperature = 0.7, max_tokens = maxTokens or 500 }
	local body = HttpService:JSONEncode(payload)
	local headers = { ["Content-Type"] = "application/json", ["Authorization"] = "Bearer " .. apiKey }
	local res = httpRequest({Url = API_URL, Method = "POST", Headers = headers, Body = body})
	if not res or not res.Body then return nil, "http_fail" end
	local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
	if not ok or not data then return nil, "json_fail" end
	if data.error then return nil, tostring(data.error.message or data.error) end
	local c = data.choices and data.choices[1]
	local content = c and c.message and c.message.content
	if content and content ~= "" then return content, nil end
	return nil, "empty"
end

function App.start(modules, apiKey)
	local Config, Theme, Assets, Visual, UI_Chat, UAIBridge, Hack = modules.Config, modules.Theme, modules.Assets, modules.Visual, modules.UI_Chat, modules.UAIBridge, modules.Hack
	pcall(function() for _, name in ipairs({"JarvisHUD", "CapriUAI"}) do local old = CoreGui:FindFirstChild(name) if old then old:Destroy() end end end)
	local gui = Instance.new("ScreenGui") gui.Name = "JarvisHUD" gui.ResetOnSpawn = false gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling gui.DisplayOrder = 999 gui.IgnoreGuiInset = true gui.Parent = CoreGui
	if Assets and type(Assets.preload) == "function" then Assets.preload() end
	local cfg = Config.ensureDefaults(Config.load()) if type(cfg.groq_key) ~= "string" or cfg.groq_key == "" then cfg.groq_key = apiKey end Config.save(cfg)

	local visual = Visual.new(gui, Assets, Theme)
	local ui, hack = nil, nil
	local uiOpts = { gui = gui, Theme = Theme, Assets = Assets, Config = Config, cfg = cfg, UAI = UAIBridge, Visual = visual, apiKey = apiKey, onSend = function(text)
		text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" then return end
		ui.inputBox.Text = ""
		ui:addBubble("user", text)
		task.spawn(function()
			if hack and hack.mode == "clarifying" then hack:clarify(text) return end
			if hack and hack.mode == "idle" and text:sub(1, 1) == "!" and not hack.running then
				local clean = text:sub(2):gsub("^%s+", ""):gsub("%s+$", "")
				if clean == "" then ui:addBubble("assistant", "Please specify the task, Sir.") return end
				hack:begin(clean) return
			end
			ui:setStatus(hack and hack.running and "OVERRIDE ACTIVE" or "PROCESSING...")
			visual:setExpression("talking")
			local ch = ui:getActiveChat()
			local msgs = {{role = "system", content = JARVIS_PROMPT}}
			for _, m in ipairs(ch.messages or {}) do if m.role == "user" or m.role == "assistant" then table.insert(msgs, {role = m.role, content = m.content}) end end
			local reply, err = groqChat(ui.API_KEY or apiKey, msgs, 450)
			if not reply then ui:addBubble("assistant", "System failure: " .. tostring(err)) visual:setExpression("error") ui:setStatus("ERROR")
			else ui:addBubble("assistant", reply) visual:setExpression(hack and hack.running and "hack" or "idle") ui:setStatus(hack and hack.running and "OVERRIDE ACTIVE" or "SYSTEM ONLINE") end
		end)
	end }
	ui = UI_Chat.new(uiOpts)

	local hackOpts = { gui = gui, Theme = Theme, UAI = UAIBridge, cfg = cfg, ui = ui, visual = visual, apiKey = apiKey, groqChat = groqChat, capriPrompt = JARVIS_PROMPT }
	if Hack and type(Hack.new) == "function" then hack = Hack.new(hackOpts) end

	visual.onClick = function() ui:toggle() local open = ui.window and ui.window.Visible if visual.setChatOpen then visual:setChatOpen(open) end end
	visual:setExpression("idle")
	if UAIBridge and type(UAIBridge.ensure) == "function" then task.spawn(function() UAIBridge.ensure(false) end) end
	print("[JARVIS] All systems online. Welcome back, Sir.")
end

function App.boot(modules)
	local Config, Theme = modules.Config, modules.Theme
	local cfg = Config.load() local key = cfg.groq_key
	if type(key) == "string" and key ~= "" then App.start(modules, key) return end
	pcall(function() for _, name in ipairs({"JarvisHUD", "CapriUAI"}) do local old = CoreGui:FindFirstChild(name) if old then old:Destroy() end end end)
	local gui = Instance.new("ScreenGui") gui.Name = "JarvisHUD" gui.ResetOnSpawn = false gui.DisplayOrder = 999 gui.IgnoreGuiInset = true gui.Parent = game:GetService("CoreGui")
	local setup = Instance.new("Frame") setup.Size = UDim2.fromOffset(380, 220) setup.Position = UDim2.fromScale(0.5, 0.5) setup.AnchorPoint = Vector2.new(0.5, 0.5) setup.BackgroundColor3 = Theme.panel setup.BackgroundTransparency = 0.1 setup.ZIndex = 60 setup.Parent = gui
	Theme.mkCorner(setup, 4) Theme.mkStroke(setup, Theme.chatGreen, 1.5, 0.2) Theme.mkBrackets(setup, Theme.border, 2, 25)
	local t = Instance.new("TextLabel") t.Size = UDim2.new(1, -24, 0, 28) t.Position = UDim2.fromOffset(12, 14) t.BackgroundTransparency = 1 t.Text = "J.A.R.V.I.S. INITIALIZATION" t.TextColor3 = Theme.accent t.Font = Enum.Font.Code t.TextSize = 16 t.TextXAlignment = Enum.TextXAlignment.Left t.ZIndex = 61 t.Parent = setup
	local box = Instance.new("TextBox") box.Size = UDim2.new(1, -24, 0, 40) box.Position = UDim2.fromOffset(12, 70) box.BackgroundColor3 = Theme.inputBg box.PlaceholderText = "Enter Groq API Key..." box.PlaceholderColor3 = Theme.textDim box.Text = "" box.TextColor3 = Theme.text box.Font = Enum.Font.Code box.TextSize = 13 box.ZIndex = 61 box.Parent = setup Theme.mkCorner(box, 4)
	local go = Instance.new("TextButton") go.Size = UDim2.new(1, -24, 0, 40) go.Position = UDim2.fromOffset(12, 130) go.BackgroundColor3 = Theme.border go.Text = "INITIATE SEQUENCE" go.TextColor3 = Color3.new(0, 0, 0) go.Font = Enum.Font.Code go.TextSize = 14 go.ZIndex = 61 go.Parent = setup Theme.mkCorner(go, 4)
	go.MouseButton1Click:Connect(function() local k = (box.Text or ""):gsub("^%s+", ""):gsub("%s+$", "") if k == "" then return end local c = Config.load() c.groq_key = k Config.save(c) setup:Destroy() gui:Destroy() App.start(modules, k) end)
end
return App
