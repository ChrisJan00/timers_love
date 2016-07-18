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

    end
}


for i,test in ipairs(Tests) do
    io.write("Test "..i.."...")
    local passed,err = pcall(test)
    print(passed and "OK" or "failed at "..err)
end