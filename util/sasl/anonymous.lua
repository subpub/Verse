
return function (stream, mechanisms, preference)
	mechanisms["ANONYMOUS"] = function ()
		return coroutine.yield() == "success";
	end;
	preference["ANONYMOUS"] = 0;
end

