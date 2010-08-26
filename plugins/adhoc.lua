local adhoc = require "lib.adhoc";

local xmlns_commands = "http://jabber.org/protocol/commands";

local commands = {};

function verse.plugins.adhoc(stream)
	stream:add_disco_feature(xmlns_commands);

	local function has_affiliation(jid, aff)
		if not(aff) or aff == "user" then return true; end
		-- TODO: Support 'roster', and callback etc.
	end
	
	function stream:add_adhoc_command(name, node, handler, permission)
		commands[node] = adhoc.new(name, node, handler, permission);
		stream:add_disco_item({ jid = stream.jid, node = node, name = name }, xmlns_commands);
		return commands[node];
	end
	
	local function handle_command(stanza)
		local command_tag = stanza.tags[1];
		local node = command_tag.attr.node;
		
		local handler = commands[node];
		if not handler then return; end
		
		if not has_affiliation(stanza.attr.from, handler.permission) then
			stream:send(verse.error_reply(stanza, "auth", "forbidden", "You don't have permission to execute this command"):up()
			:add_child(handler:cmdtag("canceled")
				:tag("note", {type="error"}):text("You don't have permission to execute this command")));
			return true
		end
		
		-- User has permission now execute the command
		return adhoc.handle_cmd(handler, { send = function (d) return stream:send(d) end }, stanza);
	end
	
	stream:hook("iq/"..xmlns_commands, function (stanza)
		local type = stanza.attr.type;
		local name = stanza.tags[1].name;
		if type == "set" and name == "command" then
			return handle_command(stanza);
		end
	end);
end
