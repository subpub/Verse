local verse = require "verse";

local xmlns_register = "jabber:iq:register";

function verse.plugins.register(stream)
	local function handle_features(features_stanza)
		if features_stanza:get_child("register", "http://jabber.org/features/iq-register") then
			local request = verse.iq({ to = stream.host_, type = "set" })
				:tag("query", { xmlns = xmlns_register })
					:tag("username"):text(stream.username):up()
					:tag("password"):text(stream.password):up();
			if stream.register_email then
				request:tag("email"):text(stream.register_email):up();
			end
			stream:send_iq(request, function (result)
				if result.attr.type == "result" then
					stream:event("registration-success");
				else
					local type, condition, text = result:get_error();
					stream:debug("Registration failed: %s", condition);
					stream:event("registration-failure", { type = type, condition = condition, text = text });
				end
			end);
		else
			stream:debug("In-band registration not offered by server");
			stream:event("registration-failure", { condition = "service-unavailable" });
		end
		stream:unhook("stream-features", handle_features);
		return true;
	end
	stream:hook("stream-features", handle_features, 310);
end
