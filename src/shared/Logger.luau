local Logger = {
    enabled = true
}

function Logger.log(...)
    if Logger.enabled then
        print("[DEBUG]", ...)
    end
end

function Logger.warn(...)
    if Logger.enabled then
        print("[WARN]", ...)
    end
end

function Logger.error(...)
    if Logger.enabled then
        print("[ERROR]", ...)
    end
end

function Logger.info(...)
    if Logger.enabled then
        print("[INFO]", ...)
    end
end






function Logger.setEnabled(enabled)
    Logger.enabled = enabled
end

return Logger
