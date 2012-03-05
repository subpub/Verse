local verse = require "verse";
local base64 = require "util.encodings".base64;
local uuid_generate = require "util.uuid".generate;

local xmlns_jingle_ibb = "urn:xmpp:jingle:transports:ibb:1";
local xmlns_ibb = "http://jabber.org/protocol/ibb";
assert(base64.encode("This is a test.") == "VGhpcyBpcyBhIHRlc3Qu", "Base64 encoding failed");
assert(base64.decode("VGhpcyBpcyBhIHRlc3Qu") == "This is a test.", "Base64 decoding failed");
local t_concat = table.concat

local ibb_conn = {};
local ibb_conn_mt = { __index = ibb_conn };

local function new_ibb(stream)
	local conn = setmetatable({ stream = stream }, ibb_conn_mt)
	conn = verse.eventable(conn);
	return conn;
end

function ibb_conn:initiate(peer, sid, stanza)
	self.block = 2048; -- ignored for now
	self.stanza = stanza or 'iq';
	self.peer = peer;
	self.sid = sid or tostring(self):match("%x+$");
	self.iseq = 0;
	self.oseq = 0;
	local feeder = function(stanza)
		return self:feed(stanza)
	end
	self.feeder = feeder;
	print("Hooking incomming IQs");
	local stream = self.stream;
		stream:hook("iq/".. xmlns_ibb, feeder)
	if stanza == "message" then
		stream:hook("message", feeder)
	end
end

function ibb_conn:open(callback)
	self.stream:send_iq(verse.iq{ to = self.peer, type = "set" }
		:tag("open", {
			xmlns = xmlns_ibb,
			["block-size"] = self.block,
			sid = self.sid,
			stanza = self.stanza
		})
	, function(reply)
		if callback then
			if reply.attr.type ~= "error" then
				callback(true)
			else
				callback(false, reply:get_error())
			end
		end
	end);
end

function ibb_conn:send(data)
	local stanza = self.stanza;
	local st;
	if stanza == "iq" then
		st = verse.iq{ type = "set", to = self.peer }
	elseif stanza == "message" then
		st = verse.message{ to = self.peer }
	end

	local seq = self.oseq;
	self.oseq = seq + 1;

	st:tag("data", { xmlns = xmlns_ibb, sid = self.sid, seq = seq })
		:text(base64.encode(data));

	if stanza == "iq" then
		self.stream:send_iq(st, function(reply)
			self:event(reply.attr.type == "result" and "drained" or "error");
		end)
	else
		stream:send(st)
		self:event("drained");
	end
end

function ibb_conn:feed(stanza)
	if stanza.attr.from ~= self.peer then return end
	local child = stanza[1];
	if child.attr.sid ~= self.sid then return end
	local ok;
	if child.name == "open" then
		self:event("connected");
		self.stream:send(verse.reply(stanza))
		return true
	elseif child.name == "data" then
		local bdata = stanza:get_child_text("data", xmlns_ibb);
		local seq = tonumber(child.attr.seq);
		local expected_seq = self.iseq;
		if bdata and seq then
			if seq ~= expected_seq then
				self.stream:send(verse.error_reply(stanza, "cancel", "not-acceptable", "Wrong sequence. Packet lost?"))
				self:close();
				self:event("error");
				return true;
			end
			self.iseq = seq + 1;
			local data = base64.decode(bdata);
			if self.stanza == "iq" then
				self.stream:send(verse.reply(stanza))
			end
			self:event("incoming-raw", data);
			return true;
		end
	elseif child.name == "close" then
		self.stream:send(verse.reply(stanza))
		self:close();
		return true
	end
end

--[[ FIXME some day
function ibb_conn:receive(patt)
	-- is this even used?
	print("ibb_conn:receive("..tostring(patt)..")");
	assert(patt == "*a" or tonumber(patt));
	local data = t_concat(self.ibuffer):sub(self.pos, tonumber(patt) or nil);
	self.pos = self.pos + #data;
	return data
end

function ibb_conn:dirty()
	print("ibb_conn:dirty()");
	return false -- ????
end
function ibb_conn:getfd()
	return 0
end
function ibb_conn:settimeout(n)
	-- ignore?
end
-]]

function ibb_conn:close()
	self.stream:unhook("iq/".. xmlns_ibb, self.feeder)
	self:event("disconnected");
end

function verse.plugins.jingle_ibb(stream)
	stream:hook("ready", function ()
		stream:add_disco_feature(xmlns_jingle_ibb);
	end, 10);

	local ibb = {};

	function ibb:_setup()
		local conn = new_ibb(self.stream);
		conn.sid    = self.sid    or conn.sid;
		conn.stanza = self.stanza or conn.stanza;
		conn.block  = self.block  or conn.block;
		conn:initiate(self.peer, self.sid, self.stanza);
		self.conn = conn;
	end
	function ibb:generate_initiate()
		print("ibb:generate_initiate() as ".. self.role);
		local sid = uuid_generate();
		self.sid = sid;
		self.stanza = 'iq';
		self.block = 2048;
		local transport = verse.stanza("transport", { xmlns = xmlns_jingle_ibb,
			sid = self.sid, stanza = self.stanza, ["block-size"] = self.block });
		return transport;
	end
	function ibb:generate_accept(initiate_transport)
		print("ibb:generate_accept() as ".. self.role);
		local attr = initiate_transport.attr;
		self.sid    = attr.sid    or self.sid;
		self.stanza = attr.stanza or self.stanza;
		self.block  = attr["block-size"] or self.block;
		self:_setup();
		return initiate_transport;
	end
	function ibb:connect(callback)
		if not self.conn then
			self:_setup();
		end
		local conn = self.conn;
		print("ibb:connect() as ".. self.role);
		if self.role == "initiator" then
			conn:open(function(ok, ...)
				assert(ok, table.concat({...}, ", "));
				callback(conn);
			end);
		else
			callback(conn);
		end
	end
	function ibb:info_received(jingle_tag)
		print("ibb:info_received()");
		-- TODO, what exactly?
	end
	function ibb:disconnect()
		if self.conn then
			self.conn:close()
		end
	end
	function ibb:handle_accepted(jingle_tag) end

	local ibb_mt = { __index = ibb };
	stream:hook("jingle/transport/"..xmlns_jingle_ibb, function (jingle)
		return setmetatable({
			role = jingle.role,
			peer = jingle.peer,
			stream = jingle.stream,
			jingle = jingle,
		}, ibb_mt);
	end);
end
