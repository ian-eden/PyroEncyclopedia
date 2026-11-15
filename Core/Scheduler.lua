-- Runs long jobs (index builds) as coroutines inside a per-frame time budget, so a full
-- database scan never freezes the game. Job bodies call coroutine.yield() every few hundred
-- iterations; the scheduler resumes them until the frame's budget is spent.
local _, ns = ...

local Scheduler = { jobs = {}, budgetMs = 6 }
ns.Scheduler = Scheduler

local frame = CreateFrame("Frame")
frame:Hide()

local function finish(job, ok, result)
    if job.onDone then
        local cbOk, err = pcall(job.onDone, ok, result)
        if not cbOk then geterrorhandler()(err) end
    end
end

frame:SetScript("OnUpdate", function(self)
    local deadline = debugprofilestop() + Scheduler.budgetMs
    while Scheduler.jobs[1] and debugprofilestop() < deadline do
        local job = Scheduler.jobs[1]
        local ok, result = coroutine.resume(job.co)
        if not ok then
            table.remove(Scheduler.jobs, 1)
            geterrorhandler()(("PyroEncyclopedia job '%s' failed: %s"):format(job.name, tostring(result)))
            finish(job, false, result)
        elseif coroutine.status(job.co) == "dead" then
            table.remove(Scheduler.jobs, 1)
            finish(job, true, result)
        end
    end
    if not Scheduler.jobs[1] then self:Hide() end
end)

--- Queue `fn` as a job. `onDone(ok, resultOrError)` runs when it finishes.
function Scheduler.Run(name, fn, onDone)
    Scheduler.jobs[#Scheduler.jobs + 1] = { name = name, co = coroutine.create(fn), onDone = onDone }
    frame:Show()
end
