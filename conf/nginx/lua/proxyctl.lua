-- Debug pring helper
local function dpr(message)
    if (tonumber(os.getenv("DEBUG_LOG")) > 0) then
        ngx.log(ngx.STDERR, "DEBUG: " .. message)
    end
end

-- Helper function to read a file from disk
local function read_file(path)
    local open = io.open
    local file = open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

-- Only allow letters, digits, hyphens, and periods in host name
local function safe_host(str)
    return string.gsub(str, "[^%a%d%-%.]", "")
end

-- Returns loading.html for HTTP_OK and not-found.html otherwise
local function response(status)
    -- Load response body from disk
    -- This used to be done with ngx.location.capture, which does not support HTTP/2 and fails with https requests:
    -- See https://github.com/openresty/lua-nginx-module/issues/1285#issuecomment-376418678
    -- While direct file operations may be inefficient, they won't happen often, so this should be fine.
    -- An alternative option would be to use lua-resty-http to replace ngx.location.capture for subrequests.
    local response_body
    if (status == ngx.HTTP_ACCEPTED) then
        response_body = read_file('/var/www/202.html')
    else
        response_body = read_file('/var/www/404.html')
    end

    ngx.header["Content-Type"] = 'text/html'
    ngx.status = status -- Set the status before printing anything
    ngx.print(response_body)

    -- Unlock host before exiting
    local host = safe_host(ngx.var.host)
    dpr("Unlocking " .. host)
    ngx.shared.hosts:delete(host)

    return ngx.exit(status)
end

-- Get the host lock timestamp
local host = safe_host(ngx.var.host)
local timestamp = os.time(os.date("!*t"))
local lock_timestamp = ngx.shared.hosts:get(host)

if (lock_timestamp == nil) then lock_timestamp = 0 end
local lock_age = timestamp - lock_timestamp

if (lock_age > 30) then
    -- Break the lock if it is older than 30s
    dpr("Unlocking a stale lock (" .. lock_age .. "s) for " .. host)
    ngx.shared.hosts:delete(host)
end

if (lock_timestamp == 0) then
    -- No lock timestamp = can proceed with project wake up

    dpr("Locking " .. host)
    lock_timestamp = os.time(os.date("!*t"))
    ngx.shared.hosts:set(host, lock_timestamp)

    -- Lanch project start script
    -- os.execute returs multiple values starting with Lua 5.2
    local status, exit, exit_code = os.execute("sudo -E /usr/local/bin/proxyctl start $(sudo /usr/local/bin/proxyctl lookup \"" .. ngx.var.host .. "\")")

    if (exit_code == 0) then
        -- If all went well, reload the page
        dpr("Container start succeeded")
        response(ngx.HTTP_ACCEPTED)
    else
        -- If proxyctl start failed (non-existing environment or something went wrong), return 404
        dpr("Container start failed")
        response(ngx.HTTP_NOT_FOUND)
    end
else
    -- There is an active lock, so skip for now
    dpr(host .. " is locked. Skipping.")
end
