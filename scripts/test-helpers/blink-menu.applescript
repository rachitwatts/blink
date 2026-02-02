-- Blink Menu Bar Interaction Helper
-- Usage: osascript blink-menu.applescript <action>
-- Actions: click, pause, resume, restart, settings, quit, start-break, status

on run argv
    if (count of argv) < 1 then
        return "Usage: osascript blink-menu.applescript <action>
Actions: click, pause, resume, restart, settings, quit, start-break, status"
    end if

    set theAction to item 1 of argv as text

    tell application "System Events"
        -- Check if Blink is running
        if not (exists process "Blink") then
            return "ERROR: Blink is not running"
        end if

        tell process "Blink"
            if theAction is equal to "status" then
                -- Return the menu bar title (timer display)
                try
                    return name of menu bar item 1 of menu bar 2
                on error
                    return "ERROR: Could not get menu bar status"
                end try

            else if theAction is equal to "click" then
                -- Just click to open the menu
                click menu bar item 1 of menu bar 2
                return "OK: Menu opened"

            else if theAction is equal to "pause" then
                click menu bar item 1 of menu bar 2
                delay 0.3
                try
                    click menu item "Pause" of menu 1 of menu bar item 1 of menu bar 2
                    return "OK: Paused"
                on error
                    key code 53 -- Escape to close menu
                    return "ERROR: Pause not available (already paused?)"
                end try

            else if theAction is equal to "resume" then
                click menu bar item 1 of menu bar 2
                delay 0.3
                try
                    click menu item "Resume" of menu 1 of menu bar item 1 of menu bar 2
                    return "OK: Resumed"
                on error
                    key code 53 -- Escape to close menu
                    return "ERROR: Resume not available (already running?)"
                end try

            else if theAction is equal to "restart" then
                click menu bar item 1 of menu bar 2
                delay 0.3
                click menu item "Restart Session" of menu 1 of menu bar item 1 of menu bar 2
                return "OK: Session restarted"

            else if theAction is equal to "settings" then
                click menu bar item 1 of menu bar 2
                delay 0.3
                click menu item "Settings..." of menu 1 of menu bar item 1 of menu bar 2
                return "OK: Settings opened"

            else if theAction is equal to "start-break" then
                click menu bar item 1 of menu bar 2
                delay 0.3
                try
                    click menu item "Start Break Now" of menu 1 of menu bar item 1 of menu bar 2
                    return "OK: Break started"
                on error
                    key code 53
                    return "ERROR: Start Break Now not available"
                end try

            else if theAction is equal to "quit" then
                click menu bar item 1 of menu bar 2
                delay 0.3
                click menu item "Quit Blink" of menu 1 of menu bar item 1 of menu bar 2
                return "OK: Quit"

            else
                return "ERROR: Unknown action: " & theAction
            end if
        end tell
    end tell
end run
