-- Registry for runtime-built reverse indexes. Each index is built once per session, lazily,
-- as a Scheduler job, from public provider APIs only. Nothing here is shipped with the addon.
local _, ns = ...

local Index = { builders = {}, data = {}, state = {}, waiters = {} }
ns.Index = Index

--- Register a builder. `build()` runs inside a coroutine (yield freely) and returns the
--- index table, or nil when its provider is unavailable.
function Index.Register(name, build)
    Index.builders[name] = build
    Index.state[name] = "none"
end

function Index.Get(name)
    return Index.state[name] == "ready" and Index.data[name] or nil
end

function Index.IsReady(name)
    local s = Index.state[name]
    return s == "ready" or s == "failed"
end

local function settle(name, ok, result)
    Index.state[name] = ok and "ready" or "failed"
    Index.data[name] = ok and result or nil
    local waiters = Index.waiters[name] or {}
    Index.waiters[name] = nil
    for _, fn in ipairs(waiters) do fn() end
end

local function start(name)
    Index.state[name] = "building"
    ns.Scheduler.Run("index:" .. name, Index.builders[name], function(ok, result) settle(name, ok, result) end)
end

--- Ensure every index in `names` is built, then call `callback()`. Calls back immediately
--- (synchronously) when all are already settled. Returns true if it had to wait.
function Index.Ensure(names, callback)
    local pending = 0
    local function one()
        pending = pending - 1
        if pending == 0 and callback then callback() end
    end
    for _, name in ipairs(names) do
        if not Index.IsReady(name) then
            pending = pending + 1
            Index.waiters[name] = Index.waiters[name] or {}
            table.insert(Index.waiters[name], one)
            if Index.state[name] == "none" then start(name) end
        end
    end
    if pending == 0 then
        if callback then callback() end
        return false
    end
    return true
end
