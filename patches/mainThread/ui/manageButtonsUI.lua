local patch = {
    debugCopyAfter = false,
    operations = {
        [1] = { type = "replaceAt", startAt = "function manageButtonsUI:init", endAt = "\r\nend", repl = {chunk = "manageButtonsUI_init"}},
    }
}

return patch