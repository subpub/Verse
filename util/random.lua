-- Prosody IM
-- Copyright (C) 2008-2014 Matthew Wild
-- Copyright (C) 2008-2014 Waqas Hussain
--
-- This project is MIT/X11 licensed. Please see the
-- COPYING file in the source package for more information.
--

local urandom = io.open("/dev/urandom", "r");

if urandom then
	return {
		seed = function () end;
		bytes = function (n) return urandom:read(n); end
	};
end

local crypto = require "crypto"
return crypto.rand;
