
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
    if not condition then
        local debugInfo = debug.getinfo(2,"Sl")
        print("failed check at "..debugInfo.source..":"..debugInfo.currentline)
        error(false)
    end
end

local function compare(value, expected)
    if value ~= expected then
        local debugInfo = debug.getinfo(2,"Sl")
        print("failed compare at "..debugInfo.source..":"..debugInfo.currentline..": "..tostring(value).." ~= "..tostring(expected))
        error(false)
    end
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
        local timer9 = Timers.create(1):withData(container)
        local timer10 = timer9:fork():withDraw(function(timer)
                timer:getData().text = timer:getData().text.."B"
            end)
        local timer11 = timer9:fork():withDraw(function(timer)
                timer:getData().text = timer:getData().text.."C"
            end)
        local timer12 = Timers.create(1) -- deliverately empty

        -- appending draw after the forks have been declared
        -- because the "draw" functions are accumulated across clones, not replaced
        timer9:withDraw(function(timer)
                timer:getData().text = timer:getData().text.."A"
            end)

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
        timer11 = Timers.create(1):withData(container):withDraw(function(timer)
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
        local timer16 = Timers.create()
        local timer17 = Timers.create()

        timer16.extra_field = 16
        timer17.extra_field = 17

        check(timer16.extra_field == 16)
        check(timer17.extra_field == 17)
        check(timer16:ref().extra_field == 16)
        check(timer17:ref().extra_field == 17)

        timer16:hang(timer17)

        check(timer16.extra_field == 16)
        check(timer17.extra_field == 17)
        check(timer16:ref().extra_field == 16)
        check(timer17:ref().extra_field == 16)

    end,

    function()
        -- test restart
        local inc_func = function(timer) timer:getData().iter = timer:getData().iter + 1 end
        local inc_double = function(timer) timer:getData().iter = timer:getData().iter + 2 end

        local d_repeat = { iter = 1 }
        local timer18 = Timers.create(1):withData(d_repeat):andThen(inc_func):thenRestart()

        timer18:start()

        check(d_repeat.iter == 1)
        Timers.update(0.5)
        check(d_repeat.iter == 1)
        Timers.update(0.5)
        check(d_repeat.iter == 2)
        Timers.update(1)
        check(d_repeat.iter == 3)
        Timers.update(1)
        check(d_repeat.iter == 4)
        timer18:cancel()
        Timers.update(1)
        check(d_repeat.iter == 4)

        -- test no-restart by accident (as I implemented restart, make sure that it only happens when called)

        local d_norepeat = { iter = 1 }
        local timer19 = Timers.create(1):withData(d_norepeat):andThen(inc_func)

        timer19:start()

        check(d_repeat.iter == 4)
        check(d_norepeat.iter == 1)
        Timers.update(0.5)
        check(d_repeat.iter == 4)
        check(d_norepeat.iter == 1)
        Timers.update(0.5)
        check(d_repeat.iter == 4)
        check(d_norepeat.iter == 2)
        Timers.update(1)
        check(d_repeat.iter == 4)
        check(d_norepeat.iter == 2)
        Timers.update(1)
        check(d_repeat.iter == 4)
        check(d_norepeat.iter == 2)

        -- test restart leaf instead of origin
        -- (for example, an animation with an "intro" and then a loop afterwards)

        local d_intro = { iter = 1 }
        local timer20 = Timers.create(1):withData(d_intro):andThen(inc_func)
            :thenWait(1):andThen(inc_double)
            :thenRestartLast()

        timer20:start()

        check(d_intro.iter == 1)
        Timers.update(1)
        check(d_intro.iter == 2)
        Timers.update(1)
        check(d_intro.iter == 4)
        Timers.update(1)
        check(d_intro.iter == 6)
        Timers.update(1)
        check(d_intro.iter == 8)
        timer20:cancel()
        Timers.update(1)
        check(d_intro.iter == 8)

        local d_full_tree = { iter = 1 }
        local timer21 = Timers.create(1):withData(d_full_tree):andThen(inc_func)
            :thenWait(1):andThen(inc_double)
            :thenRestart()

        timer21:start()

        check(d_full_tree.iter == 1)
        Timers.update(1)
        check(d_full_tree.iter == 2)
        Timers.update(1)
        check(d_full_tree.iter == 4)
        Timers.update(1)
        check(d_full_tree.iter == 5)
        Timers.update(1)
        check(d_full_tree.iter == 7)
        Timers.update(1)
        check(d_full_tree.iter == 8)
        timer21:cancel()
        Timers.update(1)
        check(d_full_tree.iter == 8)
        Timers.update(1)
        check(d_full_tree.iter == 8)

    end,

    function()
        -- test "running" property

        local timer22 = Timers.create(1):thenWait(1)

        check(timer22:isRunning() == false)
        timer22:start()
        check(timer22:isRunning() == true)
        Timers.update(0.5)
        check(timer22:isRunning() == true)
        Timers.update(0.5)
        check(timer22:isRunning() == true)
        Timers.update(0.5)
        check(timer22:isRunning() == true)
        Timers.update(0.5)
        check(timer22:isRunning() == false)

    end,

    function()
        -- regression test (setting prepare WITHOUT data)
        local test_data = { a = 1 }
        local a1 = Timers.create(2)
            :prepare(function(timer) test_data.a = 2 end)
            :andThen(function(timer) test_data.a = 5 end)
        local a2 = Timers.create(2)
            :andThen(function(timer) test_data.a = 7 end)

        local tree = Timers.create()
        tree:hang(a1)
        tree:thenWait(1):hang(a2)

        check(test_data.a == 1)

        tree:start()

        -- the root doesn't have an init
        check(test_data.a == 1)

        -- launch first animation, will trigger its init
        Timers.update(0)
        check(test_data.a == 2)

        -- continue first animation
        Timers.update(1)
        check(test_data.a == 2)

        -- finish first animation, will trigger its end
        Timers.update(1)
        check(test_data.a == 5)

        -- finish second animation, will trigger its end
        Timers.update(1)
        check(test_data.a == 7)
    end,

    function()
        -- regression test (setting prepare with data)
        local test_data = { a = 1 }
        local a1 = Timers.create(2):withData(test_data)
            :prepare(function(timer) timer:getData().a = 2 end)
            :andThen(function(timer) timer:getData().a = 5 end)
        local a2 = Timers.create(2):withData(test_data)
            :andThen(function(timer) timer:getData().a = 7 end)

        local tree = Timers.create()
        tree:hang(a1)
        tree:thenWait(1):hang(a2)

        check(test_data.a == 1)

        tree:start()

        -- the root doesn't have an init
        check(test_data.a == 1)

        -- launch first animation, will trigger its init
        Timers.update(0)
        check(test_data.a == 2)

        -- continue first animation
        Timers.update(1)
        check(test_data.a == 2)

        -- finish first animation, will trigger its end
        Timers.update(1)
        check(test_data.a == 5)

        -- finish second animation, will trigger its end
        Timers.update(1)
        check(test_data.a == 7)

    end,

    function()
        -- regression: repeated calls to init in tree
        --  this case passes. restarting external animation from single animation
        local container = { count = 0 }
        Timers.cancelAll()

        local thirdA = Timers.create(1):thenRestart():start()
        local leaf = Timers.create(1):prepare(function()
            container.count = container.count + 1
            thirdA:start()
            end)

        check(container.count == 0)
        leaf:start()
        Timers.update(1)
        check(container.count == 1)
        Timers.cancelAll()
    end,

    function()
        --  this case fails. restarting external animation from single animation in a series (chained, not root)
        -- update: now it's fixed
        local container = { count = 0 }
        Timers.cancelAll()

        local thirdA = Timers.create(1):thenRestart():start()
        local leaf = Timers.create(1):thenWait(1):prepare(function()
            container.count = container.count + 1
            thirdA:start()
            end)

        check(container.count == 0)
        leaf:start()
        Timers.update(1)
        check(container.count == 1)
        Timers.cancelAll()
    end,

    function()
            -- next regression: repeated third
            local container = { count = 0 }
            Timers.cancelAll()

            local thirdA = Timers.create(1):andThen(function() container.count = container.count + 1 end):thenRestart():start()
            local leaf = Timers.create(0):thenWait(0.5):andThen(function()
                thirdA:start()
                end)

            check(container.count == 0)
            Timers.update(1)
            check(container.count == 1)
            Timers.update(1)
            check(container.count == 2)
            leaf:start()
            Timers.update(0) -- launch leaf
            Timers.update(0.5) -- execute leaf: restart third
            check(container.count == 2) -- therefore still 2
            Timers.update(1)
            check(container.count == 3)
            Timers.update(1);
            check(container.count == 4);
            Timers.update(1);
            check(container.count == 5);

            Timers.cancelAll()
    end,

    function()
        -- I have a tree with two leaves running in parallel
        -- I call start
        -- both should restart (single origin)
        Timers.cancelAll()

        local root = Timers.create(1)
        root:thenWait(1)
        root:thenWait(1)



        check(#Timers.list == 0)
        root:start()
        check(#Timers.list == 1)
        Timers.update(1)
        check(#Timers.list == 2)
        root:start()
        check(#Timers.list == 1)
    end,

    function()
        -- withData: should be merged across leaves
        -- leaf accesses root's data
        local root = Timers.create():withData({ a = 1 });
        local leaf = Timers.create();

        check(not leaf:getData());
        check(root:getData().a == 1);
        root:hang(leaf);
        check(root:getData().a == 1);
        check(leaf:getData().a == 1);
    end,

    function()
        -- root gets leaf's data
        local root = Timers.create();
        local leaf = Timers.create():withData({ b = 2 });

        check(not root:getData());
        check(leaf:getData().b == 2);
        root:hang(leaf);
        check(root:getData().b == 2);
        check(leaf:getData().b == 2);
    end,
    function()
        -- root and leaf's data is merged
        local root = Timers.create():withData({ a = 1 });
        local leaf = Timers.create():withData({ b = 2 });

        check(root:getData().a == 1);
        check(not root:getData().b);
        check(leaf:getData().b == 2);
        check(not leaf:getData().a);

        root:hang(leaf);

        check(root:getData().a == 1);
        check(root:getData().b == 2);
        check(leaf:getData().a == 1);
        check(leaf:getData().b == 2);
    end,
    function()
        -- three-way merge
        local root = Timers.create():withData({ a = 1 });
        local leaf1 = Timers.create():withData({ b = 2 });
        local leaf2 = Timers.create():withData({ c = 3 });

        check(root:getData().a == 1);
        check(not root:getData().b);
        check(not root:getData().c);
        check(leaf1:getData().b == 2);
        check(not leaf1:getData().a);
        check(not leaf1:getData().c);
        check(leaf2:getData().c == 3);
        check(not leaf2:getData().a);
        check(not leaf2:getData().b);

        root:hang(leaf1);
        root:hang(leaf2);

        check(root:getData().a == 1);
        check(root:getData().b == 2);
        check(root:getData().c == 3);
        check(leaf1:getData().a == 1);
        check(leaf1:getData().b == 2);
        check(leaf1:getData().c == 3);
        check(leaf2:getData().a == 1);
        check(leaf2:getData().b == 2);
        check(leaf2:getData().c == 3);

    end,
    function()
        -- overwrite duplicated keys (should not be duplicated keys, but I am not checking it...)
        local root = Timers.create():withData({ d = 1 });
        local leaf = Timers.create():withData({ d = 2 });

        check(root:getData().d == 1);
        check(leaf:getData().d == 2);

        root:hang(leaf);

        check(root:getData().d == 2);
        check(leaf:getData().d == 2);
    end,

    function()
        -- more coverage
        Timers.cancelAll()

        -- cancelling a timer in the middle of an update
        local self_interrupt = Timers.create(2)
            :withUpdate(function(elapsed, timer) timer:cancel() end)
            :start()

        check(#Timers.list == 1)
        check(self_interrupt:isRunning() == true)
        Timers.update(1)
        check(#Timers.list == 0)

        -- killing one timer from another
        local victim = Timers.create(2)
        local killer = Timers.create(2)
        :withUpdate(function() victim:cancel() end)

        check(#Timers.list == 0)
        victim:start()
        check(#Timers.list == 1)
        killer:start()
        check(#Timers.list == 2)
        Timers.update(1)
        check(#Timers.list == 1)

        Timers.cancelAll()
    end,

    function()
        Timers.cancelAll()

        -- connect trees
        local data = { d = 0 }
        local tree_A = Timers.create():prepare(function() data.d = 1 end)
        local tree_B = Timers.create(1):withUpdate(function() data.d = 2 end):thenWait(1):withUpdate(function() data.d = 3 end)


        check(data.d == 0)
        tree_A:append(tree_B):start()
        check(data.d == 1)
        Timers.update(0)
        check(data.d == 1)
        Timers.update(1)
        check(data.d == 2)
        Timers.update(1)
        check(data.d == 3)

        Timers.cancelAll()

    end,

    function()
        Timers.cancelAll()

        -- make sure that draw calls are also executed when they only belong to leaves

        local data = { d = 1 }
        local single_Draw = Timers.create(1):withDraw(function() data.d = 2 end)
        local tree_Draw = Timers.create(1):thenWait(1):withDraw(function() data.d = 3 end)

        -- no leaf
        check(data.d == 1)
        single_Draw:start()
        check(data.d == 1)
        Timers.draw()
        Timers.update(1)
        check(data.d == 2)

        -- tree with leaf
        tree_Draw:start()
        Timers.draw()
        check(data.d == 2)
        Timers.update(0.5)
        Timers.draw()
        check(data.d == 2)
        Timers.update(0.5)
        Timers.draw()
        check(data.d == 3)
    end,

    function()

        local loopTimer = Timers.create(1):loopNTimes(3)

        loopTimer:start()
        compare(#Timers.list, 1)
        Timers.update(1)
        compare(#Timers.list, 1)
        Timers.update(1)
        compare(#Timers.list, 1)
        Timers.update(1)
        compare(#Timers.list, 0)
        Timers.update(1)
        compare(#Timers.list, 0)
        Timers.update(1)
        compare(#Timers.list, 0)
        Timers.update(1)
        compare(#Timers.list, 0)
        Timers.update(1)
        compare(#Timers.list, 0)
    end,


    function()
        -- looping N times
        compare(#Timers.list, 0)
        local loopTimer = Timers.create(1):withData({ cnt = 0 }):withUpdate(function(elapsed, timer) timer:getData().cnt = timer:getData().cnt + 1 end):loopNTimes(3)

        compare(loopTimer:getData().cnt, 0)
        loopTimer:start()
        compare(loopTimer:getData().cnt, 0)
        Timers.update(1)
        check(loopTimer:getData().cnt == 1)
        Timers.update(1)
        check(loopTimer:getData().cnt == 2)
        Timers.update(1)
        check(loopTimer:getData().cnt == 3)
        Timers.update(1)
        compare(loopTimer:getData().cnt, 3)
        Timers.update(1)
        check(loopTimer:getData().cnt == 3)
    end,

    function()

        local data = 0
        local spawner = Timers.create(1)
        local first_branch = Timers.create(1):thenWait(1):withDraw(function() data = data + 1 end)
        local second_branch = Timers.create(1):thenWait(1):withDraw(function() data = data + 2 end)

        spawner
            :hang(first_branch:ref())
            :hang(second_branch:ref())

        spawner:start()
        check(data == 0)

        Timers.update(1)
        Timers.draw()
        check(data == 0)

        Timers.update(1)
        Timers.draw()
        check(data == 1)

        Timers.update(1)
        Timers.draw()
        check(data == 3)

        Timers.update(1)
        Timers.draw()
        check(data == 3)

        check(#Timers.list == 0)

    end,

    function()
        -- test withData is reference, but appendData is copy
        local data = { a = 0 }
        local refTimer = Timers.create():withData(data):prepare(function(timer) timer:getData().a = timer:getData().a + 1 end)
        local copyTimer = Timers.create():appendData(data):prepare(function(timer) timer:getData().a = timer:getData().a + 2 end)

        check(data.a == 0)
        check(refTimer:getData().a == 0)
        check(copyTimer:getData().a == 0)
        refTimer:start()
        copyTimer:start()
        check(data.a == 1)
        check(refTimer:getData().a == 1)
        check(copyTimer:getData().a == 2)

    end,

    function()
        -- test appending data as array (elements should be overwritten)

        local arr1 = { 1, 2, 3 }
        local arr2 = { 4, 5 }
        local overwriteTimer = Timers.create():withData(arr1)
        local appendTimer = Timers.create():appendData(arr1)

        check(#overwriteTimer:getData() == 3)
        overwriteTimer:withData(arr2)
        check(#overwriteTimer:getData() == 2)
        for i=1,2 do
            check(overwriteTimer:getData()[i] == i+3)
        end

        check(#appendTimer:getData() == 3)
        appendTimer:appendData(arr2)
        check(#appendTimer:getData() == 3)
        local expected = {4,5,1}
        for i=1,2 do
            check(appendTimer:getData()[i] == expected[i])
        end

    end,

    function()
        -- testing "finally"
        local data = { control = 0 }
        local function incControl() data.control = data.control + 1 end
        -- simple timer, expiration
        local fine1 = Timers.create(2):finally(incControl)

        check(data.control == 0)
        fine1:start()
        check(data.control == 0)
        Timers.update(1)
        check(data.control == 0)
        Timers.update(1)
        check(data.control == 1)
        check(#Timers.list == 0)

        -- reuse simple timer, cancellation (on-timer)
        fine1:start()
        check(data.control == 1)
        Timers.update(1)
        check(data.control == 1)
        fine1:cancel()
        check(data.control == 2)
        check(#Timers.list == 0)

        -- reuse simple timer, cancellation (global)
        fine1:start()
        check(data.control == 2)
        Timers.update(1)
        check(data.control == 2)
        Timers.cancelAll()
        check(data.control == 3)
        check(#Timers.list == 0)
    end,

    function()
        -- simple timer, using passed parameter
        local data = { control = 0 }
        local function incControl() data.control = data.control + 1 end
        local fine2 = Timers.create(2):withData({ d = 0 }):finally(function(cancelled, timer) timer:getData().d = timer:getData().d + 1 end)
        check(fine2:getData().d == 0)
        fine2:start()
        check(fine2:getData().d == 0)
        Timers.update(1)
        check(fine2:getData().d == 0)
        Timers.update(1)
        check(fine2:getData().d == 1)
        check(#Timers.list == 0)

        -- reuse simple timer, cancellation (on-timer)
        fine2:start()
        check(fine2:getData().d == 1)
        Timers.update(1)
        check(fine2:getData().d == 1)
        fine2:cancel()
        check(fine2:getData().d == 2)
        check(#Timers.list == 0)

        -- reuse simple timer, cancellation (global)
        fine2:start()
        check(fine2:getData().d == 2)
        Timers.update(1)
        check(fine2:getData().d == 2)
        Timers.cancelAll()
        check(fine2:getData().d == 3)
        check(#Timers.list == 0)
    end,

    function()
    local data = { control = 0 }
    local function incControl() data.control = data.control + 1 end

        -- timer tree, with finally attached at creation timer
        local fine3 = Timers.create(2):thenWait(2):finally(incControl)

        check(data.control == 0)
        fine3:start()
        check(data.control == 0)
        Timers.update(2)
        check(data.control == 0)
        Timers.update(2)
        check(data.control == 1)
        check(#Timers.list == 0)

        -- cancellation (on-timer), root cancelled
        fine3:start()
        check(data.control == 1)
        Timers.update(1)
        check(data.control == 1)
        fine3:cancel()
        check(data.control == 2)
        check(#Timers.list == 0)

         -- cancellation (on-timer), leaf cancelled
        fine3:start()
        check(data.control == 2)
        Timers.update(3)
        check(data.control == 2)
        fine3:cancel()
        check(data.control == 3)
        check(#Timers.list == 0)

        -- cancellation (global)
        fine3:start()
        check(data.control == 3)
        Timers.update(1)
        check(data.control == 3)
        Timers.cancelAll()
        check(data.control == 4)
        check(#Timers.list == 0)
    end,

    function()
        -- leaf with finally, then attached to tree
        local data = { control = 0 }
        local function incControl() data.control = data.control + 1 end
        local leaf4 = Timers.create(2):finally(incControl)
        local fine4 = Timers.create(2)
        fine4:hang(leaf4)

        check(data.control == 0)
        fine4:start()
        check(data.control == 0)
        Timers.update(2)
        check(data.control == 0)
        Timers.update(2)
        check(data.control == 1)
        check(#Timers.list == 0)

        -- cancellation (on-timer), root cancelled
        fine4:start()
        check(data.control == 1)
        Timers.update(1)
        check(data.control == 1)
        fine4:cancel()
        check(data.control == 2)
        check(#Timers.list == 0)

         -- cancellation (on-timer), leaf cancelled
        fine4:start()
        check(data.control == 2)
        Timers.update(3)
        check(data.control == 2)
        fine4:cancel()
        check(data.control == 3)
        check(#Timers.list == 0)

        -- cancellation (global)
        fine4:start()
        check(data.control == 3)
        Timers.update(1)
        check(data.control == 3)
        Timers.cancelAll()
        check(data.control == 4)
        check(#Timers.list == 0)
    end,

   function()
        -- timer with loop and finally: only gets executed when explicitly cancelled
        -- but not while it's looping
        local data = { control = 0 }
        local function incControl() data.control = data.control + 1 end
        -- first define finally, then loop
        local fine5 = Timers.create(2):finally(incControl):thenRestart()

        check(data.control == 0)
        fine5:start()

        -- several iterations, finally never called
        check(data.control == 0)
        Timers.update(2)
        check(data.control == 0)
        Timers.update(2)
        check(data.control == 0)
        Timers.update(1)
        check(data.control == 0)
        Timers.update(2)
        check(data.control == 0)
        -- explicit cancel
        fine5:cancel()
        check(data.control == 1)

        check(#Timers.list == 0)

        -- first define loop, then finally
        local fine6 = Timers.create(2):thenRestart():finally(incControl)

        data.control = 0
        fine6:start()

        -- several iterations, finally never called
        check(data.control == 0)
        Timers.update(2)
        check(data.control == 0)
        Timers.update(2)
        check(data.control == 0)
        Timers.update(1)
        check(data.control == 0)
        Timers.update(2)
        check(data.control == 0)
        -- explicit cancel
        fine6:cancel()
        check(data.control == 1)

        check(#Timers.list == 0)
    end,

    function()
        -- finite looper with finally
        check(#Timers.list == 0)
        local loopTimer_5 = Timers.create(1):withData({ cnt = 0 }):withUpdate(function(elapsed, timer) timer:getData().cnt = timer:getData().cnt + 1 end):loopNTimes(2)
            :finally(function(cancelled, timer) timer:getData().cnt = timer:getData().cnt + 10 end)

        check(loopTimer_5:getData().cnt == 0)
        loopTimer_5:start()
        check(loopTimer_5:getData().cnt == 0)
        Timers.update(1)
        check(loopTimer_5:getData().cnt == 1)
        Timers.update(1)
        check(loopTimer_5:getData().cnt == 12)
    end,

    function()
        -- branch with callback and finally should execute both!
        local count = 0
        local inc = function() count = count + 1 end
        local two_call = Timers.create():andThen(inc):finally(inc)

        two_call:start()
        check(count == 0)
        Timers.update(1)
        check(count == 2)
    end,

    function()
        -- finally is called at the end of the tree, no matter where it is defined
        local count = 0
        local inc = function() count = count + 1 end
        local final_call = Timers.create(1):finally(inc):thenWait(1):thenWait(1)

        final_call:start()
        check(count == 0)
        Timers.update(1)
        check(count == 0)
        Timers.update(1)
        check(count == 0)
        Timers.update(1)
        check(count == 1)
    end,

    function()
        -- cancelling a tree from a branch while another branch is executing in parallel
        local root = Timers.create()
        root:thenWait(2) -- leaf A
        root:thenWait(2):withUpdate(function(elapsed, timer) if elapsed >= 1 then timer:cancel() end end)

        root:start()
        check(#Timers.list == 1)
        Timers.update(1)
        check(#Timers.list == 2)
        Timers.update(0.5)
        check(#Timers.list == 2)
        Timers.update(0.5)
        check(#Timers.list == 0)

    end,

    function()
        -- immediates
        local count = 0

        -- not immediate: leafs will be spawned in second iteration
        local root_delayed = Timers.create()
        local leaf = Timers.create(2):withUpdate(function() count = count + 1 end)

        root_delayed:hang(leaf)
        root_delayed:hang(leaf)

        check(count == 0)
        root_delayed:start()
        check(count == 0)
        Timers.update(1)
        check(count == 0)
        Timers.update(1)
        check(count == 2)
        Timers.cancelAll()

        count = 0
        local root_immediate = Timers.immediate()
        root_immediate:hang(leaf)
        root_immediate:hang(leaf)

        check(count == 0)
        root_immediate:start()
        check(count == 0)
        Timers.update(1)
        check(count == 2)
        Timers.update(1)
        check(count == 4)

        Timers.cancelAll()
    end,

    function()
        -- prevent infinite loops

        -- convenience code for breaking infinite loops
        local currentHook_f,currentHook_m,currentHook_c = debug.gethook() -- luacov relies on hooks, we need this info to restore them
        local executionLimit = 1e4
        local executionCount = executionLimit
        local hook = function()
            -- clean hook
            executionCount = executionCount - 1
            if executionCount <= 0 then
                debug.sethook(currentHook_f,currentHook_m,currentHook_c)
                local debugInfo = debug.getinfo(2,"Sl")
                print("timed out at "..debugInfo.source..":"..debugInfo.currentline)
                error()
            end
        end


        -- regular empty timer -> should not iterate on update
        local recur_zero = Timers.create():thenRestart()
        recur_zero:start()

        -- calling update: if there is an infinite loop, test will stop here
        debug.sethook(hook, "l")
        Timers.update(1)
        debug.sethook(currentHook_f,currentHook_m,currentHook_c)
        recur_zero:cancel()

        -- immediate timer -> should break the loop after a reasonable time
        local recur_imm = Timers.immediate():thenRestart()
        recur_imm:start()
        debug.sethook(hook, "l")
        Timers.update(1)
        debug.sethook(currentHook_f,currentHook_m,currentHook_c)
        recur_imm:cancel()
    end,

    function()
        -- coverage: immediate with final
        local test_val = 0
        local final_immediate = Timers.immediate():finally(function() test_val = 1 end)

        check(test_val == 0)
        final_immediate:start()
        check(test_val == 0)
        Timers.update(1)
        check(test_val == 1)
    end,

    function()
        -- prepare is local to a timer, not to a tree
        local count = 0
        local inc = function() count = count + 1 end
        local prepare_tree = Timers.create(2):prepare(inc):thenWait(1):prepare(inc)

        check(count == 0)
        prepare_tree:start()
        check(count == 1)
        Timers.update(1)
        check(count == 1)
        Timers.update(1)
        check(count == 2)
    end,

    function()
        -- coverage: appending finallys
        local count = 0
        local inc = function() count = count + 1 end

        local two_finals_one_timer = Timers.create():finally(inc):finally(inc)

        check(count == 0)
        two_finals_one_timer:start()
        check(count == 0)
        Timers.update(1)
        check(count == 2)

        count = 0
        local two_finals_tree = Timers.create():finally(inc):thenWait(1):finally(inc)
        check(count == 0)
        two_finals_tree:start()
        check(count == 0)
        Timers.update(1)
        check(count == 0)
        Timers.update(1)
        check(count == 2)
    end,

    function()
        -- finally: assymetric trees
        local asym_data = 0
        local tree_asym = Timers.create(1)
        -- short branch
        tree_asym:thenWait(1):finally(function() asym_data = 1 end)
        -- long branch
        tree_asym:thenWait(2)

        -- finally should be called after the whole tree is finished
        tree_asym:start()
        check(asym_data == 0)
        check(#Timers.list == 1)

        -- run root, spawn 2 branches
        Timers.update(1)
        check(asym_data == 0)
        check(#Timers.list == 2)

        -- finish one branch, finally not triggered yet
        Timers.update(1)
        check(asym_data == 0)
        check(#Timers.list == 1)

        -- finish second branch, trigger finally
        Timers.update(1)
        check(asym_data == 1)
        check(#Timers.list == 0)
    end,

    function()
        -- finally: symetric trees, finally should be called only once
        local asym_data = 0
        local tree_asym = Timers.create(1)
        tree_asym:thenWait(1)
        tree_asym:thenWait(1):finally(function() asym_data = asym_data+1 end)

        -- finally should be called after the whole tree is finished
        tree_asym:start()
        check(asym_data == 0)
        check(#Timers.list == 1)

        -- run root, spawn 2 branches
        Timers.update(1)
        check(asym_data == 0)
        check(#Timers.list == 2)

        -- finish both branches, trigger finally but only once
        Timers.update(1)
        check(asym_data == 1)
        check(#Timers.list == 0)

    end,

    function()
        -- finally: callback is aware of explicit cancellation

        local fControl = 0
        local finalled_timer = Timers.create(1):finally(function(cancelled)
                fControl = cancelled and 1 or 2
            end)

        check(fControl == 0)
        finalled_timer:start()
        check(fControl == 0)
        Timers.update(1)
        check(fControl == 2)

        fControl = 0
        finalled_timer:start()
        check(fControl == 0)
        finalled_timer:cancel()
        check(fControl == 1)

        fControl = 0
        finalled_timer:start()
        check(fControl == 0)
        Timers.cancelAll()
        check(fControl == 1)

    end,


    function()
        -- followWith: append a tree to another tree
        local done = 0
        local tree_followed = Timers.immediate()
        tree_followed:thenWait(2):followWith(1):andThen(function() done = 1 end)
        tree_followed:thenWait(4)

        tree_followed:start()

        -- first, two branches of tree_followed are executing
        Timers.update(1)
        check(done == 0)
        check(#Timers.list == 2)

        -- after 2 seconds, the first branch dies, but the second branch still runs
        Timers.update(1)
        check(done == 0)
        check(#Timers.list == 1)

        -- at 3 seconds, the second branch is still there
        Timers.update(1)
        check(done == 0)
        check(#Timers.list == 1)

        -- at 4 seconds, the second branch dies, which triggers the second tree (1 second root)
        Timers.update(1)
        check(done == 0)
        check(#Timers.list == 1)

        -- 5 seconds: the last branch of the last tree finishes
        Timers.update(1)
        check(done == 1)
        check(#Timers.list == 0)
    end,

    function()
        -- follower trees are only spawned when launcher tries finish correctly (not when cancelled)
        local done = 0
        local tree_cancelled = Timers.immediate()
        tree_cancelled:thenWait(2):followWith(1):thenWait(2):andThen(function() done = 1 end)

        tree_cancelled:start()

        Timers.update(1)
        check(done == 0)
        check(#Timers.list == 1)

        tree_cancelled:cancel()
        Timers.update(1)
        check(done == 0)
        check(#Timers.list == 0)

        -- just to make sure that nothing is running
        Timers.update(1)
        check(done == 0)
        check(#Timers.list == 0)

    end,

    function()
        -- independent instances of Timers
        local TimersA = Timers.newInstance()
        local TimersB = Timers.newInstance()

        local count = 0
        local timerA = TimersA.create(100):withUpdate(function() count = count + 1 end)
        local timerB = TimersB.create(100):withUpdate(function() count = count + 10 end)

        check(count == 0)
        timerA:start()
        timerB:start()
        check(count == 0)
        check(#TimersA.list == 1)
        check(#TimersB.list == 1)
        TimersA.update(1)
        check(count == 1)
        TimersB.update(1)
        check(count == 11)
        TimersA.update(1)
        TimersB.update(1)
        check(count == 22)
        TimersA.cancelAll()
        TimersA.update(1)
        TimersB.update(1)
        check(count == 32)

        TimersA.cancelAll()
        TimersB.cancelAll()

    end,

    function()
        -- you don't have to pass references to self in Timers' functions
        -- but you do in methods of individual timers
        -- yet, the Timers also accept this other form

        local data = 0
        Timers.setTimeout(function() data = 1 end, 1)
        check(data == 0)
        Timers.update(1)
        check(data == 1)

        Timers:setTimeout(function() data = 2 end, 1)
        check(data == 1)
        Timers:update(1)
        check(data == 2)

        local timer_noself = Timers.create(1):andThen(function() data = 3 end)
        timer_noself:start()
        check(data == 2)
        Timers.update(1)
        check(data == 3)

        local timer_withself = Timers:create(1):andThen(function() data = 4 end)
        timer_withself:start()
        check(data == 3)
        Timers.update(1)
        check(data == 4)

    end,

    function()
        -- observe: link a timer to a tree (when it does not belong to that tree)
        -- the timer will run as long as the tree is running

        local count = 0
        local watched_tree = Timers.create(1):thenWait(1):thenWait(1)
        local observer = Timers.create():observe(watched_tree):withUpdate(function()
            count = count + 2
            end)

        watched_tree:start()
        observer:start()

        check(count == 0)

        Timers.update(1)
        check(count == 2)
        check(observer.elapsed == 1)

        Timers.update(1)
        check(count == 4)
        check(observer.elapsed == 2)

        Timers.update(1)
        check(count == 6)
        check(observer.elapsed == 3)

        Timers.update(1)
        check(count == 6)
        check(#Timers.list == 0)
        check(observer.elapsed == 3)
    end,

    function()
        -- prevent animation to observe itself
        local self_observe = Timers.create()

        self_observe:observe(self_observe)
        check(self_observe.observed == nil)

        self_observe:observe(Timers.create())
        check(self_observe.observed ~= nil)

        self_observe:observe()
        check(self_observe.observed == nil)
    end,

    function()
        -- test that origin is passed through correctly across branches regardless of the order in which they were defined
        -- and thus finally is correctly executed

        local control = 0
        local root = Timers.create()
        local a = Timers.create()
        local b = Timers.create(2)
        local c = Timers.create()

        a:hang(c)
        root:hang(a)
        a:hang(b)
        c:finally(function() control = 1 end)

        root:start()
        check(control == 0)
        Timers.update(1)
        check(control == 0)
        Timers.update(1)
        check(control == 0)
        Timers.update(1)
        check(control == 0)
        Timers.update(1)
        check(control == 1)

    end,

}


for i,test in ipairs(Tests) do
    io.write("Test "..i.."...")
    local passed,err = pcall(test)
    Timers.cancelAll() -- make sure that Timers is clean before starting a new test
    print(passed and "OK" or err and "failed at "..err or "")
end