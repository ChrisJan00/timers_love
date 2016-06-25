local Timer_proto = {
    -- function cb()
    andThen = function(self, cb)
        if self.callback then
            local func = self.callback
            self.callback = function()
                func()
                cb()
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
            self.update = function(elapsed)
                func(elapsed)
                upd(elapsed)
            end
        else
            self.update = upd
        end
        return self
    end,

    thenWait = function(self, T)
        local newTimer = Timers.create(T)
        newTimer.origin = self.origin
        self:andThen(function()
            newTimer.control = { elapsed = 0 }
            table.insert(Timers.list, newTimer)
        end)
        return newTimer
    end,

    start = function(self)
        self:cancel()
        self.origin.control = { elapsed = 0 }
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

    -- you can't clone a timer and get access to the whole tail
    -- because the tail is stored in the closures of the callbacks
    -- but you can get a timer-chain that behaves like the original
    -- but it's detached, so that it can run in parallel to it
    cloneBase = function(self)
        local newBase = Timers.create(self.origin.timeout)
        newBase.update = self.origin.update
        newBase.callback = self.origin.callback
        return newBase
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
            control = { elapsed = 0 },
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
                t.control.elapsed = t.control.elapsed + dt
                if t.update then
                    t.update(t.control.elapsed)
                end

                if t.control.elapsed >= t.timeout then
                    if t.callback then
                        t.callback()
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