-- Verse XMPP Library
-- Copyright (C) 2010 Hubert Chathi <hubert@uhoreg.ca>
-- Copyright (C) 2010 Matthew Wild <mwild1@gmail.com>
-- 
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local verse = require "verse";
local b64 = require("mime").b64;
local sha1 = require("util.sha1").sha1;

local xmlns_caps = "http://jabber.org/protocol/caps";
local xmlns_disco = "http://jabber.org/protocol/disco";
local xmlns_disco_info = xmlns_disco.."#info";
local xmlns_disco_items = xmlns_disco.."#items";

function verse.plugins.disco(stream)
	stream:add_plugin("presence");
	local disco_info_mt = {
		__index = function(t, k)
			local node = { identities = {}, features = {} };
			if k == "identities" or k == "features" then
				return t[false][k]
			end
			t[k] = node;
			return node;
		end,
	};
	local disco_items_mt = {
		__index = function(t, k)
			local node = { };
			t[k] = node;
			return node;
		end,
	};
	stream.disco = {
		cache = {},
		info = setmetatable({
			[false] = {
				identities = {
					{category = 'client', type='pc', name='Verse'},
				},
				features = {
					[xmlns_caps] = true,
					[xmlns_disco_info] = true,
					[xmlns_disco_items] = true,
				},
			},
		}, disco_info_mt);
		items = setmetatable({[false]={}}, disco_items_mt);
	};

	stream.caps = {}
	stream.caps.node = 'http://code.matthewwild.co.uk/verse/'

	local function cmp_identity(item1, item2)
		if item1.category < item2.category then
			return true;
		elseif item2.category < item1.category then
			return false;
		end
		if item1.type < item2.type then
			return true;
		elseif item2.type < item1.type then
			return false;
		end
		if (not item1['xml:lang'] and item2['xml:lang']) or
			 (item2['xml:lang'] and item1['xml:lang'] < item2['xml:lang']) then
			return true
		end
		return false
	end

	local function cmp_feature(item1, item2)
		return item1.var < item2.var
	end

	local function calculate_hash(node)
		local identities = stream.disco.info[node or false].identities;
		table.sort(identities, cmp_identity)
		local features = {};
		for var in pairs(stream.disco.info[node or false].features) do
			features[#features+1] = { var = var };
		end
		table.sort(features, cmp_feature)
		local S = {};
		for key,identity in pairs(identities) do
			S[#S+1] = table.concat({
				identity.category, identity.type or '',
				identity['xml:lang'] or '', identity.name or ''
			}, '/');
		end
		for key,feature in pairs(features) do
			S[#S+1] = feature.var
		end
		S[#S+1] = '';
		S = table.concat(S,'<');
		-- FIXME: make sure S is utf8-encoded
		--stream:debug("Computed hash string: "..S);
		--stream:debug("Computed hash string (sha1): "..sha1(S, true));
		--stream:debug("Computed hash string (sha1+b64): "..b64(sha1(S)));
		return (b64(sha1(S)))
	end

	setmetatable(stream.caps, {
		__call = function (...) -- vararg: allow calling as function or member
			-- retrieve the c stanza to insert into the
			-- presence stanza
			local hash = calculate_hash()
			stream.caps.hash = hash;
			-- TODO proper caching.... some day
			return verse.stanza('c', {
				xmlns = xmlns_caps,
				hash = 'sha-1',
				node = stream.caps.node,
				ver = hash
			})
		end
	})
	
	function stream:set_identity(identity, node)
		self.disco.info[node or false].identities = { identity };
		stream:resend_presence();
	end

	function stream:add_identity(identity, node)
		local identities = self.disco.info[node or false].identities;
		identities[#identities + 1] = identity;
		stream:resend_presence();
	end

	function stream:add_disco_feature(feature, node)
		local feature = feature.var or feature;
		self.disco.info[node or false].features[feature] = true;
		stream:resend_presence();
	end
	
	function stream:remove_disco_feature(feature, node)
		local feature = feature.var or feature;
		self.disco.info[node or false].features[feature] = nil;
		stream:resend_presence();
	end

	function stream:add_disco_item(item, node)
		local items = self.disco.items[node or false];
		items[#items +1] = item;
	end

	function stream:remove_disco_item(item, node)
		local items = self.disco.items[node or false];
		for i=#items,1,-1 do
			if items[i] == item then
				table.remove(items, i);
			end
		end
	end

	-- TODO Node?
	function stream:jid_has_identity(jid, category, type)
		local cached_disco = self.disco.cache[jid];
		if not cached_disco then
			return nil, "no-cache";
		end
		local identities = self.disco.cache[jid].identities;
		if type then
			return identities[category.."/"..type] or false;
		end
		-- Check whether we have any identities with this category instead
		for identity in pairs(identities) do
			if identity:match("^(.*)/") == category then
				return true;
			end
		end
	end

	function stream:jid_supports(jid, feature)
		local cached_disco = self.disco.cache[jid];
		if not cached_disco or not cached_disco.features then
			return nil, "no-cache";
		end
		return cached_disco.features[feature] or false;
	end
	
	function stream:get_local_services(category, type)
		local host_disco = self.disco.cache[self.host];
		if not(host_disco) or not(host_disco.items) then
			return nil, "no-cache";
		end
		
		local results = {};
		for _, service in ipairs(host_disco.items) do
			if self:jid_has_identity(service.jid, category, type) then
				table.insert(results, service.jid);
			end
		end
		return results;
	end
	
	function stream:disco_local_services(callback)
		self:disco_items(self.host, nil, function (items)
			if not items then
				return callback({});
			end
			local n_items = 0;
			local function item_callback()
				n_items = n_items - 1;
				if n_items == 0 then
					return callback(items);
				end
			end
			
			for _, item in ipairs(items) do
				if item.jid then
					n_items = n_items + 1;
					self:disco_info(item.jid, nil, item_callback);
				end
			end
			if n_items == 0 then
				return callback(items);
			end
		end);
	end
	
	function stream:disco_info(jid, node, callback)
		local disco_request = verse.iq({ to = jid, type = "get" })
			:tag("query", { xmlns = xmlns_disco_info, node = node });
		self:send_iq(disco_request, function (result)
			if result.attr.type == "error" then
				return callback(nil, result:get_error());
			end
			
			local identities, features = {}, {};
			
			for tag in result:get_child("query", xmlns_disco_info):childtags() do
				if tag.name == "identity" then
					identities[tag.attr.category.."/"..tag.attr.type] = tag.attr.name or true;
				elseif tag.name == "feature" then
					features[tag.attr.var] = true;
				end
			end
			

			if not self.disco.cache[jid] then
				self.disco.cache[jid] = { nodes = {} };
			end

			if node then
				if not self.disco.cache[jid].nodes[node] then
					self.disco.cache[jid].nodes[node] = { nodes = {} };
				end
				self.disco.cache[jid].nodes[node].identities = identities;
				self.disco.cache[jid].nodes[node].features = features;
			else
				self.disco.cache[jid].identities = identities;
				self.disco.cache[jid].features = features;
			end
			return callback(self.disco.cache[jid]);
		end);
	end
	
	function stream:disco_items(jid, node, callback)
		local disco_request = verse.iq({ to = jid, type = "get" })
			:tag("query", { xmlns = xmlns_disco_items, node = node });
		self:send_iq(disco_request, function (result)
			if result.attr.type == "error" then
				return callback(nil, result:get_error());
			end
			local disco_items = { };
			for tag in result:get_child("query", xmlns_disco_items):childtags() do
				if tag.name == "item" then
					table.insert(disco_items, {
						name = tag.attr.name;
						jid = tag.attr.jid;
						node = tag.attr.node;
					});
				end
			end
			
			if not self.disco.cache[jid] then
				self.disco.cache[jid] = { nodes = {} };
			end
			
			if node then
				if not self.disco.cache[jid].nodes[node] then
					self.disco.cache[jid].nodes[node] = { nodes = {} };
				end
				self.disco.cache[jid].nodes[node].items = disco_items;
			else
				self.disco.cache[jid].items = disco_items;
			end
			return callback(disco_items);
		end);
	end
	
	stream:hook("iq/"..xmlns_disco_info, function (stanza)
		local query = stanza.tags[1];
		if stanza.attr.type == 'get' and query.name == "query" then
			local query_node = query.attr.node;
			local node = stream.disco.info[query_node or false];
			if query_node and query_node == stream.caps.node .. "#" .. stream.caps.hash then
				node = stream.disco.info[false];
			end
			local identities, features = node.identities, node.features

			-- construct the response
			local result = verse.reply(stanza):tag("query", {
				xmlns = xmlns_disco_info,
				node = query_node,
			});
			for _,identity in pairs(identities) do
				result:tag('identity', identity):up()
			end
			for feature in pairs(features) do
				result:tag('feature', { var = feature }):up()
			end
			stream:send(result);
			return true
		end
	end);

	stream:hook("iq/"..xmlns_disco_items, function (stanza)
		local query = stanza.tags[1];
		if stanza.attr.type == 'get' and query.name == "query" then
			-- figure out what items to send
			local items = stream.disco.items[query.attr.node or false];

			-- construct the response
			local result = verse.reply(stanza):tag('query',{
				xmlns = xmlns_disco_items,
				node = query.attr.node
			})
			for i=1,#items do
				result:tag('item', items[i]):up()
			end
			stream:send(result);
			return true
		end
	end);
	
	local initial_disco_started;
	stream:hook("ready", function ()
		if initial_disco_started then return; end
		initial_disco_started = true;
		stream:disco_local_services(function (services)
			for _, service in ipairs(services) do
				local service_disco_info = stream.disco.cache[service.jid];
				if service_disco_info then
					for identity in pairs(service_disco_info.identities) do
						local category, type = identity:match("^(.*)/(.*)$");
						stream:event("disco/service-discovered/"..category, {
							type = type, jid = service.jid;
						});
					end
				end
			end
			stream:event("ready");
		end);
		return true;
	end, 50);
	
	stream:hook("presence-out", function (presence)
		if not presence:get_child("c", xmlns_caps) then
			presence:reset():add_child(stream:caps()):reset();
		end
	end, 10);
end

-- end of disco.lua
