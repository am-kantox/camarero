counter = 0

request = function()
  wrk.method = "GET"
  wrk.headers["Content-Type"] = "application/json"
  wrk.path = "/api/v1/crud/foo" .. counter
  counter = counter + 1
  return wrk.format(nil, path)
end
