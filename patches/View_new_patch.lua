local patch = {
	version = "0.4.2.5",
	patcheOrder = 1,
	debugOnly = false,
	debugCopyAfter = false,
	appliesTo = {
		"mainThread/ui/.+", 
		"mainThread/controller",
		"mainThread/storyPanel"
	},
	operations = {
		-- replaces all the [z] = GameObjectView.new([x], vec2([y])) into uiController:newGameObjectViewView([x], vec2([y]), [z], modulePath) if we're not in "mainThread/ui/uiCommon/uiCommon"
		[1] = { type = "replace", 
				pattern = "([^ %.]+)[ =]+GameObjectView%.new%(([^,]+)[%s,]+vec2%(([^%)]+)[ %)]+", 
				repl = "%1 = uiController:newGameObjectView(%2, vec2(%3), \"%1\", \"#PATH#\")", skipOnFail = true, 
				condition = function(fileContent, context) return not context.path:find("/uiCommon/uiCommon", 1, true) end },

		-- replaces all the [z] = [x]View.new([y]) into uiController:new[x]View([y], [z], modulePath) if we're not in "mainThread/ui/uiCommon/uiCommon"
		[2] = { type = "replace", pattern = "([^%s%.]+)[%s=]+([^%s]*)View%.new%(([^\r\n%)]+)%)", repl = "%1 = uiController:new%2View(%3, \"%1\", \"#PATH#\")", skipOnFail = true, 
				condition = function(fileContent, context) return not context.path:find("/uiCommon/uiCommon", 1, true) end },

		-- replaces all the [z] = [x]View.new([y]) into uiController:new[x]View([y], [z]) if we're in "mainThread/ui/uiCommon/uiCommon"
		[3] = { type = "replace", pattern = "([^%s%.]+)[%s=]+([^%s]*)View%.new%(([^\r\n%)]+)%)", repl = "%1 = uiController:new%2View(%3, \"%1\")", skipOnFail = true, 
				condition = function(fileContent, context) return context.path:find("/uiCommon/uiCommon", 1, true) end },

		-- replaces all [x]:removeSubview([y]) into uiController:removeSubview([x], [y])
		[4] = { type = "replace", pattern = "[%s\r\n]([^%s]):removeSubview%(([^%(])%)", repl = "uiController:removeSubview(%1, %2)", skipOnFail = true },


		-- if the file now contains reference to "uiController" but has no other "mjrequire" , add the mjrequire for it at the start of file
		[5] = { type = "insertBefore", string = "local uiController = mjrequire \"hammerstone/ui/uiController\"\r\n", 
			condition = function(fileContent) return fileContent:find("uiController:", 1, true) and not fileContent:find("mjrequire") end }, 

		-- if the file now contains reference to "uiController" and has at least one other "mjrequire" , add the mjrequire after the last mjrequire line
		[6] = { type = "insertAfter", after = { text = "mjrequire[^\r\n]+", plain = false, reps = -1 }, 
			string = "\r\n\r\nlocal uiController = mjrequire \"hammerstone/ui/uiController\"\r\n", 
			condition = function(fileContent) return fileContent:find("uiController:", 1, true) and fileContent:find("mjrequire") end },
	}
}

return patch