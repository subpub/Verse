local print = print
module "logger"

function init(name)
	return function (level, message)
		print(level, message);
	end
end

return _M;
