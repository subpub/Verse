
local xmlns_ping = "urn:xmpp:ping";

function verse.plugins.ping(stream)
	function stream:ping(jid, callback)
		local t = socket.gettime();
		stream:send_iq(verse.iq{ to = jid, type = "get" }:tag("ping", { xmlns = xmlns_ping }), 
			function (reply)
				callback(socket.gettime()-t, jid);
			end);
	end
	return true;
end
