local patch = {
	version = "0.4.2.5",
	debugCopyAfter = true,
	debugOnly = false, 
	operations = {
		[1] = { type = "replaceAt", startAt = "local innerSegmentModelNames = {", endAt = { "local innerSegmentToolTipInfos = {", "\r\n}" }, repl = { chunk = "actionUI_innerWheel" } },
		[2] = { type = "replace", pattern = "local function addInnerSegment%(addOffsetIndex%)", repl = "local function addInnerSegment(parentView, innerSegmentInfos)\r\n    " }, 
		[3] = { type = "replace", pattern = "innerSegmentModelNames%[addOffsetIndex%]", repl = "innerSegmentInfos.modelName" }, 
		[4] = { type = "replace", pattern = "innerSegmentControllerShortcuts%[addOffsetIndex%]", repl = "innerSegmentInfos.controllerShortcut" }, 
		[5] = { type = "replace", pattern = "vec3%(innerSegmentControllerShortcutKeyImageXOffsets%[addOffsetIndex%],2,0%)", repl = "innerSegmentInfos.controllerShortcutKeyImageOffset" },
		[6] = { type = "replace", pattern = "innerSegmentIconNames%[addOffsetIndex%]", repl = "innerSegmentInfos.iconName" },
		[7] = { type = "replace", pattern = "innerSegmentIconOffsets%[addOffsetIndex%]", repl = "innerSegmentInfos.iconOffset" },
		[8] = { type = "replace", pattern = "innerSegmentFunctions%[addOffsetIndex%]", repl = "innerSegmentInfos.clickFunction"},
		[9] = { type = "replace", pattern = "innerSegmentToolTipInfos%[addOffsetIndex%]", repl = "innerSegmentInfos.tooltipInfos"},
		[10] = { type = "replace", pattern = "addInnerSegment%(1%)[%s\r\n]+addInnerSegment%(2%)[%s\r\n]+", repl = { chunk = "actionUI_innerWheelInit", indent = 1 } },
		[11] = { type = "replaceAt", startAt = "local function updateButtons(", endAt = "\r\nend", repl = { chunk = "actionUI_updateButtons" } },
		[12] = { type = "replaceBetween", startAt = "local innerSegmentView = View.new(", endAt = ")", repl = "parentView" },
		[13] = { type = "replaceBetween", startAt = { "function actionUI:selectDeconstructAction", "local buttonInfo = buttonInfos[" }, endAt = "]", repl = "getButtonIndexFromDisplayIndex(index)" },
		[14] = { type = "replaceBetween", startAt = { "function actionUI:selectCloneAction", "local buttonInfo = buttonInfos["}, endAt = "]", repl = "getButtonIndexFromDisplayIndex(index)" },
	}
}

return patch