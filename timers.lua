local function clone_self_orig(timer)
    local copy = Timers.create(timer.timeout)
    copy.update = timer.update
    copy.callback = timer.callback
    copy.origin.data = timer.origin.data
    return copy
end

local Timer_proto = {
    -- function cb()
    andThen = function(self, cb)
        if self.callback then
            local func = self.callback
            self.callback = function(timer)
                func(timer)
                cb(timer)
            end
        else
            self.callback = cb
        end
        return self
    end,

    -- function upd(elapsed)
    withUpdate = function(self, upd)
        if self.update then
            local func = self.update
            self.update = function(elapsed, timer)
                func(elapsed, timer)
                upd(elapsed, timer)
            end
        else
            self.update = upd
        end
        return self
    end,

    thenWait = function(self, T)
        local newTimer = Timers.create(T)
        newTimer.origin = self.origin
        self:andThen(function(timer)
            local launched = clone_self_orig(newTimer)
            launched.origin = timer.origin
            table.insert(Timers.list, launched)
        end)
        return newTimer
    end,

    start = function(self)
        self:cancel()
        self.origin.elapsed = 0
        table.insert(Timers.list, self.origin)
        return self
    end,

    cancel = function(self)
        for i=1,#Timers.list do
            if Timers.list[i].origin == self.origin then
                table.remove(Timers.list, i)
                return
            end
        end
    end,

    pause = function(self)
        self.origin.paused = true
        return self
    end,

    continue = function(self)
        self.origin.paused = false
        return self
    end,

    ispaused = function(self)
        return self.origin.paused
    end,

    withTimeout = function(self, t)
        self.timeout = t
        return self
    end,

    withData = function(self, data)
        self.origin.data = data
        return self
    end,

    getData = function(self)
        return self.origin.data
    end,

    fork = function(self)
        return clone_self_orig(self.origin)
    end,

    ref = function(self)
        return self.origin
    end
}

local Timer_mt = {
    __index = function(table, key) return Timer_proto[key] end
}

Timers = {
    -- create a new timer object
    create = function(timeout)
        local newTimer = {
            elapsed = 0 ,
            timeout = timeout,
        }
        setmetatable(newTimer,Timer_mt)
        newTimer.origin = newTimer
        return newTimer
    end,

    -- general pause all
    pauseAll = function()
        Timers.paused = true
    end,

    -- general continue all
    continueAll = function()
        Timers.paused = false
    end,

    -- general cancel all
    cancelAll = function()
        Timers.list = {}
    end,


    -- general update (must be called from love.update)
    update = function(dt)
        if Timers.paused then return end

        local i
        local l = Timers.list
        for i=#l,1,-1 do
            local t = l[i]
            if not t.origin.paused then
                t.elapsed = t.elapsed + dt
                if t.update then
                    t.update(t.elapsed, t)
                end

                if t.elapsed >= t.timeout then
                    if t.callback then
                        t.callback(t)
                    end
                    table.remove(l, i)
                end
            end
        end
    end,
}

-- convenience function
function Timers.setTimeout(func, time)
    return Timers.create(time):done(func):start()
end


local function init()
    Timers.list = {}
    Timers.paused = false
    return Timers
end

return init()