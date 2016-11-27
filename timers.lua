
-- timers_love: a small library for timed events

-- zlib license
-- Copyright (c) 2016 Christiaan Janssen

-- This software is provided 'as-is', without any express or implied
-- warranty. In no event will the authors be held liable for any damages
-- arising from the use of this software.

-- Permission is granted to anyone to use this software for any purpose,
-- including commercial applications, and to alter it and redistribute it
-- freely, subject to the following restrictions:

-- 1. The origin of this software must not be misrepresented; you must not
--    claim that you wrote the original software. If you use this software
--    in a product, an acknowledgement in the product documentation would be
--    appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not be
--    misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source distribution.



local _rebuild_draw_list
local _purge
local _timers_busy = false
local _delayed_commands = {}
local function clone_self_orig(timer)
    local copy = Timers.create(timer.timeout)
    copy.init = timer.init
    copy.update = timer.update
    copy.callback = timer.callback
    copy.origin.data = timer.origin.data
    return copy
end

local Timer_proto = {
    prepare = function(self, pre)
        if self.init then
            local func = self.init
            self.init = function(timer)
                func(timer)
                pre(timer)
            end
        else
            self.init = pre
        end
        return self
    end,

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

    -- function upd()
    withDraw = function(self, draw, draworder)
        if self.draw then
            local func = self.draw
            self.draw = function(timer)
                func(timer)
                draw(timer)
            end
        else
            self.draw = draw
        end

        self:withDrawOrder(draworder or 0)

        return self
    end,

    withDrawOrder = function(self, draworder)
        self.origin.draworder = draworder
        self.origin._dirty = true
        return self
    end,

    thenWait = function(self, T)
        local newTimer = Timers.create(T)
        return self:hang(newTimer)
    end,

    thenRestart = function(self)
        self:hang(self.origin)
        return self
    end,

    thenRestartLast = function(self)
        self:hang(self)
        return self
    end,

    hang = function(self, newTimer)
        -- move data if necessary
        if newTimer.origin.data then
            if not self.origin.data then
                self.origin.data = newTimer.origin.data
            else
                for k,v in pairs(newTimer.origin.data) do
                    self.origin.data[k] = v
                end
            end
        end
        newTimer.origin = self.origin
        self:andThen(function(timer)
            local launched = clone_self_orig(newTimer)
            launched.origin = timer.origin
            if launched.init then launched:init() end
            table.insert(Timers.list, launched)
            launched.origin._running = launched.origin._running + 1
            _rebuild_draw_list()
        end)
        return newTimer
    end,

    append = function(self, newTimer)
        self:hang(newTimer:ref())
        newTimer.origin = self.origin
        return newTimer
    end,

    start = function(self)
        if _timers_busy then
            table.insert(_delayed_commands, function() self:start() end)
            return self
        end
        if self.origin._running > 0 then
            self.origin._running = 0
            _purge()
        end
        self.origin.elapsed = 0
        if self.origin.init then self.origin:init() end
        table.insert(Timers.list, self.origin)
        self.origin._running = 1
        _rebuild_draw_list()
        return self
    end,

    cancel = function(self)
        self.origin._running = 0
        if _timers_busy then
            table.insert(_delayed_commands, function() self:cancel() end)
            return self
        end
        _purge()
        _rebuild_draw_list()
        return self
    end,

    pause = function(self)
        self.origin.paused = true
        return self
    end,

    continue = function(self)
        self.origin.paused = false
        return self
    end,

    isPaused = function(self)
        return self.origin.paused
    end,

    isRunning = function(self)
        return self.origin._running > 0
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

_rebuild_draw_list = function()
    Timers.drawList = {}
    for i=1,#Timers.list do
        local t = Timers.list[i]
        if t.draw and t.origin._running > 0 then
            table.insert(Timers.drawList, t)
        end
    end

    table.sort(Timers.drawList,
        function(a,b) return a.origin.draworder < b.origin.draworder end)
end

_purge = function()
    if _timers_busy then return end
    for i=#Timers.list,1,-1 do
        if Timers.list[i].origin._running == 0 then
            table.remove(Timers.list, i)
        end
    end
end

Timers = {
    -- create a new timer object
    create = function(timeout)
        local newTimer = {
            elapsed = 0 ,
            timeout = timeout or 0,
        }
        setmetatable(newTimer, { __index = function(table, key) return Timer_proto[key] end })
        newTimer.origin = newTimer
        newTimer.origin._running = 0
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
        for i=1,#Timers.list do
            Timers.list[i].origin._running = 0
        end
        Timers.list = {}
        _rebuild_draw_list()
    end,


    -- general update (must be called from love.update)
    update = function(dt)
        if Timers.paused then return end
        _timers_busy = true

        local _dead_timer_indices = {}
        local _dirty = false
        local i
        local l = Timers.list
        for i=#l,1,-1 do
            local t = l[i]
            if t.origin._running == 0 then
                table.insert(_dead_timer_indices, i)
            elseif not t.origin.paused then
                t.elapsed = t.elapsed + dt
                if t.update then
                    t.update(t.elapsed, t)
                end

                if t.elapsed >= t.timeout then
                    t.origin._running = t.origin._running - 1
                    if t.callback then
                        t.callback(t)
                    end
                    -- table.remove(l, i)
                    table.insert(_dead_timer_indices, i)
                    _dirty = true
                end
            end

            if t.origin._dirty then
                t.origin._dirty = nil
                _dirty = true
            end
        end

        for i=1,#_dead_timer_indices do
            table.remove(l, _dead_timer_indices[i])
        end

        if _dirty then
            _rebuild_draw_list()
        end
        _timers_busy = false

        if (#_delayed_commands > 0) then
            for i=1,#_delayed_commands do
                _delayed_commands[i]()
            end
            _delayed_commands = {}
        end
    end,

    draw = function()
        for i=1,#Timers.drawList do
            local t = Timers.drawList[i]
            if t.draw then
                t.draw(t)
            end
        end
    end,
}

-- convenience function
function Timers.setTimeout(func, time)
    return Timers.create(time):andThen(func):start()
end


local function init()
    Timers.list = {}
    Timers.drawList = {}
    Timers.paused = false
    return Timers
end

return init()