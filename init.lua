
-- Use LuaRocks if available
pcall(require, "luarocks.require");

local server = require "server";
local events = require "events";

module("verse", package.seeall);
local verse = _M;

local stream = {};
stream.__index = stream;
stream_mt = stream;

verse.plugins = {};

function verse.new()
	local t = {};
	t.id = tostring(t):match("%x*$");
	t.logger = logger.init(t.id);
	t.events = events.new();
	return setmetatable(t, stream);
end

function verse.loop()
	return server.loop();
end

function stream:connect(connect_host, connect_port)
	connect_host = connect_host or "localhost";
	connect_port = tonumber(connect_port) or 5222;
	
	-- Create and initiate connection
	local conn = socket.tcp()
	conn:settimeout(0);
	local success, err = conn:connect(connect_host, connect_port);
	
	if not success and err ~= "timeout" then
		self:warn("connect() to %s:%d failed: %s", connect_host, connect_port, err);
		return false, err;
	end

	--local conn, err = server.addclient(self.connect_host or self.host, tonumber(self.connect_port) or 5222, new_listener(self), "*a");
	local conn = server.wrapclient(conn, connect_host, connect_port, new_listener(self), "*a"); --, hosts[from_host].ssl_ctx, false );
	if not conn then
		return nil, err;
	end
	
	self.conn = conn;
	local w, t = conn.write, tostring;
	self.send = function (_, data) return w(t(data)); end
end

-- Logging functions
function stream:debug(...)
	return self.logger("debug", ...);
end

function stream:warn(...)
	return self.logger("warn", ...);
end

function stream:error(...)
	return self.logger("error", ...);
end

-- Event handling
function stream:event(name, ...)
	self:debug("Firing event: "..tostring(name));
	return self.events.fire_event(name, ...);
end

function stream:hook(name, ...)
	return self.events.add_handler(name, ...);
end

function stream:add_plugin(name)
	if require("verse.plugins."..name) then
		local ok, err = verse.plugins[name](self);
		if ok then
			self:debug("Loaded %s plugin", name);
		else
			self:warn("Failed to load %s plugin: %s", name, err);
		end
	end
	return self;
end

-- Listener factory
function new_listener(stream)
	local conn_listener = {};
	
	function conn_listener.incoming(conn, data)
		stream:debug("Data");
		if not stream.connected then
			stream.connected = true;
			stream.send = function (stream, data) stream:debug("Sending data: "..tostring(data)); return conn.write(tostring(data)); end;
			stream:event("connected");
		end
		if data then
			stream:event("incoming-raw", data);
		end
	end
	
	function conn_listener.disconnect(conn, err)
		stream.connected = false;
		stream:event("disconnected", { reason = err });
	end
	
	return conn_listener;
end


local log = require "util.logger".init("verse");

return verse;
