
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

-- begin local
local function _newInstance()
    local Timers

    local _rebuild_draw_list, _append_internal_data, _purge, _launch_immediates
    local _timers_busy = false
    local _delayed_commands = {}

    local function _bubble_origin(timer)
        -- recurse through tree until we find an origin that points to itself
        -- note: assuming that origin will always end up being a self-reference
        -- no nils, no crossed-references
        while timer.origin ~= timer.origin.origin do
            timer.origin = timer.origin.origin
        end
        return timer.origin
    end

    local function _clone_callbacks(timer)
        local copy = Timers.create(timer.timeout)
        copy.init = timer.init
        copy.update = timer.update
        copy.callback = timer.callback
        copy.draw = timer.draw
        return copy
    end

    local function _clone_self_new_orig(timer)
        local copy = _clone_callbacks(timer)
        copy.origin.data = timer.origin.data
        copy.origin._data = timer.origin._data
        return copy
    end

    local function _clone_timer(timer)
        local copy = _clone_callbacks(timer)
        copy.origin = timer.origin
        return copy
    end

    local function _append_internal_data(timer, _data)
        _bubble_origin(timer)
        if not timer.origin._data then
            timer.origin._data = _data
        else
            -- append
            for k,v in pairs(_data) do
                timer.origin._data[k] = v
            end
        end
        return timer
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
            _bubble_origin(self)
            _append_internal_data(self, {_draworder = draworder})
            self.origin._dirty = true
            return self
        end,

        finally = function(self, fin)
            _bubble_origin(self)
            if fin ~= self.origin.final then
                if self.origin.final then
                    local func = self.origin.final
                    self.origin.final = function(cancelled, timer)
                        func(cancelled, timer)
                        fin(cancelled, timer)
                    end
                else
                    self.origin.final = function(cancelled,timer)
                        fin(cancelled, timer)
                    end
                end
            end
            return self
        end,

        thenWait = function(self, T)
            local newTimer = Timers.create(T)
            return self:hang(newTimer)
        end,

        followWith = function(self, T)
            local newRoot = Timers.create(T)
            self:finally(function(cancelled)
                if not cancelled then
                    newRoot:start()
                end
            end)
            return newRoot
        end,

        observe = function(self, tree)
            if tree ~= _bubble_origin(self) then
                self.observed = tree and _bubble_origin(tree) or nil
            end
            return self
        end,

        thenRestart = function(self)
            self:hang(_bubble_origin(self))
            return self
        end,

        thenRestartLast = function(self)
            self:hang(self)
            return self
        end,

        loopNTimes = function(self, times)
            if times <= 1 then
                return self
            end

            _bubble_origin(self)

            local tail = Timers.immediate()
            tail.callback = self.callback
            local ghost = _clone_timer(self)
            ghost:hang(tail)

            self:hang(self.origin)
            local _loopCount = times
            local recurse = self.callback
            self.callback = function(timer)
                _loopCount = _loopCount - 1
                if _loopCount > 0 then
                    recurse(timer)
                else
					-- passed timer will be self (despite calling the 'ghost' one)
                    ghost.callback(timer)
                end
            end

            return tail
        end,

        hang = function(self, newTimer)
            _bubble_origin(self)
            _bubble_origin(newTimer)
            _append_internal_data(self, newTimer.origin._data)
            if newTimer.origin.data then
                if self.origin.data then
                    -- if I already had data, append new one
                    self:appendData(newTimer.origin.data)
                else
                    -- else just pass the reference
                    self:withData(newTimer.origin.data)
                end
            end
            -- pass the finally clause
            if newTimer.origin.final then
                self:finally(newTimer.origin.final)
            end

            newTimer.origin = self.origin
            self:andThen(function(timer)
                local launched = _clone_callbacks(newTimer)
                launched.origin = _bubble_origin(timer)
                if launched.init then launched:init() end
                if launched.timeout < 0 then
                    table.insert(Timers.immediateList, launched)
                else
                    table.insert(Timers.list, launched)
                    launched.origin._running = launched.origin._running + 1
                    _rebuild_draw_list()
                end
            end)
            return newTimer
        end,

        append = function(self, newTimer)
            self:hang(newTimer:ref())
            newTimer.origin = _bubble_origin(self)
            return newTimer
        end,

        start = function(self)
            if _timers_busy then
                -- mark as started (will be overwritten at actual start)
                self.origin._running = self.origin._running + 1
                table.insert(_delayed_commands, function() self:start() end)
                return self
            end
            _bubble_origin(self)
            if self.origin._running > 0 then
                self.origin._running = 0
                _purge()
            end
            self.origin.elapsed = 0
            if self.origin.init then self.origin:init() end
            if self.origin.timeout<0 then
                table.insert(Timers.immediateList, self.origin)
            else
                table.insert(Timers.list, self.origin)
                self.origin._running = 1
                _rebuild_draw_list()
            end
            return self
        end,

        cancel = function(self)
            _bubble_origin(self)
            self.origin._running = 0
            if _timers_busy then
                table.insert(_delayed_commands, function() self:cancel() end)
                return self
            end
            if self.origin.final then
                self.origin.final(true, self)
            end
            _purge()
            _rebuild_draw_list()
            return self
        end,

        pause = function(self)
            _bubble_origin(self).paused = true
            return self
        end,

        continue = function(self)
            _bubble_origin(self).paused = false
            return self
        end,

        isPaused = function(self)
            return _bubble_origin(self).paused
        end,

        isRunning = function(self)
            return _bubble_origin(self)._running > 0
        end,

        withTimeout = function(self, t)
            self.timeout = t
            return self
        end,

        withData = function(self, data)
            _bubble_origin(self).data = data
            return self
        end,

        appendData = function(self, data)
            _bubble_origin(self)
            self.origin.data = self.origin.data or {}
            -- note: duplicated keys will be overwritten, also indices in array part
            for k,v in pairs(data) do
                self.origin.data[k] = v
            end
            return self
        end,

        getData = function(self)
            return _bubble_origin(self).data
        end,

        fork = function(self)
            _bubble_origin(self)
            return _clone_self_new_orig(self.origin)
        end,

        ref = function(self)
            return _bubble_origin(self)
        end
    }

    _rebuild_draw_list = function()
        Timers.drawList = {}
        for i=1,#Timers.list do
            local t = Timers.list[i]
            if t.draw and _bubble_origin(t)._running > 0 then
                -- overwrite origin for speeding up the sorting (so that it doesn't need to check reference validity all the time)
                table.insert(Timers.drawList, t)
            end
        end

        table.sort(Timers.drawList,
            function(a,b) return a.origin._data._draworder < b.origin._data._draworder end)
    end

    _purge = function()
        if _timers_busy then return end
        for i=#Timers.list,1,-1 do
            if _bubble_origin(Timers.list[i])._running == 0 then
                table.remove(Timers.list, i)
            end
        end
    end

    _launch_immediates = function()
        -- default: 20 iterations of immediates launching other immediates
        -- usually it should be all solved in a single iteration, but a loop might be there
        -- in that case, I am breaking it and continue the loop on the next iteration
        -- (although it would be better to hard-break here...)
        local _iteration_count = 20
        while #Timers.immediateList > 0 and _iteration_count > 0 do
            _iteration_count = _iteration_count - 1
            local list = Timers.immediateList
            Timers.immediateList = {}

            for _,t in ipairs(list) do
                -- execute immediate
                if t.callback then
                    t.callback(t)
                elseif _bubble_origin(t).final then
                    t.origin.final(false, t)
                end
            end
        end
    end

    Timers = {
        -- create a new timer object
        create = function(timeout, orself)
            if timeout == Timers then timeout = orself end
            local newTimer = {
                elapsed = 0 ,
                timeout = timeout or 0,
            }
            setmetatable(newTimer, { __index = function(table, key) return Timer_proto[key] end })
            newTimer.origin = newTimer
            newTimer.origin._running = 0
            return newTimer
        end,

        immediate = function()
            return Timers.create(-1)
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
                local t = Timers.list[i]
                _bubble_origin(t)._running = 0
                if t.final then t.final(true, t) end
            end
            Timers.list = {}
            _rebuild_draw_list()
        end,


        -- general update (must be called from love.update)
        update = function(dt, orself)
            if dt == Timers then dt = orself end
            if Timers.paused then return end
            _timers_busy = true
            _launch_immediates()

            local _dead_timer_indices = {}
            local _dirty = false
            local i
            local l = Timers.list
            -- reverse order because new timers spawned by callbacks
            -- are appended to the list and should not be executed in this iteration
            for i=#l,1,-1 do
                local t = l[i]
                _bubble_origin(t)
                if t.origin._running == 0 then
                    table.insert(_dead_timer_indices, i)
                elseif not t.origin.paused then
                    t.elapsed = t.elapsed + dt
                    if t.update then
                        t.update(t.elapsed, t)
                    end

                    if t.observed then
                        -- artificially inflate obersvers's life
                        t.timeout = t.elapsed + t.observed.origin._running
                    end

                    if t.elapsed >= t.timeout then
                        t.origin._running = t.origin._running - 1
                        if t.callback then
                            t.callback(t)
                        end
                        table.insert(_dead_timer_indices, i)
                        _dirty = true
                    end
                end

                if t.origin._dirty then
                    t.origin._dirty = nil
                    _dirty = true
                end
            end

            if #_dead_timer_indices > 0 then
                local _resolved_trees = {}
                for i=1,#_dead_timer_indices do
                    local t = table.remove(l, _dead_timer_indices[i])
                    _bubble_origin(t)
                    if t.origin.final
                        and t.origin._running == 0
                        and not _resolved_trees[t.origin] then
                            _resolved_trees[t.origin] = true
                            t.origin.final(false, t)
                    end
                end
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

        newInstance = _newInstance
    }

    -- convenience function
    Timers.setTimeout = function(func, time, orself)
        if func == Timers then
            func = time
            time = orself
        end
        return Timers.create(time):andThen(func):start()
    end


    local _init = function()
        Timers.list = {}
        Timers.drawList = {}
        Timers.immediateList = {}
        Timers.paused = false
        return Timers
    end

    return _init()

end

-- global default
Timers = _newInstance()
return Timers