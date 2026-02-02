-- Blink Settings Window Interaction Helper
-- Usage: osascript blink-settings.applescript <action>
-- Actions: check, close, get-work-duration, get-break-duration

on run argv
    if (count of argv) < 1 then
        return "Usage: osascript blink-settings.applescript <action>
Actions: check, close, get-work-duration, get-break-duration"
    end if

    set theAction to item 1 of argv as text

    tell application "System Events"
        -- Check if Blink is running
        if not (exists process "Blink") then
            return "ERROR: Blink is not running"
        end if

        tell process "Blink"
            if theAction is equal to "check" then
                -- Check if settings window is open
                set windowCount to count of windows
                if windowCount > 0 then
                    -- Try to find Settings window
                    repeat with w in windows
                        try
                            if name of w contains "Settings" then
                                return "OPEN"
                            end if
                        end try
                    end repeat
                    return "NOT_FOUND"
                else
                    return "CLOSED"
                end if

            else if theAction is equal to "close" then
                -- Close settings with Cmd+W
                keystroke "w" using command down
                delay 0.3
                return "OK: Closed"

            else if theAction is equal to "get-work-duration" then
                -- Try to read the work duration value
                -- This requires accessibility to read stepper values
                repeat with w in windows
                    try
                        -- Look for stepper or text showing work duration
                        set allTexts to every static text of w
                        repeat with t in allTexts
                            set textValue to value of t
                            if textValue contains "min" then
                                return textValue
                            end if
                        end repeat
                    end try
                end repeat
                return "NOT_FOUND"

            else
                return "ERROR: Unknown action: " & theAction
            end if
        end tell
    end tell
end run
