

local server = require "server";
local xmlhandlers = require "xmlhandlers";
local jid = require "jid";
local jid_split = jid.split;

module("verse", package.seeall);
local verse = _M;

local stream = {};
stream.__index = stream;

function verse.new()
	return setmetatable({}, stream);
end

function verse.loop()
	return server.loop();
end

function stream:connect(jid, pass)
	self.jid, self.password = jid, pass;
	self.username, self.host, self.resource = jid_split(jid);
	local conn, err = server.addclient(self.connect_host or self.host, tonumber(self.connect_port) or 5222, new_listener(self), "*a");
	
	if not conn then
		return nil, err;
	end
	
	self.conn = conn;
end

function new_listener(stream)
	local conn_listener = {};
	
	function conn_listener.incoming(conn, data)
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
