local xmlns_version = "jabber:iq:version";

local function set_version(version_info)
	self.name = version_info.name;
	self.version = version_info.version;
	self.platform = version_info.platform;
end

function verse.plugins.version(stream)
	stream.version = { set = set_version };
	stream:hook("iq/"..xmlns_version, function (event)
		if event.stanza.attr.type ~= "get" then return; end
		local reply = verse.reply(event.stanza)
			:tag("query", { xmlns = xmlns_version });
		if stream.version.name then
			reply:tag("name"):text(tostring(stream.version.name)):up();
		end
		if stream.version.version then
			reply:tag("version"):text(tostring(stream.version.version)):up()
		end
		if stream.version.platform then
			reply:tag("os"):text(stream.version.platform);
		end
	end);
	
	function stream:query_version(target_jid, callback)
		callback = callback or function (version) return stream:event("version/response", version); end
		stream:send_iq(verse.iq({ type = "get", to = target_jid })
			:tag("query", { xmlns = xmlns_version }), 
			function (reply)
				local query = reply:get_child("query", xmlns_version);
				if query then
					local name = query:get_child("name");
					local version = query:get_child("version");
					local os = query:get_child("os");
					callback({
						name = name and name:get_text() or nil;
						version = version and version:get_text() or nil;
						platform = os and os:get_text() or nil;
						});
				else
					local type, condition, text = reply:get_error();
					callback({
						error = true;
						condition = condition;
						text = text;
						type = type;
						});
				end
			end);
	end

end
