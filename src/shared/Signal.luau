--[[
	Signal.luau
	Minimal pure-Luau signal (no BindableEvent overhead, no argument copying).
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ()): Connection
	local handlers = self._handlers
	local connection
	connection = {
		Connected = true,
		Disconnect = function(conn)
			if not conn.Connected then
				return
			end
			conn.Connected = false
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
	table.insert(handlers, handler)
	return connection
end

function Signal:Fire(...: any)
	-- Snapshot so handlers can disconnect while firing.
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

function Signal:Once(handler: (...any) -> ()): Connection
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

return Signal
