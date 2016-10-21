
-- Test suite for the timers library

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


require 'timers'

local function check(condition)
    if not condition then error(debug.getinfo(2,"l").currentline) end
end

Tests = {
    function()
        -- basic functions of timers
        check(#Timers.list == 0)

        -- empty update without crash
        Timers.update(1)

        -- create 1 timer
        check(#Timers.list == 0)
        local timer1 = Timers.create(1)

        -- not launched
        check(#Timers.list == 0)

        -- launched
        timer1:start()
        check(#Timers.list == 1)

        -- half step
        Timers.update(0.5)
        check(#Timers.list == 1)

        -- full step: timer removed
        Timers.update(0.5)
        check(#Timers.list == 0)
    end,

    function()
        -- pause/continue/cancel in timers
        local timer2 = Timers.create(1):start()

        check(#Timers.list == 1)
        Timers.update(0.5)
        check(#Timers.list == 1)
        Timers.pauseAll()
        Timers.update(2)
        check(#Timers.list == 1)
        Timers.continueAll()
        Timers.update(2)
        check(#Timers.list == 0)

        timer2:start()
        check(#Timers.list == 1)
        Timers.cancelAll()
        check(#Timers.list == 0)

        return true
    end,

    function()
        -- pause/continue/cancel single timer
        local timer3 = Timers.create(1):start()

        check(#Timers.list == 1)
        Timers.update(0.5)
        check(#Timers.list == 1)
        check(not timer3:isPaused())
        timer3:pause()
        check(timer3:isPaused())
        Timers.update(2)
        check(#Timers.list == 1)
        timer3:continue()
        check(not timer3:isPaused())
        Timers.update(2)
        check(#Timers.list == 0)

        timer3:start()
        check(#Timers.list == 1)
        timer3:cancel()
        check(#Timers.list == 0)

        return true
    end,

    function()
        -- complex timer
        local container = { count = 0 }

        local timer4 = Timers.create()
        :withData(container)
        :prepare(function(timer) timer:getData().count = 1 end)
        :withTimeout(1)
        :andThen(function(timer) timer:getData().count = 2 end)
        :thenWait(1)
        :withUpdate(function(t, timer) timer:getData().count = t+3 end)


        check(container.count == 0)
        timer4:start()
        check(container.count == 1)
        Timers.update(0.5)
        check(container.count == 1)
        Timers.update(0.5)
        check(container.count == 2)
        Timers.update(0.5)
        check(container.count == 3.5)
        Timers.update(0.5)
        check(container.count == 4)
        Timers.update(0.5)
        check(container.count == 4)
        check(#Timers.list == 0)
    end,

    function()
        -- parallel timers
        local container = { count = 0 }

        local timer5 = Timers.create()
        :withData(container)
        :withTimeout(1)
        :withUpdate(function(T,timer) timer:getData().count = timer:getData().count + T end)
        :thenWait(1)
        :withUpdate(function(T,timer) timer:getData().count = timer:getData().count + 2 * T end)

        local timer6 = timer5:fork()

        -- single timer with one inactive fork
        check(container.count == 0)
        timer5:start()
        check(container.count == 0)
        Timers.update(1)
        check(container.count == 1)
        Timers.update(1)
        check(container.count == 3)

        -- two timers, forked, referring to same data
        Timers.cancelAll()
        container.count = 0
        check(container.count == 0)
        timer5:start()
        timer6:start()

        Timers.update(1)
        check(container.count == 2)
        Timers.update(1)
        check(container.count == 6)

        -- two timers, forked, referring to different data, only one is running
        local container2 = { count = 0 }
        timer6:withData(container2)
        container.count = 0
        Timers.cancelAll()
        check(container.count == 0)
        check(container2.count == 0)

        timer5:start()

        Timers.update(1)
        check(container.count == 1)
        check(container2.count == 0)
        Timers.update(1)
        check(container.count == 3)
        check(container2.count == 0)

        -- two timers, forked, referring to different data, the other one is running
        container2.count = 0
        container.count = 0
        Timers.cancelAll()
        check(container.count == 0)
        check(container2.count == 0)

        timer6:start()

        Timers.update(1)
        check(container.count == 0)
        check(container2.count == 1)
        Timers.update(1)
        check(container.count == 0)
        check(container2.count == 3)

        -- two timers, forked, referring to different data
        container2.count = 0
        container.count = 0
        Timers.cancelAll()
        check(container.count == 0)
        check(container2.count == 0)

        timer5:start()
        timer6:start()

        Timers.update(1)
        check(container.count == 1)
        check(container2.count == 1)
        Timers.update(1)
        check(container.count == 3)
        check(container2.count == 3)

        Timers.cancelAll()
    end,

    function()
        -- basic fork
        local container = { count = 0 }

        local timer7 = Timers.create(2)
        :withData(container)
        :withUpdate(function(T, timer) timer:getData().count = timer:getData().count + T end)
        :start()

        -- no fork-> it's just 1 timer, and it's reset
        local timer8 = timer7:start()

        check(container.count == 0)
        Timers.update(1)
        check(container.count == 1)
        Timers.update(1)
        check(container.count == 3)
        Timers.update(1)
        check(container.count == 3)

        -- fork, run-through
        container.count = 0
        Timers.cancelAll()
        timer7:start()
        timer8 = timer7:fork():start()

        check(container.count == 0)
        Timers.update(1)
        check(container.count == 2)
        Timers.update(1)
        check(container.count == 6)
        Timers.update(1)
        check(container.count == 6)

        -- fork, timer7 is resed mid-run while timer8 continues
        container.count = 0
        Timers.cancelAll()
        timer7:start()
        timer8:start()

        check(container.count == 0)
        Timers.update(1)
        check(container.count == 2)
        timer7:start() -- reset
        Timers.update(1)
        check(container.count == 5) -- 2 + 1 (timer7) + 2 (timer8)
        -- timer8 should have expired here
        Timers.update(1)
        check(container.count == 7) -- 5 + 2 (timer7) + 0 (timer8)

        Timers.cancelAll()
    end,

    function()
        -- note: the draw methods are sorted, and default value is 0 for all.

        -- when everything is 0, the sorting function leaves the list untouched,
        -- so they will be drawn in the order of introduction

        -- when everything has a different value, we are forcing our wished order

        -- but when some of them have the same value for order, it is not
        -- guaranteed how they will be sorted (if untouched or inverted)


        local container = { text = "" }
        -- test draw
        local timer9 = Timers.create(1):withData(container):withDraw(function(timer)
                timer:getData().text = timer:getData().text.."A"
            end)
        local timer10 = timer9:fork():withDraw(function(timer)
                timer:getData().text = timer:getData().text.."B"
            end)
        local timer11 = timer9:fork():withDraw(function(timer)
                timer:getData().text = timer:getData().text.."C"
            end)
        local timer12 = Timers.create(1) -- deliverately empty

        -- draw in calling order (because all drawing order is the default, 0)
        -- 11-9-10-12 -> CAB
        timer11:start()
        timer9:start()
        timer10:start()
        timer12:start()
        check(container.text == "")
        Timers.draw()
        check(container.text == "CAB")

        -- one of them has explicit order, the others have default order
        timer11 = timer9:fork():withDraw(function(timer)
                timer:getData().text = timer:getData().text.."D"
            end,2)

        Timers.cancelAll()
        container.text = ""
        timer11:start()
        timer9:start()
        timer10:start()
        timer12:start()
        check(container.text == "")
        Timers.draw()
        check(container.text:sub(3,3) == "D")
        check(container.text:len() == 3)
        -- cannot guarantee that first two characters are "AB" or "BA"


        -- draw in explicit order
        Timers.cancelAll()
        container.text = ""
        timer9:withDrawOrder(4):start()
        timer10:withDrawOrder(3):start()
        timer11:withDrawOrder(2):start()
        timer12:withDrawOrder(1):start()
        check(container.text == "")
        Timers.draw()
        check(container.text == "DBA")

        Timers.cancelAll()

    end,


    function()
        -- testing that update is called only on timeout
        local val = 1
        Timers.setTimeout(function() val = 3 end, 1)

        check(#Timers.list == 1)
        check(val == 1)
        Timers.update(0.5)
        check(val == 1)
        Timers.update(0.5)
        check(val == 3)
        check(#Timers.list == 0)

    end,

    function()
        -- multiple inits+draws+updates per step
        local val=0
        local timer13 = Timers.create(1)
            :prepare(function() val = val + 1 end)
            :prepare(function() val = val + 2 end)

        check(val == 0)
        timer13:start()
        check(val == 3)
        Timers.update(1)
        check(val == 3)
        Timers.draw()
        check(val == 3)

        local timer14 = Timers.create(1)
            :withUpdate(function(dt) val = val + 4 end)
            :withUpdate(function(dt) val = val + 8 end)

        check(val == 3)
        timer14:start()
        check(val == 3)
        Timers.update(1)
        check(val == 15)
        Timers.draw()
        check(val == 15)

        local timer15 = Timers.create(1)
            :withDraw(function() val = val + 16 end)
            :withDraw(function() val = val + 32 end)
        check(val == 15)
        timer15:start()
        check(val == 15)
        Timers.draw()
        check(val == 63)
        Timers.update(1)

        check(#Timers.list == 0)
    end,

    function()
        -- test reference
        local timer16 = Timers.create():withData({id = 16})
        local timer17 = Timers.create():withData({id = 17})

        check(timer16.data.id == 16)
        check(timer17.data.id == 17)

        timer16:hang(timer17)

        check(timer16.data.id == 16)
        check(timer17.data.id == 17)
        check(timer16:ref().data.id == 16)
        check(timer17:ref().data.id == 16)

        check(timer16:getData().id == 16)
        check(timer17:getData().id == 16)
    end
}


for i,test in ipairs(Tests) do
    io.write("Test "..i.."...")
    local passed,err = pcall(test)
    print(passed and "OK" or "failed at "..err)
end