local jid_bare = require "util.jid".bare;
local t_insert = table.insert;

local xmlns_pubsub = "http://jabber.org/protocol/pubsub";
local xmlns_pubsub_owner = "http://jabber.org/protocol/pubsub#owner";
local xmlns_pubsub_event = "http://jabber.org/protocol/pubsub#event";
local xmlns_pubsub_errors = "http://jabber.org/protocol/pubsub#errors";

local pubsub = {};
local pubsub_mt = { __index = pubsub };

function verse.plugins.pubsub(stream)
	stream.pubsub = setmetatable({ stream = stream }, pubsub_mt);
	stream:hook("message", function (message)
		for pubsub_event in message:childtags("event", xmlns_pubsub_event) do
			local items = pubsub_event:get_child("items");
			if items then
				local node = items.attr.node;
				for item in items:childtags("item") do
					stream:event("pubsub/event", {
						from = message.attr.from;
						node = node;
						item = item;
					});
				end
			end
		end
	end);
	return true;
end

function pubsub:create(server, node, callback)
	self.stream:warn("pubsub:create() is deprecated, "
		.."you should use pubsub:service(%q):node(%q):create() instead\n%s", server or "", node, debug.traceback());
	local create = verse.iq({ to = server, type = "set" })
		:tag("pubsub", { xmlns = xmlns_pubsub })
			:tag("create", { node = node }):up()
	self.stream:send_iq(create, function (result)
		if callback then
			if result.attr.type == "result" then
				callback(true);
			else
				callback(false, result:get_error());
			end
		end
	  end
	);
end

function pubsub:subscribe(server, node, jid, callback)
	self.stream:warn("pubsub:subscribe() is deprecated, "
		.."you should use pubsub:service(%q):node(%q):subscribe(jid) instead\n%s", server or "", node, debug.traceback());
	self.stream:send_iq(verse.iq({ to = server, type = "set" })
		:tag("pubsub", { xmlns = xmlns_pubsub })
			:tag("subscribe", { node = node, jid = jid or jid_bare(self.stream.jid) })
	, function (result)
		if callback then
			if result.attr.type == "result" then
				callback(true);
			else
				callback(false, result:get_error());
			end
		end
	  end
	);
end

function pubsub:publish(server, node, id, item, callback)
	self.stream:warn("pubsub:publish() is deprecated, "
		.."you should use pubsub:service(%q):node(%q):publish() instead\n%s", server or "", node, debug.traceback());
	self.stream:send_iq(verse.iq({ to = server, type = "set" })
		:tag("pubsub", { xmlns = xmlns_pubsub })
			:tag("publish", { node = node })
				:tag("item", { id = id })
					:add_child(item)
	, function (result)
		if callback then
			if result.attr.type == "result" then
				callback(true);
			else
				callback(false, result:get_error());
			end
		end
	  end
	);
end

--------------------------------------------------------------------------
---------------------New and improved PubSub interface--------------------
--------------------------------------------------------------------------

local pubsub_service = {};
local pubsub_service_mt = { __index = pubsub_service };

-- TODO should the property be named 'jid' instead?
function pubsub:service(service)
	return setmetatable({ stream = self.stream, service = service }, pubsub_service_mt)
end

-- Helper function for iq+pubsub tags

local function pubsub_iq(iq_type, to, ns, op, node, jid, item_id)
	local st = verse.iq{ type = iq_type or "get", to = to }
		:tag("pubsub", { xmlns = ns or xmlns_pubsub }) -- ns would be ..#owner
			if op then st:tag(op, { node = node, jid = jid }); end
				if id then st:tag("item", { id = item_id ~= true and item_id or nil }); end
	return st;
end

-- http://xmpp.org/extensions/xep-0060.html#entity-subscriptions
function pubsub_service:subscriptions(callback)
	self.stream:send_iq(pubsub_iq(nil, self.service, nil, "subscriptions")
	, callback and function (result)
		if result.attr.type == "result" then
			local ps = result:get_child("pubsub", xmlns_pubsub);
			local subs = ps and ps:get_child("subscriptions");
			local nodes = {};
			if subs then
				for sub in subs:childtags("subscription") do
					local node = self:node(sub.attr.node)
					node.subscription = sub;
					t_insert(nodes, node);
					-- FIXME Good enough?
					-- Or how about:
					-- nodes[node] = sub;
				end
			end
			callback(nodes);
		else
			callback(false, result:get_error());
		end
	end or nil);
