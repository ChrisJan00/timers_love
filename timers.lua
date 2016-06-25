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
        local newTimer = Timers.create(T, self.name)
        newTimer.origin = self.origin
        self:andThen(function()
            newTimer.elapsed = 0
            table.insert(Timers.list, newTimer)
        end)
        return newTimer
    end,

    start = function(self)
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

    withName = function(self, name)
        self.origin.name = name
        return self
    end,

    withTimeout = function(self, t)
        self.limit = t
        return self
    end,

    -- clone as-is is dangerous: there's shallow copies of stuff embedded, when they were
    -- supposed to be all deep copies. I would have to recurse
    -- clone = function(self)
    --     local newTimer = Timers.create(self.name, self.timeout)
    --     newTimer.update = self.update
    --     newTimer.callback = self.callback
    --     newTimer.origin = self.origin
    --     return newTimer
    -- end,

    ref = function(self)
        return self.origin
    end
}

local Timer_mt = {
    __index = function(table, key) return Timer_proto[key] end
}

-- possible inputs:
-- the "string" parameter will be taken as name, the "number" parameter will be taken as timeout
-- Timers.create(name, timeout)
-- Timers.create(timeout, name)
-- Timers.create(name)
-- Timers.create(timeout)

Timers = {
    -- create a new timer object
    create = function(param1, param2)
        local name = (param1 and type(param1) == 'string' and param1) or (param2 and type(param2) == 'string' and param2)
        local timeout = (param1 and type(param1) == 'number' and param1) or (param2 and type(param2) == 'number' and param2)

        local newTimer = {
            elapsed = 0,
            limit = timeout,
            name = name
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
                    t.update(t.elapsed)
                end

                if t.elapsed >= t.limit then
                    if t.callback then
                        t.callback()
                    end
                    table.remove(l, i)
                end
            end
        end
    end,

    -- get first running timer with matching name
    -- if timer is not running it will now show
    get = function(name)
        local i
        local l = Timers.list

        for i=1,#l do
            if l[i].origin.name == name then return l[i] end
        end
        return nil
    end,

    -- cancel all running timers with matching name
    cancelNamed = function(name)
        local i
        local l = Timers.list

        for i=#l,1,-1 do
            if l[i].origin.name == name then
                table.remove(l,i)
            end
        end
    end,

    -- pause all timers with matching name
    pauseNamed = function(name)
        local i
        local l = Timers.list

        for i=1,#l do
            if l[i].origin.name == name then
                l[i]:pause()
            end
        end
    end,

    -- continue all timers with matching name
    continueNamed = function(name)
        local i
        local l = Timers.list

        for i=1,#l do
            if l[i].origin.name == name then
                l[i]:continue()
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