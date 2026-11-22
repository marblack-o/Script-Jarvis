--[[
  UAIBridge.lua
  Qué: puente inteligente hacia Project UAI.
  - Busca UAI en el entorno del executor/juego.
  - Si lo encuentra, lo usa como agente.
  - Si no lo encuentra, delega a NativeBridge.
  No descarga scripts externos.
]]

local UAIBridge = {}

local _uai = nil
local _native = nil
local _connected = false
local _status = "BUSCANDO"

local function log(message)
	print("[UAIBridge] " .. tostring(message))
end

local function tryFindUAI()
	local candidates = {
		function()
			return _G.UAI
		end,
		function()
			return _G.ProjectUAI
		end,
		function()
			if type(getgenv) == "function" then
				return getgenv().UAI
			end
			return nil
		end,
		function()
			if type(getgenv) == "function" then
				return getgenv().ProjectUAI
			end
			return nil
		end,
		function()
			return shared.UAI
		end,
		function()
			return shared.ProjectUAI
		end,
		function()
			return UAI
		end,
		function()
			return ProjectUAI
		end,
	}

	for _, getter in ipairs(candidates) do
		local ok, value = pcall(getter)
		if ok and value ~= nil then
			return value
		end
	end

	local executorUAI = nil
	pcall(function()
		if type(getuai) == "function" then
			executorUAI = getuai()
		end
	end)

	if executorUAI ~= nil then
		return executorUAI
	end

	local function searchIn(parent)
		if not parent then
			return nil
		end

		local names = { "UAI", "ProjectUAI", "UAI_Core", "UAI_Agent" }

		for _, name in ipairs(names) do
			local ok, obj = pcall(function()
				return parent:FindFirstChild(name, true)
			end)

			if ok and obj and obj:IsA("ModuleScript") then
				local ok2, mod = pcall(function()
					return require(obj)
				end)

				if ok2 and mod then
					return mod
				end
			end
		end

		return nil
	end

	local found = nil

	pcall(function()
		found = searchIn(game:GetService("CoreGui"))
	end)

	if found then
		return found
	end

	pcall(function()
		found = searchIn(game:GetService("ReplicatedStorage"))
	end)

	if found then
		return found
	end

	return nil
end

local function validateUAI(uai)
	if type(uai) ~= "table" then
		return false, "UAI no es una tabla válida."
	end

	if type(uai.runMission) == "function" then
		return true, "OK"
	end

	if type(uai.execute) == "function" then
		return true, "OK via execute adapter"
	end

	return false, "Falta runMission/execute en UAI."
end

local function adaptUAI(uai)
	if type(uai.runMission) == "function" then
		return uai
	end

	local adapter = {}

	for k, v in pairs(uai) do
		adapter[k] = v
	end

	if type(uai.execute) == "function" then
		function adapter.runMission(prompt, callback, cfg)
			return uai.execute(prompt, callback, cfg)
		end
	end

	if type(adapter.ensure) ~= "function" then
		function adapter.ensure()
			return true
		end
	end

	return adapter
end

function UAIBridge.init(NativeBridgeModule)
	_native = NativeBridgeModule
	_status = "BUSCANDO"

	log("Inicializando puente...")

	local found = tryFindUAI()

	if found then
		local valid, message = validateUAI(found)
		if valid then
			_uai = adaptUAI(found)
			_connected = true
			_status = "CONECTADO"
			log("UAI conectado. Agente activo.")
		else
			_uai = nil
			_connected = false
			_status = "NATIVO"
			log("UAI encontrado pero incompatible: " .. tostring(message))
		end
	else
		_uai = nil
		_connected = false
		_status = "NATIVO"
		log("UAI no encontrado. Usando NativeBridge.")
	end

	return _connected
end

function UAIBridge.ensure(force)
	if _connected and _uai then
		local ok = pcall(function()
			if type(_uai.ensure) == "function" then
				_uai.ensure(force)
			end
		end)

		if ok then
			return true
		end

		log("UAI dejó de responder. Cambiando a modo nativo.")
		_connected = false
		_status = "NATIVO"
	end

	if force then
		local found = tryFindUAI()
		if found then
			local valid = validateUAI(found)
			if valid then
				_uai = adaptUAI(found)
				_connected = true
				_status = "CONECTADO"
				return true
			end
		end
	end

	return false
end

function UAIBridge.runMission(prompt, callback, cfg)
	if _connected and _uai and type(_uai.runMission) == "function" then
		local ok, err = pcall(function()
			_uai.runMission(prompt, callback, cfg)
		end)

		if ok then
			return
		end

		log("UAI.runMission falló: " .. tostring(err) .. ". Usando NativeBridge.")
	end

	if _native and type(_native.runMission) == "function" then
		_native.runMission(prompt, callback, cfg)
		return
	end

	if type(callback) == "function" then
		callback(false, "No hay agente disponible: UAI no conectado y NativeBridge no inicializado.")
	end
end

function UAIBridge.show(section)
	if _connected and _uai and type(_uai.show) == "function" then
		local ok, result = pcall(function()
			return _uai.show(section)
		end)

		if ok then
			return true, result
		end

		return false, "UAI.show falló."
	end

	return false, "UAI no conectado."
end

function UAIBridge.injectProvider(provider, key)
	if _connected and _uai and type(_uai.injectProvider) == "function" then
		local ok, result = pcall(function()
			return _uai.injectProvider(provider, key)
		end)

		if ok then
			return true, result
		end

		return false, "UAI.injectProvider falló."
	end

	return true, "Guardado localmente. UAI no conectado."
end

function UAIBridge.getStatus()
	return _status
end

function UAIBridge.isConnected()
	return _connected
end

UAIBridge.sessions = {
	open = function(...)
		if _connected and _uai and _uai.sessions and type(_uai.sessions.open) == "function" then
			return pcall(_uai.sessions.open, ...)
		end
		return true
	end,
	request = function(...)
		if _connected and _uai and _uai.sessions and type(_uai.sessions.request) == "function" then
			return pcall(_uai.sessions.request, ...)
		end
		return true
	end,
}

return UAIBridge
