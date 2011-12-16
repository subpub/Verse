local verse = require "verse";

local xmlns_pubsub = "http://jabber.org/protocol/pubsub";
local xmlns_pubsub_event = xmlns_pubsub.."#event";

function verse.plugins.pep(stream)
	stream:add_plugin("disco");
	stream:add_plugin("pubsub");
	stream.pep = {};
	
	stream:hook("pubsub/event", function(event)
		return stream:event("pep/"..event.node, { from = event.from, item = event.item.tags[1] } );
	end);
	
	function stream:hook_pep(node, callback, priority)
		local handlers = stream.events._handlers["pep/"..node];
		if not(handlers) or #handlers == 0 then
			stream:add_disco_feature(node.."+notify");
		end
		stream:hook("pep/"..node, callback, priority);
	end
	
	function stream:unhook_pep(node, callback)
		stream:unhook("pep/"..node, callback);
		local handlers = stream.events._handlers["pep/"..node];
		if not(handlers) or #handlers == 0 then
			stream:remove_disco_feature(node.."+notify");
		end
	end
	
	function stream:publish_pep(item, node)
		return stream.pubsub:service(nil):node(node or item.attr.xmlns):publish(nil, nil, item)
	end
end
