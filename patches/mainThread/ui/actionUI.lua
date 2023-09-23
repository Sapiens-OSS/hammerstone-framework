local patcher = mjrequire "hammerstone/utils/patcher"

local patch = {
	version = "0.4.2.5",
	debugCopyAfter = true,
	debugOnly = false
}

function patch:registerChunkFiles()
	return {
		["innerWheel"] = "patches/mainThread/ui/actionUI_innerWheel",
		["innerWheelInit"] = "patches/mainThread/ui/actionUI_innerWheelInit",
		["updateButtons"] = "patches/mainThread/ui/actionUI_updateButtons",
	}
end

function patch:applyPatch(fileContent_)
	local operations = {
		[1] = 
			function(fileContent)
				return patcher:replaceAt(
					{
						"local innerSegmentModelNames = {"
					}, 
					{
						"local innerSegmentToolTipInfos = {", 
						"\r\n}"
					}, 
					patcher:getChunk("innerWheel"),
					fileContent
				)
			end, 
		[2] = 
			function(fileContent)
				return patcher:replace("local function addInnerSegment%(addOffsetIndex%)", 
				"local function addInnerSegment(parentView, innerSegmentInfos)\r\n    ",
				fileContent)
			end,
		[3] = 
			function(fileContent)
				return patcher:replace("innerSegmentModelNames%[addOffsetIndex%]", "innerSegmentInfos.modelName", fileContent)
			end,
		[4] = 
			function(fileContent)
				return patcher:replace("innerSegmentControllerShortcuts%[addOffsetIndex%]", "innerSegmentInfos.controllerShortcut", fileContent)
			end, 
		[5] = 
			function(fileContent)
				return patcher:replace("vec3%(innerSegmentControllerShortcutKeyImageXOffsets%[addOffsetIndex%],2,0%)", "innerSegmentInfos.controllerShortcutKeyImageOffset", fileContent)
			end, 
		[6] = 
			function(fileContent)
				return patcher:replace("innerSegmentIconNames%[addOffsetIndex%]", "innerSegmentInfos.iconName", fileContent)
			end,
		[7] = 
			function(fileContent)
				return patcher:replace("innerSegmentIconOffsets%[addOffsetIndex%]", "innerSegmentInfos.iconOffset", fileContent)
			end, 
		[8] = 
			function(fileContent)
				return patcher:replace("innerSegmentFunctions%[addOffsetIndex%]", "innerSegmentInfos.clickFunction", fileContent)
			end,
		[9] = 
			function(fileContent)
				return patcher:replace("innerSegmentToolTipInfos%[addOffsetIndex%]", "innerSegmentInfos.tooltipInfos", fileContent)
			end,
		[10] = 
			function(fileContent)
				return patcher:replace("addInnerSegment%(1%)[%s\r\n]+addInnerSegment%(2%)[%s\r\n]+", patcher:getChunk("innerWheelInit"), fileContent)
			end,
		[11] = 
			function(fileContent)
				return patcher:replaceAt(
					{
						"local function updateButtons("
					}, 
					{
						"\r\nend"
					},
					patcher:getChunk("updateButtons"), 
					fileContent
				)
			end,
		[12] = 
			function(fileContent)
				return patcher:replace("local innerSegmentView = View%.new%(actionUI%.backgroundView%)", "local innerSegmentView = View.new(parentView)", fileContent)
			end, 
		[13] = 
			function(fileContent)
				return patcher:replaceAt(
					{
						"function actionUI:selectDeconstructAction",
						"local buttonInfo = buttonInfos["
					},
					{
						"]"
					},
					"local buttonInfo = buttonInfos[getButtonIndexFromDisplayIndex(index)]",
					fileContent
				)
			end,
		[14] = 
			function(fileContent)
				return patcher:replaceAt(
					{
						"function actionUI:selectCloneAction",
						"local buttonInfo = buttonInfos["
					},
					{
						"]"
					},
					"local buttonInfo = buttonInfos[getButtonIndexFromDisplayIndex(index)]",
					fileContent
				)
			end,
	}

	return patcher:runOperations(operations, fileContent_, true)
end

return patch