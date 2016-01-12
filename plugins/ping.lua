local verse = require "verse";
local gettime = require"socket".gettime;

local xmlns_ping = "urn:xmpp:ping";

function verse.plugins.ping(stream)
	function stream:ping(jid, callback)
		local t = gettime();
		stream:send_iq(verse.iq{ to = jid, type = "get" }:tag("ping", { xmlns = xmlns_ping }),
			function (reply)
				if reply.attr.type == "error" then
					local type, condition, text = reply:get_error();
					if condition ~= "service-unavailable" and condition ~= "feature-not-implemented" then
						callback(nil, jid, { type = type, condition = condition, text = text });
						return;
					end
				end
				callback(gettime()-t, jid);
			end);
	end
	stream:hook("iq/"..xmlns_ping, function(stanza)
		return stream:send(verse.reply(stanza));
	end);
	return true;
end
