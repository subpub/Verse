-- Change these:
local jid, password = "user@example.com/receiver", "secret";

-- This line squishes verse each time you run,
-- handy if you're hacking on Verse itself
--os.execute("squish --minify-level=none");

require "verse".init("client");

c = verse.new(verse.logger())
c:add_plugin("version");
c:add_plugin("disco");
c:add_plugin("proxy65");
c:add_plugin("jingle");
c:add_plugin("jingle_ft");
c:add_plugin("jingle_s5b");

-- Add some hooks for debugging
c:hook("opened", function () print("Stream opened!") end);
c:hook("closed", function () print("Stream closed!") end);
c:hook("stanza", function (stanza) print("Stanza:", stanza) end, 15);

-- This one prints all received data
--c:hook("incoming-raw", function (...) print("<<", ...) end, 1000);

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
	
	-- Handle incoming Jingle requests
	c:hook("jingle", function (jingle)
		if jingle.content.type == "file" then
			print("File offer from "..jingle.peer.."!");
			print("Filename: "..jingle.content.file.name.." Size: "..jingle.content.file.size);
			jingle:accept({ save_file = jingle.content.file.name..".received" });
		end
	end);
	
	c:send(verse.presence()
		:tag("status"):text("Send me a file!"):up()
		:add_child(c:caps())
	);
end);

print("Starting loop...")
verse.loop()
