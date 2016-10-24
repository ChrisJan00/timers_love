timers_love
===========
by Christiaan Janssen

A convenience library for timed events in Löve2D.  A 'timer' is a common pattern that I use often in my projects.  The aim of this library is to wrap the frequent boilerplate in some convenient functions so that I can spawn and chain 'timers' with only a handful of lines of code.

This is not a tweening library.  It is possible to implement tweens on top of this library, but that is not the goal of this project.  This offers a more basic framework for generic use.

Usage:
------

**Including it in your project**:


    require "timers"

    function love.update(dt)
        Timers.update(dt)
        ...
    end

    function love.draw()
        Timers.draw()
        ...
    end

Concepts
--------

    timer:  a timer object.  It has a timeout duration and callback functions can be attached to be called at specific points of its lifetime.
    tree: a chain of timers.  When one timer expires, the next one(s) in the tree are started.

Timer methods
-------------

**Creating a timer**:


    timer = Timers.create(timeout)
        -- timeout is optional.  Specifies the time after which the timer expires. Default value is 0 (immediate expiration when started).



**Timer parameters**:


    timer = timer:withTimeout(timeout)
        -- explicitly replice a timeout value
    timer = timer:withData(data_object)
        -- attaches data_object to timer chain, so that it can be referenced in the callbacks.  New calls will replace data_object
    data_object = timer:getData()
        -- returns the attached data_object
    timer = timer:withDrawOrder(draworder)
        -- changes the draworder of the timer tree (default is 0).  See below for explanation

The data object is attached to the tree and it's the same for all the timers of that tree.



**User-defined callbacks**:


    timer = timer:prepare(function(timer))
        -- callback will be called when this timer is launched
    timer = timer:andThen(function(timer))
        -- callback will be called when timer expires
    timer = timer:withUpdate(function(elapsed, timer))
        -- callback will be called on update.  elapsed is the time elapsed since this individual timer started, in seconds.
    timer = timer:withDraw(function(timer), draworder)
        -- callback will be called on draw.  All timers with draw callbacks are sorted by ascending draworder value.  draworder is an optional parameter, with default value 0.


The callbacks are pushed to a stack, using closures.  This means, if you call for example "andThen" two times, both callbacks will be attached, in the order in which this function was called.

The callbacks are going to be passed a reference to the current timer, mostly for access to the data_object.

These functions return a reference to the timer itself, so that they can be chained (see examples below).

Drawing order might be important, for example when a given element has to remain above another element, and thus should come afterwards in the drawing order, regardless of the order in which the timer callbacks are resolved.  This explains the parameter.


**Timer tree**:

You can append timers to timers, like a tree.  When a timer expires, all the leaves connected to it are started.  If a leaf is appended to another leaf, it will be triggered by it.

The parameters data and draworder are unique per tree, the other parameters are per-leaf.


    timer_leaf = timer_root:thenWait(timeout)
        -- returns a new timer with a new timeout value, that will be started when timer_root expires.
    timer_leaf = timer_root:hang(timer_leaf)
        -- appends a full timer as leaf of timer_root, returns timer_leaf
        -- timer_root:thenWait(timeout) is equivalent to timer_root:hang(Timers.create(timeout))


Once a new leaf has been created, you can still modify the parameters of the root or of the leaf calling the respective functions over them.  You can attach new leaves to any of those.



**Timer control**:


    timer = timer:start()
        -- launches root timer of this timer's tree.  Restarts it if already running.
    timer = timer:cancel()
        -- stops timer's tree and removes it from internal list.
    timer = timer:pause()
    timer = timer:continue()
        --  pauses/unpauses timer's tree, if currently running.  If not, it will start paused.
    is_paused = timer:isPaused()
        --  to check the current 'pause' status of the tree


These methods affect the timer's tree, regardless of which of the leaves is currently running.  You can view the whole tree as a single timer for that matter, regardless of internal structure.

If start is called repeatedly, it will stop and reset the tree if it's already running.


**Parallel trees**:


    new_root = timer:fork()
        -- clones the tree and returns reference to root of cloned tree
    root = timer:ref()
        -- returns a reference to root timer (itself if it is the root)


There is no way to access and modify the 'leaves' of a timer tree, from the root.  You can only append new leaves to a current root.  If you need a tree with different leaves, you will have to build it from scratch.  If you want to expand an existing tree, you will need a reference to the desired leaf, which you can't get if it's a forked tree.

The existence of fork() is to overcome the problem of wanting to have two or more instances of the same tree running in parallel, without having to recreate it from scratch.  The intended use is to change the data_object of the fork and launch it in parallel to the original tree.

**Looping timers**:

    timer = timer:thenRestart()
        -- once this timer expires, restart the tree (infinite loop)
    timer = timer:thenRestartLast()
        -- once this timer expires, restart itself: the last leaf of the tree (infinite loop)


Timer controller
----------------

**General controls**


    Timers.pauseAll()
        -- pauses update function
    Timers.continueAll()
        -- unpauses update function
    Timers.cancelAll()
        -- cancels all running timers


**Convenience function**


    timer = Timers.setTimeout(function(timer), timeout)
        -- creates and launches a timer that will launch the callback after timeout seconds.  Similar to JavaScript setTimeout.


Examples
--------

timeout

    Timers.setTimeout(function() print("Hello World in 4 seconds") end, 4)

timer tree

    Timers.create(2)
        :andThen(function() print("Two seconds") end)
        :thenWait(3)
        :andThen(function() print("Five seconds") end)
        :thenWait(1)
        :andThen(function() print("Six seconds") end)
        :start()

update and draw

    Timers.create()
        :withData({ opacity = 0 })
        :withTimeout(10)
        :withUpdate(function(T,timer)
            timer:getData().opacity = 1 - math.abs(T-5)/5
        end)
        :withDraw(function(timer)
            love.graphics.setColor(255,255,255,255 * timer:getData().opacity)
            love.graphics.print("Hello world", 100, 100)
        end)
        :start()


For more examples of usage, you can look at tests_timers.lua.


-- Christiaan Janssen, July 2016
