local have_luacrypto, crypto = pcall(require, "crypto");

if have_luacrypto then
	local hashes = {};

	local digest = crypto.digest;
	local function gethash(algo)
		return function (string, hex)
			return digest(algo, string, not hex);
		end
	end

	local hmac = crypto.hmac.digest;
	local function gethmac(algo)
		return function (key, message, hex)
			return hmac(algo, message, key, not hex);
		end
	end

	local hash_algos = { "md5", "sha1", "sha256", "sha512" };

	for _, hash_algo in ipairs(hash_algos) do
		hashes[hash_algo] = gethash(hash_algo);
		hashes["hmac_"..hash_algo] = gethmac(hash_algo);
	end

	return hashes;
else
	local sha1 = require"util.sha1".sha1;
	local bxor = require"bit".bxor;

	local s_rep = string.rep;
	local s_char = string.char;
	local s_byte = string.byte;
	local t_concat = table.concat;

	local function hmac_sha1(key, message, hexres)
		if #key > 20 then
			key = sha1(key);
		elseif #key < 20 then
			key = key .. s_rep("\0", 20 - #key);
		end
		local o_key_pad, i_key_pad = {}, {}
		for i = 1, 20 do
			local b = s_byte(key, i)
			o_key_pad[i] = s_char(bxor(b, 0x5c));
			i_key_pad[i] = s_char(bxor(b, 0x36));
		end
		o_key_pad = t_concat(o_key_pad);
		i_key_pad = t_concat(i_key_pad);
		return sha1(o_key_pad .. sha1(i_key_pad .. message), hexres);
	end

	return {
		sha1 = sha1;
		hmac_sha1 = hmac_sha1;
	};
end
