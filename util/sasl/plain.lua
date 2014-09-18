
return function (stream, mechanisms, preference)
	if stream.username and stream.password then
		mechanisms["PLAIN"] = function (stream)
			return "success" == coroutine.yield("\0"..stream.username.."\0"..stream.password);
		end;
		preference["PLAIN"] = 5;
	end
end

