--[[
  Config.lua
  Qué: guarda y carga configuración local de J.A.R.V.I.S.
  - Usa writefile/readfile si el executor lo permite.
  - Si no, usa memoria/shared como fallback.
]]

local HttpService = game:GetService("HttpService")

local Config = {}

local FILE_NAME = "jarvis_config.json"
local memory = {}

local function safeDecode(content)
	if type(content) ~= "string" or content == "" then
		return nil
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(content)
	end)

	if ok and type(decoded) == "table" then
		return decoded
	end

	return nil
end

function Config.load()
	local data = nil

	if type(readfile) == "function" then
		local ok, content = pcall(readfile, FILE_NAME)
		if ok then
			data = safeDecode(content)
		end
	end

	if not data and shared and type(shared.__jarvis_config) == "table" then
		data = shared.__jarvis_config
	end

	if not data and type(memory.last) == "table" then
		data = memory.last
	end

	return data or {}
end

function Config.save(cfg)
	if type(cfg) ~= "table" then
		return
	end

	memory.last = cfg

	if shared then
		pcall(function()
			shared.__jarvis_config = cfg
		end)
	end

	if type(writefile) == "function" then
		pcall(function()
			writefile(FILE_NAME, HttpService:JSONEncode(cfg))
		end)
	end
end

function Config.ensureDefaults(cfg)
	cfg = type(cfg) == "table" and cfg or {}

	if type(cfg.groq_key) ~= "string" then
		cfg.groq_key = ""
	end

	if type(cfg.provider_keys) ~= "table" then
		cfg.provider_keys = {}
	end

	if type(cfg.chats) ~= "table" then
		cfg.chats = {}
	end

	if #cfg.chats == 0 then
		local id = HttpService:GenerateGUID(false)
		table.insert(cfg.chats, {
			id = id,
			title = "Sesión inicial",
			messages = {},
		})
		cfg.active_chat = id
	end

	for _, chat in ipairs(cfg.chats) do
		if type(chat.messages) ~= "table" then
			chat.messages = {}
		end

		if type(chat.title) ~= "string" or chat.title == "" then
			chat.title = "Chat"
		end
	end

	local activeValid = false
	for _, chat in ipairs(cfg.chats) do
		if chat.id == cfg.active_chat then
			activeValid = true
			break
		end
	end

	if not activeValid then
		cfg.active_chat = cfg.chats[1].id
	end

	return cfg
end

return Config
