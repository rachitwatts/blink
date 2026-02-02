-- Blink Overlay Interaction Helper
-- Usage: osascript blink-overlay.applescript <action>
-- Actions: check, snooze, skip, count-windows

on run argv
    if (count of argv) < 1 then
        return "Usage: osascript blink-overlay.applescript <action>
Actions: check, snooze, skip, count-windows"
    end if

    set theAction to item 1 of argv as text

    tell application "System Events"
        -- Check if Blink is running
        if not (exists process "Blink") then
            return "ERROR: Blink is not running"
        end if

        tell process "Blink"
            if theAction is equal to "check" then
                -- Check if overlay is visible (has windows)
                set windowCount to count of windows
                if windowCount > 0 then
                    return "VISIBLE:" & windowCount
                else
                    return "HIDDEN"
                end if

            else if theAction is equal to "count-windows" then
                return count of windows

            else if theAction is equal to "snooze" then
                -- Single Escape to snooze
                key code 53
                delay 0.5
                set windowCount to count of windows
                if windowCount = 0 then
                    return "OK: Snoozed"
                else
                    return "WARN: Overlay still visible after snooze"
                end if

            else if theAction is equal to "skip" then
                -- Double Escape to skip
                key code 53
                delay 0.2
                key code 53
                delay 0.5
                set windowCount to count of windows
                if windowCount = 0 then
                    return "OK: Skipped"
                else
                    return "WARN: Overlay still visible after skip"
                end if

            else
                return "ERROR: Unknown action: " & theAction
            end if
        end tell
    end tell
end run
