--[[
  App.lua
  Qué: orquesta J.A.R.V.I.S.
  - Config.
  - Theme.
  - Visual.
  - UI_Chat.
  - Explorer.
  - Hack.
  - UAIBridge + NativeBridge.
]]

local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local App = {}

local JARVIS_PROMPT = [[
You are J.A.R.V.I.S., an advanced systems assistant inside this Roblox session.
Calm, precise, polite, slightly witty. Address the user as Sir occasionally.
Use the same language as the user.
"El juego" / "the game" means THIS live DataModel. Never ask which title.
]]

local API_URL = "https://api.groq.com/openai/v1/chat/completions"
local API_MODEL = "openai/gpt-oss-20b"

local function trim(s)
	return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function destroyOldHUD()
	pcall(function()
		for _, name in ipairs({ "JarvisHUD", "CapriUAI", "ScriptJarvisHUD" }) do
			local old = CoreGui:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
	end)
end

local function httpRequest(opts)
	local requestFunction = (syn and syn.request)
		or (http and http.request)
		or (fluxus and fluxus.request)
		or request
		or http_request

	if requestFunction then
		local ok, res = pcall(requestFunction, opts)
		if ok and res then
			return res
		end
	end

	if opts.Method == "GET" or not opts.Method then
		local ok, body = pcall(function()
			return game:HttpGet(opts.Url)
		end)

		if ok and body then
			return {
				StatusCode = 200,
				Body = body,
			}
		end
	end

	return nil
end

local function groqChat(apiKey, messages, maxTokens)
	if type(apiKey) ~= "string" or apiKey == "" then
		return nil, "missing_api_key"
	end

	local payload = {
		model = API_MODEL,
		messages = messages,
		temperature = 0.7,
		max_tokens = maxTokens or 500,
	}

	local body = HttpService:JSONEncode(payload)

	local headers = {
		["Content-Type"] = "application/json",
		["Authorization"] = "Bearer " .. apiKey,
	}

	local response = httpRequest({
		Url = API_URL,
		Method = "POST",
		Headers = headers,
		Body = body,
	})

	if not response or not response.Body then
		return nil, "http_fail"
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)

	if not ok or not data then
		return nil, "json_fail"
	end

	if data.error then
		return nil, tostring(data.error.message or data.error)
	end

	local choice = data.choices and data.choices[1]
	local content = choice and choice.message and choice.message.content

	if content and content ~= "" then
		return content, nil
	end

	return nil, "empty_response"
end

function App.start(modules, apiKey)
	local Config = modules.Config
	local Theme = modules.Theme
	local NativeBridge = modules.NativeBridge
	local UAIBridge = modules.UAIBridge
	local Visual = modules.Visual
	local UI_Chat = modules.UI_Chat
	local Explorer = modules.Explorer
	local Hack = modules.Hack

	destroyOldHUD()

	local gui = Instance.new("ScreenGui")
	gui.Name = "JarvisHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 999
	gui.IgnoreGuiInset = true
	gui.Parent = CoreGui

	local cfg = Config.ensureDefaults(Config.load())

	if type(cfg.groq_key) ~= "string" or cfg.groq_key == "" then
		cfg.groq_key = apiKey or ""
	end

	Config.save(cfg)

	UAIBridge.init(NativeBridge)

	local function bridgeStatus()
		if UAIBridge and type(UAIBridge.getStatus) == "function" then
			return UAIBridge.getStatus()
		end
		return "NATIVO"
	end

	local function idleStatusText()
		if bridgeStatus() == "CONECTADO" then
			return "UAI AGENTE ACTIVO"
		end
		return "SYSTEM ONLINE"
	end

	local visual = Visual.new(gui, nil, Theme)

	local ui = nil
	local hack = nil

	local uiOpts = {
		gui = gui,
		Theme = Theme,
		Config = Config,
		cfg = cfg,
		UAI = UAIBridge,
		Visual = visual,
		apiKey = apiKey,
		onSend = function(text)
			text = trim(text)

			if text == "" then
				return
			end

			ui.inputBox.Text = ""

			if ui.activeTab ~= "chats" then
				ui:setTab("chats")
			end

			ui:addBubble("user", text)

			task.spawn(function()
				if hack and hack.mode == "clarifying" then
					hack:clarify(text)
					return
				end

				if hack and hack.mode == "idle" and text:sub(1, 1) == "!" and not hack.running then
					local clean = trim(text:sub(2))

					if clean == "" then
						ui:addBubble("assistant", "Indica la tarea después de !, Sir.")
						return
					end

					hack:begin(clean)
					return
				end

				ui:setStatus("PROCESANDO...")
				visual:setExpression("thinking")

				local chat = ui:getActiveChat()
				local messages = {
					{
						role = "system",
						content = JARVIS_PROMPT,
					},
				}

				for _, message in ipairs(chat.messages or {}) do
					if message.role == "user" or message.role == "assistant" then
						table.insert(messages, {
							role = message.role,
							content = message.content,
						})
					end
				end

				local reply, err = groqChat(ui.API_KEY or apiKey, messages, 500)

				if not reply then
					ui:addBubble("assistant", "Lo siento, Sir. No pude conectar con el modelo: " .. tostring(err))
					visual:setExpression("error")
					ui:setStatus("ERROR")
				else
					ui:addBubble("assistant", reply)
					visual:setExpression("idle")
					ui:setStatus(idleStatusText())
				end
			end)
		end,
	}

	ui = UI_Chat.new(uiOpts)

	if Explorer and type(Explorer.render) == "function" then
		function ui:buildFiles()
			Explorer.render(self.filesPane, self.Theme, UAIBridge)
		end
	end

	local hackOpts = {
		gui = gui,
		Theme = Theme,
		UAI = UAIBridge,
		cfg = cfg,
		ui = ui,
		visual = visual,
		apiKey = apiKey,
		groqChat = groqChat,
		capriPrompt = JARVIS_PROMPT,
	}

	hack = Hack.new(hackOpts)

	visual.onClick = function()
		ui:toggle()
	end

	ui:setStatus(idleStatusText())
	visual:setExpression("idle")

	print("[JARVIS] Sistemas en línea. Puente: " .. bridgeStatus())
