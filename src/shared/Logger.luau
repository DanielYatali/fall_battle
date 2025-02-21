local Logger = {
    enabled = false
}

function Logger.log(...)
    if Logger.enabled then
        print("[DEBUG]", ...)
    end
end

function Logger.setEnabled(enabled)
    Logger.enabled = enabled
end

return Logger
