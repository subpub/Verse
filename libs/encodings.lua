local function not_impl()
	error("Function not implemented");
end

local mime = require "mime";

module "encodings"

stringprep = {};
base64 = { encode = mime.b64, decode = mime.unb64 };

return _M;
