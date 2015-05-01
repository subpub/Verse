local xmlns_carbons = "urn:xmpp:carbons:1";
local xmlns_forward = "urn:xmpp:forward:0";

local function datetime(t) return os_date("!%Y-%m-%dT%H:%M:%SZ", t); end

-- This line squishes verse each time you run,
-- handy if you're hacking on Verse itself
--os.execute("squish --minify-level=none verse");

require "verse".init("client");

c = verse.new();--verse.logger());
c:add_plugin "carbons"

c:hook("disconnected", verse.quit);
local jid, password = unpack(arg);
assert(jid and password, "You need to supply JID and password as arguments");
c:connect_client(jid, password);

-- Print a message after authentication
c:hook("authentication-success", function () c:debug("Logged in!"); end);
c:hook("authentication-failure", function (err)
	c:error("Failed to log in! Error: "..tostring(err.condition));
	c:close();
end);

c:hook("carbon", function(carbon)
	local dir, ts, st = carbon.dir, carbon.timestamp, carbon.stanza;
	print("", datetime(ts), dir:upper());
	print(st);
end);

-- Catch the "ready" event to know when the stream is ready to use
c:hook("ready", function ()
	c:debug("Connected");
	c.carbons:enable(function(ok)
		if ok then
			c:debug("Carbons enabled")
		else
			c:error("Could not enable carbons, aborting");
			c:close();
		end
	end);
end);

verse.loop()
