local verse = require "verse";
local vcard = require "util.vcard";

local xmlns_vcard = "vcard-temp";

function verse.plugins.vcard(stream)
	function stream:get_vcard(jid, callback) --jid = nil for self
		stream:send_iq(verse.iq({to = jid, type="get"})
			:tag("vCard", {xmlns=xmlns_vcard}), callback and function(stanza)
				local lCard, xCard;
				xCard = stanza:get_child("vCard", xmlns_vcard);
				if stanza.attr.type == "result" and xCard then
					lCard = vcard.xep54_to_lua(xCard)
					vCard = vcard.xep54_to_text(xCard)
					-- FIXME This is only until util.vcard.lua_to_text() is implemented
					lCard._text = vCard;
					callback(lCard)
				else
					callback(false) -- FIXME add error
				end
			end or nil);
	end

	function stream:set_vcard(aCard, callback)
		local xCard;
		if type(aCard) == "table" and aCard.name then
			xCard = aCard;
		elseif type(aCard) == "string" then
			xCard = vcard.text_to_xep54(aCard)[1];
		elseif type(aCard) == "table" then
			error("Converting a table to vCard not implemented")
		end
		if not xCard then return false end
		stream:debug("setting vcard to %s", tostring(xCard));
		stream:send_iq(verse.iq({type="set"})
			:add_child(xCard), callback);
	end
end