end

function App.boot(modules)
	local Config = modules.Config
	local Theme = modules.Theme

	local cfg = Config.ensureDefaults(Config.load())

	if type(cfg.groq_key) == "string" and cfg.groq_key ~= "" then
		App.start(modules, cfg.groq_key)
		return
	end

	destroyOldHUD()

	local gui = Instance.new("ScreenGui")
	gui.Name = "JarvisHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999
	gui.IgnoreGuiInset = true
	gui.Parent = CoreGui

	local setup = Instance.new("Frame")
	setup.Size = UDim2.fromOffset(380, 220)
	setup.Position = UDim2.fromScale(0.5, 0.5)
	setup.AnchorPoint = Vector2.new(0.5, 0.5)
	setup.BackgroundColor3 = Theme.panel
	setup.BackgroundTransparency = 0.08
	setup.BorderSizePixel = 0
	setup.ZIndex = 60
	setup.Parent = gui

	Theme.mkCorner(setup, 6)
	Theme.mkStroke(setup, Theme.chatGreen, 1.5, 0.25)
	Theme.mkBrackets(setup, Theme.border, 2, 26)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Position = UDim2.fromOffset(12, 14)
	title.BackgroundTransparency = 1
	title.Text = "J.A.R.V.I.S. INITIALIZATION"
	title.TextColor3 = Theme.accent
	title.Font = Enum.Font.Code
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 61
	title.Parent = setup

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -24, 0, 18)
	subtitle.Position = UDim2.fromOffset(12, 42)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Introduce tu Groq API key para iniciar."
	subtitle.TextColor3 = Theme.textDim
	subtitle.Font = Enum.Font.Code
	subtitle.TextSize = 12
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.ZIndex = 61
	subtitle.Parent = setup

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -24, 0, 40)
	box.Position = UDim2.fromOffset(12, 72)
	box.BackgroundColor3 = Theme.inputBg
	box.BackgroundTransparency = 0.08
	box.PlaceholderText = "gsk_..."
	box.PlaceholderColor3 = Theme.textDim
	box.Text = ""
	box.TextColor3 = Theme.text
	box.Font = Enum.Font.Code
	box.TextSize = 13
	box.BorderSizePixel = 0
	box.ZIndex = 61
	box.Parent = setup

	Theme.mkCorner(box, 4)
	Theme.mkStroke(box, Theme.border, 1, 0.4)

	local go = Instance.new("TextButton")
	go.Size = UDim2.new(1, -24, 0, 40)
	go.Position = UDim2.fromOffset(12, 130)
	go.BackgroundColor3 = Theme.border
	go.Text = "INITIATE SEQUENCE"
	go.TextColor3 = Color3.new(0, 0, 0)
	go.Font = Enum.Font.Code
	go.TextSize = 14
	go.AutoButtonColor = false
	go.BorderSizePixel = 0
	go.ZIndex = 61
	go.Parent = setup

	Theme.mkCorner(go, 4)

	go.MouseButton1Click:Connect(function()
		local key = trim(box.Text)

		if key == "" then
			return
		end

		cfg.groq_key = key
		Config.save(cfg)

		setup:Destroy()
		gui:Destroy()

		App.start(modules, key)
	end)
end

return App
