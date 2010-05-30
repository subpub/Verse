local st = require "util.stanza";
local xmlns_session = "urn:ietf:params:xml:ns:xmpp-session";

function verse.plugins.session(stream)
	local function handle_binding(jid)
		stream:debug("Establishing Session...");
		stream:send_iq(st.iq({ type = "set" }):tag("session", {xmlns=xmlns_session}),
			function (reply)
				if reply.attr.type == "result" then
					stream:event("session-success");
				elseif reply.attr.type == "error" then
					local err = reply:child_with_name("error");
					local type, condition, text = reply:get_error();
					stream:event("session-failure", { error = condition, text = text, type = type });
				end
			end);
	end
	stream:hook("binding-success", handle_binding);
	return true;
end
