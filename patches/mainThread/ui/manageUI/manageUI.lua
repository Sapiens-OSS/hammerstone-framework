local patch = {
    patchOrder = 0,
    debugCopyAfter = true,
    operations = {
        [1] = { type = "replace", pattern = "modeInfos", repl = "manageUI.modeInfos" },
        [2] = { type = "replaceAt", startAt = "local manageUI.modeInfos = {", endAt="\r\n}", repl = {chunk = "manageUI_modeInfos"}}, 
        [3] = { type = "localVariableToModule", variableName = "mainContentView"}, 
        [4] = { type = "localVariableToModule", variableName = "uiObjectsByModeType"}, 
        [5] = { type = "replaceAt", startAt = "titleIcon = ModelView.new(titleView)", endAt = "titleTextView.baseOffset = vec3(iconPadding, 0, 0)", repl = {chunk = "manageUI_titleIcon"}}, 
        [6] = { type = "replaceAt", startAt = {"local function updateCurrentView(", "if currentModeIndex == modeTypes.options then"}, endAt = "end", repl = {chunk = "manageUI_changeTitle", indent = 1}}
    }
}

return patch