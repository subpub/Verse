-- Change these:
local jid, password = "user@example.com", "secret";

-- This line squishes verse each time you run,
-- handy if you're hacking on Verse itself
--os.execute("squish --minify-level=none");

require "verse".init("client");

c = verse.new();
c:add_plugin("pubsub");

-- Add some hooks for debugging
c:hook("opened", function () print("Stream opened!") end);
c:hook("closed", function () print("Stream closed!") end);
c:hook("stanza", function (stanza) print("Stanza:", stanza) end);

-- This one prints all received data
c:hook("incoming-raw", print, 1000);

-- Print a message after authentication
c:hook("authentication-success", function () print("Logged in!"); end);
c:hook("authentication-failure", function (err) print("Failed to log in! Error: "..tostring(err.condition)); end);

-- Print a message and exit when disconnected
c:hook("disconnected", function () print("Disconnected!"); os.exit(); end);

-- Now, actually start the connection:
c:connect_client(jid, password);

-- Catch the "ready" event to know when the stream is ready to use
c:hook("ready", function ()
	print("Stream ready!");

	-- Create a reference to a node
	local node = c.pubsub("pubsub.shakespeare.lit", "princely_musings");

	-- Callback for when something is published to the node
	node:hook(function(event)
		print(event.item)
	end);
	node:subscribe() -- so we actually get the notifications that above callback would get

	node:publish(
			nil, -- no id, so the service should give us one
			nil, -- no options (not supported at the time of this writing)
			verse.stanza("something", { xmlns = "http://example.com/pubsub-thingy" }) -- the actual payload, would turn up in event.item above
				:tag("foobar"),
			function(success) -- callback
				print("publish", success and "success" or "failure")
			end)
end);

print("Starting loop...")
verse.loop()

