local verse = require"verse";
local xmlns_receipts = "urn:xmpp:receipts";

function verse.plugins.receipts(stream)
	stream:add_plugin("disco");
	local function send_receipt(stanza)
		if stanza:get_child("request", xmlns_receipts) then
			stream:send(verse.reply(stanza)
				:tag("received", { xmlns = xmlns_receipts, id = stanza.attr.id }));
		end
	end

	stream:add_disco_feature(xmlns_receipts);
	stream:hook("message", send_receipt, 1000);
end

