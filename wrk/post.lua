counter = 0

request = function()
  wrk.method = "POST"
  wrk.headers["Content-Type"] = "application/json"
  wrk.body = "{\"key\":\"foo" .. counter .. "\",\"value\":\"" .. counter .. "\"}"
  counter = counter + 1
  return wrk.format(nil, path)
end