end

-- http://xmpp.org/extensions/xep-0060.html#entity-affiliations
function pubsub_service:affiliations(callback)
	self.stream:send_iq(pubsub_iq(nil, self.service, nil, "affiliations")
	, callback and function (result)
		if result.attr.type == "result" then
			local ps = result:get_child("pubsub", xmlns_pubsub);
			local affils = ps and ps:get_child("affiliations") or {};
			local nodes = {};
			if affils then
				for affil in affils:childtags("affiliation") do
					local node = self:node(affil.attr.node)
					node.affiliation = affil;
					t_insert(nodes, node);
					-- nodes[node] = affil;
				end
			end
			callback(nodes);
		else
			callback(false, result:get_error());
		end
	end or nil);
end

-- TODO Listing nodes? It's done with standard disco#items, but should
-- we have a wrapper here? If so, it could wrap items in pubsub_node objects

--[[
function pubsub_service:nodes(callback)
	self.stream:disco_items(...)
end
--]]

local pubsub_node = {};
local pubsub_node_mt = { __index = pubsub_node };

function pubsub_service:node(node)
	return setmetatable({ stream = self.stream, service = self.service, node = node }, pubsub_node_mt)
end

function pubsub_mt:__call(service, node)
	local s = self:service(service);
	return node and s:node(node) or s;
end

function pubsub_node:hook(callback, prio)
	local function hook(event)
		-- FIXME service == nil would mean anyone,
		-- publishing would be go to your bare jid.
		-- So if you're only interestied in your own
		-- events, hook your own bare jid.
		if (not event.service or event.from == self.service) and event.node == self.node then
			return callback(event)
		end
	end
	self.stream:hook("pubsub/event", hook, prio);
	return hook;
end

function pubsub_node:unhook(callback)
	self.stream:unhook("pubsub/event", callback);
end

function pubsub_node:create(config, callback)
	if config ~= nil then
		error("Not implemented yet.");
	else
		self.stream:send_iq(pubsub_iq("set", self.service, nil, "create", self.node), callback);
	end
end

-- <configure/> and <default/> rolled into one
function pubsub_node:configure(config, callback)
	if config ~= nil then
		error("Not implemented yet.");
		-- if config == true then
		-- fetch form and pass it to the callback
		-- which would process it and pass it back
		-- and then we submit it
		-- elseif type(config) == "table" then
		-- it's a form or stanza that we submit
		-- end
		-- this would be done for everything that needs a config
	end
	self.stream:send_iq(pubsub_iq("set", self.service, nil, config == nil and "default" or "configure", self.node), callback);
end

function pubsub_node:publish(id, options, node, callback)
	if options ~= nil then
		error("Node configuration is not implemented yet.");
	end
	self.stream:send_iq(pubsub_iq("set", self.service, nil, "publish", self.node, nil, id)
	:add_child(node)
	, callback);
end

function pubsub_node:subscribe(jid, options, callback)
	if options ~= nil then
		error("Subscription configuration is not implemented yet.");
	end
	self.stream:send_iq(pubsub_iq("set", self.service, nil, "subscribe", self.node, jid, id)
	, callback);
end

function pubsub_node:subscription(callback)
	error("Not implemented yet.");
end

function pubsub_node:affiliation(callback)
	error("Not implemented yet.");
end

function pubsub_node:unsubscribe(callback)
	error("Not implemented yet.");
end

function pubsub_node:configure_subscription(options, callback)
	error("Not implemented yet.");
end

function pubsub_node:items(count, callback)
	error("Not implemented yet.");
end

function pubsub_node:item(id, callback)
	error("Not implemented yet.");
end

function pubsub_node:retract(id, callback)
	error("Not implemented yet.");
end

function pubsub_node:purge(callback)
	error("Not implemented yet.");
end

function pubsub_node:delete(callback)
	error("Not implemented yet.");
end

