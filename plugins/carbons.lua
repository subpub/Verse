local verse = require "verse";

local xmlns_carbons = "urn:xmpp:carbons:2";
local xmlns_forward = "urn:xmpp:forward:0";
local os_time = os.time;
local parse_datetime = require "util.datetime".parse;
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
		local carbon = stanza:get_child(nil, xmlns_carbons);
		if stanza.attr.from == my_bare and carbon then
			local carbon_dir = carbon.name;
			local fwd = carbon:get_child("forwarded", xmlns_forward);
			local fwd_stanza = fwd and fwd:get_child("message", "jabber:client");
			local delay = fwd:get_child("delay", "urn:xmpp:delay");
			local stamp = delay and delay.attr.stamp;
			stamp = stamp and parse_datetime(stamp);
			if fwd_stanza then
				return stream:event("carbon", {
					dir = carbon_dir,
					stanza = fwd_stanza,
					timestamp = stamp or os_time(),
				});
			end
		end
	end, 1);
end
