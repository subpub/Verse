local base64 = require "mime".b64;
local xmlns_sasl = "urn:ietf:params:xml:ns:xmpp-sasl";

function verse.plugins.sasl(stream)
	local function handle_features(features_stanza)
		if stream.authenticated then return; end
		stream:debug("Authenticating with SASL...");
		--stream.sasl_state, initial_data = sasl_new({"PLAIN"}, stream.username, stream.password, stream.jid);
		local mechanism , initial_data
		if stream.username then
			mechanism = "PLAIN"
			initial_data = base64("\0"..stream.username.."\0"..stream.password);
		else
			mechanism = "ANONYMOUS"
		end
		stream:debug("Selecting %s mechanism...",mechanism);
		local auth_stanza = verse.stanza("auth", { xmlns = xmlns_sasl, mechanism = mechanism });
		if initial_data then
			auth_stanza:text(initial_data);
		end
		stream:send(auth_stanza);
		return true;
	end
	
	local function handle_sasl(sasl_stanza)
		if sasl_stanza.name == "success" then
			stream.authenticated = true;
			stream:event("authentication-success");
		elseif sasl_stanza.name == "failure" then
			local err = sasl_stanza.tags[1];
			local text = sasl_stanza:get_child_text("text");
			stream:event("authentication-failure", { condition = err.name, text = text });
		end
		stream:reopen();
		return true;
	end
	
	stream:hook("stream-features", handle_features, 300);
	stream:hook("stream/"..xmlns_sasl, handle_sasl);
	
	return true;
end

