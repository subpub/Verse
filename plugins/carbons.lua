local verse = require "verse";

local xmlns_carbons = "urn:xmpp:carbons:1";
local xmlns_forward = "urn:xmpp:forward:0";
local os_date = os.date;
local datetime = function(t) return os_date("!%Y-%m-%dT%H:%M:%SZ", t); end
local bare_jid = require "util.jid".bare;

-- TODO Check disco for support

function verse.plugins.carbons(stream)
	local carbons = {};
	carbons.enabled = false;
	stream.carbons = carbons;

	function carbons:enable(callback)
		stream:send_iq(verse.iq{type="set"}
		:tag("enable", { xmlns = xmlns_carbons })
		, function(result)
			local success = result.attr.type == "result";
			if success then
				carbons.enabled = true;
			end
			if callback then
				callback(success);
			end
		end or nil);
	end

	function carbons:disable(callback)
		stream:send_iq(verse.iq{type="set"}
		:tag("disable", { xmlns = xmlns_carbons })
		, function(result)
			local success = result.attr.type == "result";
			if success then
				carbons.enabled = false;
			end
			if callback then
				callback(success);
			end
		end or nil);
	end

	local my_bare;
	stream:hook("bind-success", function()
		my_bare = bare_jid(stream.jid);
	end);

	stream:hook("message", function(stanza)
		local carbon_dir = stanza:get_child(nil, xmlns_carbons);
		if stanza.attr.from == my_bare and carbon_dir then
			carbon_dir = carbon_dir.name;
			local fwd = stanza:get_child("forwarded", xmlns_forward);
			local fwd_stanza = fwd and fwd:get_child("message", "jabber:client");
			if fwd_stanza then
				return stream:event("carbon", {
					dir = carbon_dir,
					stanza = fwd_stanza,
					timestamp = nil or datetime(), -- TODO check for delay tag
				});
			end
		end
	end, 1);
end
