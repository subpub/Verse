local verse = require "verse2";
local stream = verse.stream_mt;

local jid_split = require "jid".split;
local lxp = require "lxp";
local st = require "util.stanza";

-- Shortcuts to save having to load util.stanza
verse.message, verse.presence, verse.iq, verse.stanza, verse.reply = 
	st.message, st.presence, st.iq, st.stanza, st.reply;

local init_xmlhandlers = require "xmlhandlers";

local xmlns_stream = "http://etherx.jabber.org/streams";

local stream_callbacks = { stream_tag = xmlns_stream.."\1stream", 
		default_ns = "jabber:client" };
	
function stream_callbacks.streamopened(stream, attr)
	if not stream:event("opened") then
		stream.notopen = nil;
	end
	return true;
end

function stream_callbacks.streamclosed(stream)
	return stream:event("closed");
end

function stream_callbacks.handlestanza(stream, stanza)
	if stanza.attr.xmlns == xmlns_stream then
		return stream:event("stream-"..stanza.name, stanza);
	elseif stanza.attr.xmlns then
		return stream:event("stream/"..stanza.attr.xmlns, stanza);
	end
	return stream:event("stanza", stanza);
end

local function reset_stream(stream)
	-- Reset stream
	local parser = lxp.new(init_xmlhandlers(stream, stream_callbacks), "\1");
	stream.parser = parser;
	
	stream.notopen = true;
	
	function stream.data(conn, data)
		local ok, err = parser:parse(data);
		if ok then return; end
		stream:debug("debug", "Received invalid XML (%s) %d bytes: %s", tostring(err), #data, data:sub(1, 300):gsub("[\r\n]+", " "));
		stream:close("xml-not-well-formed");
	end
	
	return true;
end

function stream:connect_client(jid, pass)
	self.jid, self.password = jid, pass;
	self.username, self.host, self.resource = jid_split(jid);
	
	self:hook("incoming-raw", function (data) return self.data(self.conn, data); end);
	
	self.curr_id = 0;
	
	self.tracked_iqs = {};
	self:hook("stanza", function (stanza)
		local id, type = stanza.attr.id, stanza.attr.type;
		if id and stanza.name == "iq" and (type == "result" or type == "error") and self.tracked_iqs[id] then
			self.tracked_iqs[id](stanza);
			self.tracked_iqs[id] = nil;
			return true;
		end
	end);
	
	-- Initialise connection
	self:connect(self.connect_host or self.host, self.connect_port or 5222);
	--reset_stream(self);	
	self:reopen();
end

function stream:reopen()
	reset_stream(self);
	self:send(st.stanza("stream:stream", { to = self.host, ["xmlns:stream"]='http://etherx.jabber.org/streams', xmlns = "jabber:client" }):top_tag());
end

function stream:close(reason)
	if not self.notopen then
		self:send("</stream:stream>");
	end
	self.conn:close();
end

function stream:send_iq(iq, callback)
	local id = self:new_id();
	self.tracked_iqs[id] = callback;
	iq.attr.id = id;
	self:send(iq);
end

function stream:new_id()
	self.curr_id = self.curr_id + 1;
	return tostring(self.curr_id);
end
