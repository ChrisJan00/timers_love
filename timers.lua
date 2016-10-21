
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
local function clone_self_orig(timer)
    local copy = Timers.create(timer.timeout)
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

    hang = function(self, newTimer)
        newTimer.origin = self.origin
        self:andThen(function(timer)
            local launched = clone_self_orig(newTimer)
            launched.origin = timer.origin
            if launched.init then launched:init() end
            table.insert(Timers.list, launched)
            _rebuild_draw_list()
        end)
        return newTimer
    end,

    start = function(self)
        self:cancel()
        self.origin.elapsed = 0
        if self.origin.init then self.origin:init() end
        table.insert(Timers.list, self.origin)
        _rebuild_draw_list()
        return self
    end,

    cancel = function(self)
        for i=1,#Timers.list do
            if Timers.list[i].origin == self.origin then
                table.remove(Timers.list, i)
                _rebuild_draw_list()
                return self
            end
        end
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
        if t.draw then
            table.insert(Timers.drawList, t)
        end
    end

    table.sort(Timers.drawList,
        function(a,b) return a.origin.draworder < b.origin.draworder end)
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
        _rebuild_draw_list()
    end,


    -- general update (must be called from love.update)
    update = function(dt)
        if Timers.paused then return end

        local _dirty = false
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
                    _dirty = true
                end
            end

            if t.origin._dirty then
                t.origin._dirty = nil
                _dirty = true
            end
        end

        if _dirty then
            _rebuild_draw_list()
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