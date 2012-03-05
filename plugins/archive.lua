local xmlns_mam = "urn:xmpp:mam:tmp"
local uuid = require "util.uuid".generate;

function verse.plugins.archive(stream)
	function stream:query_archive(where, query_params, callback)
		local queryid = uuid();
		local query_st = verse.iq{ type="get", to=where }
			:tag("query", { xmlns = xmlns_mam, queryid = queryid });

		local params = { "with", "start", "end" };
		local query_params = query_params or {};
		for i=1,#params do
			local k = params[i];
			if query_params[k] then
				query_st:tag(k):text(query_params[k]):up();
			end
		end

		local results = {};
		local function handle_archived_message(message)
			local result_tag = message:get_child("result", xmlns_mam);
			if result_tag and result_tag.attr.queryid == queryid then
				local forwarded = message:get_child("forwarded", "urn:xmpp:forward:0");

				local delay = forwarded:get_child("delay", "urn:xmpp:delay");
				local stamp = delay and delay.attr.stamp or nil;

				local message = forwarded:get_child("message", "jabber:client")

				results[#results+1] = { stamp = stamp, message = message };
				return true
			end
		end

		self:hook("message", handle_archived_message, 1);
		self:send_iq(query_st, function(reply)
			self:unhook("message", handle_archived_message);
			callback(reply.attr.type == "result" and #results, results);
			return true
		end);
	end

	--TODO Settings
end
