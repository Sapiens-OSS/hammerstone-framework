local patch = {
    version = "0.5.0.79",
    patchOrder = 0,
    debugCopyAfter = true,
    operations = {
        [1] = { type = "replaceAt", startAt = "manageUI.titleIcon = ModelView.new(manageUI.titleView)", endAt = "titleTextView.baseOffset = vec3(iconPadding, 0, 0)", repl = {chunk = "manageUI_titleIcon"}}, 
        [2] = { type = "replaceAt", startAt = {"local function updateCurrentView(", "if manageUI.currentModeIndex == modeTypes.options then"}, endAt = "end", repl = {chunk = "manageUI_changeTitle", indent = 1}}
    }
}

return patch