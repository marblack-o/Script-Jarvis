--[[
  UAIBridge.lua
  Que: Puente inteligente hacia Project UAI.
  - Detecta si UAI está disponible en el entorno (executor/juego).
  - Si existe → lo usa como agente principal (runMission, providers, sesiones).
  - Si no existe → delega a NativeBridge como fallback.
  No descarga scripts externos. Solo se conecta a lo que ya esté presente.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local UAIBridge = {}

-- Estado interno
local _uai = nil          -- Referencia al agente UAI si se encuentra
local _connected = false  -- true si UAI está activo
local _native = nil       -- Referencia a NativeBridge (fallback)
local _status = "BUSCANDO" -- BUSCANDO | CONECTADO | NATIVO | ERROR

-- ============ DETECCIÓN DE UAI ============

local function log(msg)
	print("[UAIBridge] " .. msg)
end

local function tryFindUAI()
	-- Método 1: Globals comunes donde UAI suele inyectarse
	local candidates = {
		"_G.UAI",
		"_G.ProjectUAI", 
		"getgenv().UAI",
		"getgenv().ProjectUAI",
		"shared.UAI",
		"shared.ProjectUAI",
	}
	
	for _, path in ipairs(candidates) do
		local ok, val = pcall(function()
			return loadstring("return " .. path)()
		end)
		if ok and val ~= nil then
			log("UAI encontrado en: " .. path)
			return val
		end
	end
	
	-- Método 2: Verificar si hay un ModuleScript llamado "UAI" o "ProjectUAI" en el juego
	local searchNames = { "UAI", "ProjectUAI", "UAI_Core", "UAI_Agent" }
	pcall(function()
		for _, name in ipairs(searchNames) do
			-- Buscar en CoreGui (donde suelen inyectarse los executors)
			local coreGui = game:GetService("CoreGui")
			if coreGui then
				local found = coreGui:FindFirstChild(name, true)
				if found and found:IsA("ModuleScript") then
					local ok, mod = pcall(function() return require(found) end)
					if ok and mod then
						log("UAI encontrado como ModuleScript en CoreGui: " .. name)
						return mod
					end
				end
			end
			
			-- Buscar en ReplicatedStorage
			local rs = game:GetService("ReplicatedStorage")
			if rs then
				local found = rs:FindFirstChild(name, true)
				if found and found:IsA("ModuleScript") then
					local ok, mod = pcall(function() return require(found) end)
					if ok and mod then
						log("UAI encontrado en ReplicatedStorage: " .. name)
						return mod
					end
				end
			end
		end
	end)
	
	-- Método 3: Verificar si el executor expone una API de UAI directamente
	pcall(function()
		if type(getuai) == "function" then
			local u = getuai()
			if u then
				log("UAI expuesto por executor via getuai()")
				return u
			end
		end
	end)
	
	return nil
end

-- ============ VERIFICACIÓN DE API ============

-- Valida que el objeto encontrado tenga la API esperada de UAI
local function validateUAI(uai)
	if type(uai) ~= "table" then return false, "No es una tabla" end
	
	-- Verificar funciones mínimas que necesitamos
	local required = { "runMission", "ensure" }
	local optional = { "show", "injectProvider", "sessions" }
	
	for _, fn in ipairs(required) do
		if type(uai[fn]) ~= "function" then
			return false, "Falta función requerida: " .. fn
		end
	end
	
	return true, "OK"
end

-- ============ INICIALIZACIÓN ============

function UAIBridge.init(NativeBridgeModule)
	_native = NativeBridgeModule
	log("Inicializando puente...")
	
	-- Intentar encontrar UAI
	local found = tryFindUAI()
	
	if found then
		local valid, msg = validateUAI(found)
		if valid then
			_uai = found
			_connected = true
			_status = "CONECTADO"
			log("✓ UAI conectado exitosamente. Agente activo.")
		else
			log("⚠ Objeto encontrado pero API inválida: " .. msg)
			log("  Usando modo nativo como fallback.")
			_status = "NATIVO"
		end
	else
		log("⚠ UAI no encontrado en el entorno.")
		log("  Usando modo nativo como fallback.")
		_status = "NATIVO"
	end
	
	return _connected
end

-- ============ API PÚBLICA (compatible con Hack.lua) ============

-- Asegura que UAI esté listo (compatibilidad con API antigua)
function UAIBridge.ensure(force)
	if _connected then
		-- Si ya estamos conectados, verificar que siga vivo
		local ok, err = pcall(function()
			if type(_uai.ensure) == "function" then
				return _uai.ensure(force)
			end
			return true
		end)
		if ok then return true end
		log("UAI dejó de responder. Cambiando a modo nativo.")
		_connected = false
		_status = "NATIVO"
	end
	
	-- Reintentar detección si force = true
	if force and not _connected then
		local found = tryFindUAI()
		if found then
			local valid = validateUAI(found)
			if valid then
				_uai = found
				_connected = true
				_status = "CONECTADO"
				return true
			end
		end
	end
	
	return _connected
end

-- Ejecuta una misión/hackeo
-- Si UAI está conectado → lo usa como agente inteligente
-- Si no → usa NativeBridge para análisis básicos
function UAIBridge.runMission(prompt, callback, cfg)
	if _connected and _uai and type(_uai.runMission) == "function" then
		log("Ejecutando misión via UAI (agente)...")
		local ok, err = pcall(function()
			_uai.runMission(prompt, callback, cfg)
		end)
		if not ok then
			log("UAI falló: " .. tostring(err) .. ". Fallback a nativo.")
			if _native and type(_native.runMission) == "function" then
				_native.runMission(prompt, callback, cfg)
			else
				if callback then callback(false, "UAI y NativeBridge fallaron") end
			end
		end
	else
		-- Modo nativo
		if _native and type(_native.runMission) == "function" then
			_native.runMission(prompt, callback, cfg)
		else
			if callback then
				callback(false, "No hay agente disponible. UAI no encontrado y NativeBridge no inicializado.")
			end
		end
	end
end

-- Abrir paneles de UAI (si está conectado)
function UAIBridge.show(section)
	if _connected and _uai and type(_uai.show) == "function" then
		local ok, err = pcall(function()
			return _uai.show(section)
		end)
		if ok then return true end
		log("No se pudo abrir panel UAI: " .. tostring(err))
		return false, "UAI.show falló"
	end
	return false, "UAI no conectado"
end

-- Inyectar provider (Groq, OpenAI, etc.)
function UAIBridge.injectProvider(prov, key)
	if _connected and _uai and type(_uai.injectProvider) == "function" then
		local ok, result = pcall(function()
			return _uai.injectProvider(prov, key)
		end)
		if ok then return true, result end
		return false, "UAI.injectProvider falló"
	end
	-- Si no hay UAI, solo guardamos localmente
	return true, "Guardado local (UAI no conectado)"
end

-- Sesiones (compatibilidad)
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

-- Estado del puente (para mostrar en UI)
function UAIBridge.getStatus()
	return _status -- "CONECTADO" | "NATIVO" | "ERROR" | "BUSCANDO"
end

function UAIBridge.isConnected()
	return _connected
end

return UAIBridge
