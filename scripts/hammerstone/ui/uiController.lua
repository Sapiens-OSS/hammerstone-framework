--- Hammerstone: uiController
--- @author: Witchy
--- Allows modders to retrieve ui Views and sub Views

-- Hammerstone
local logging = mjrequire "hammerstone/logging"

-- List of all views
local allViews = {}

local uiController = {}

local function addView(view, parentView, name, modulePath, viewType)
	
	if not modulePath then
		local parentInfos = allViews[parentView]

		while parentInfos and not modulePath do
			if parentInfos.modulePath then
				modulePath = parentInfos.modulePath
			else
				parentInfos = allViews[parentInfos.parentView]
			end
		end
	end

	local mainModulePath = nil

	if modulePath then
		if not modulePath:find("/uiCommon/") then
			mainModulePath = modulePath
		else
			local parentInfos = allViews[parentView]

			if parentInfos then
				mainModulePath = parentInfos.mainModulePath
			end
		end
	end

	allViews[view] =  {
		name = name,
		parentView = parentView,
		subViews = {},
		viewType = viewType, 
		modulePath = modulePath, 
		mainModulePath = mainModulePath
	}

	if allViews[parentView] then
		table.insert(allViews[parentView].subViews, view)
	end
end

-- Functions to add new views
do
	function uiController:newView(parentView, name, modulePath)
		local view = View.new(parentView)

		addView(view, parentView, name, modulePath, "View")

		return view
	end

	function uiController:newModelView(parentView, name, modulePath)
		local view = ModelView.new(parentView)

		addView(view, parentView, name, modulePath, "ModelView")

		return view
	end

	function uiController:newTextView(parentView, name, modulePath)
		local view = TextView.new(parentView)

		addView(view, parentView, name, modulePath, "TextView")

		return view
	end

	function uiController:newModelTextView(parentView, name, modulePath)
		mj:log(parentView)
		mj:log(name)
		mj:log(modulePath)
		local view = ModelTextView.new(parentView)

		addView(view, parentView, name, modulePath, "ModelTextView")

		return view
	end

	function uiController:newColorView(parentView, name, modulePath)
		local view = ColorView.new(parentView)

		addView(view, parentView, name, modulePath, "ColorView")

		return view
	end

	function uiController:newRenderTargetView(parentView, name, modulePath)
		local view = RenderTargetView.new(parentView)

		addView(view, parentView, name, modulePath, "RenderTargetView")

		return view
	end

	function uiController:newImageView(parentView, name, modulePath)
		local view = ImageView.new(parentView)

		addView(view, parentView, name, modulePath, "ImageView")

		return view
	end

	function uiController:newModelImageView(parentView, name, modulePath)
		local view = ModelImageView.new(parentView)

		addView(view, parentView, name, modulePath, "ModelImageView")

		return view
	end

	function uiController:newGlobeView(parentView, name, modulePath)
		local view = GlobeView.new(parentView)

		addView(view, parentView, name, modulePath, "GlobeView")

		return view
	end

	function uiController:newGameObjectView(parentView, size,  name, modulePath)
		local view = GameObjectView.new(parentView, size)

		addView(view, parentView, name, modulePath, "GameObjectView")

		return view
	end

	function uiController:newLinesView(parentView, name, modulePath)
		local view = LinesView.new(parentView)

		addView(view, parentView, name, modulePath, "LinesView")

		return view
	end

	function uiController:newTerrainMapView(parentView, name, modulePath)
		local view = TerrainMapView.new(parentView)

		addView(view, parentView, name, modulePath, "TerrainMapView")

		return view
	end
end

-- Functions to remove views
do
	function uiController:removeSubview(parentView, viewToRemove)

		local function removeAllChildren(viewToRemove_)
			local viewInfos = allViews[viewToRemove_]

			if viewInfos then
				for i, subView in ipairs(viewInfos.subView) do
					removeAllChildren(subView)
				end

				allViews[viewToRemove_] = nil
			end
		end

		removeAllChildren(viewToRemove)
		allViews[viewToRemove] = nil

		local parentViewInfos = allViews[parentView]

		if parentViewInfos then
			for i, subView in ipairs(parentViewInfos.subViews) do
				if subView == viewToRemove then
					table.remove(i)
					break
				end
			end
		end

		parentView:removeSubview(viewToRemove)
	end
end

-- Utils functions for modders to retrieve views
do
	function uiController:getParentView(view)
		if allViews[view] then
			return allViews[view].parentView
		end

		return nil
	end

	function uiController:getViewType(view)
		if allViews[view] then
			return allViews[view].type
		end

		return nil
	end

	function uiController:getSubViews(view)
		if allViews[view] then
			return mj:cloneTable(allViews[view].subViews)
		end

		return nil
	end

	function uiController:logHierarchy(view)
		local str = ""

		local function logView(view_, index, indent)
			local viewInfos = allViews[view_]

			if viewInfos then
				str = str .. string.rep(" ", indent) .. string.format("[%d] = %s type=%s modulePath=%s\r\n", index, viewInfos.name, viewInfos.viewType, viewInfos.modulePath)

				for i, subView in ipairs(viewInfos.subViews) do
					logView(subView, i, indent + 4)
				end
			end
		end

		logView(view, 0, 0)

		logging:log("View Hierarchy\r\n", str)
	end

	function uiController:searchViews(viewNameOrNil, viewTypeOrNil, mainModulePathOrNil, modulePathOrNil)
		local results = {}

		for view, viewInfos in pairs(allViews) do
			if (not modulePathOrNil or viewInfos.modulePath == modulePathOrNil) and
				(not mainModulePathOrNil or viewInfos.mainModulePath == mainModulePathOrNil) and
				(not viewTypeOrNil or viewInfos.viewType == viewTypeOrNil) and 
				(not viewNameOrNil or viewInfos.name == viewNameOrNil) then
				table.insert(results, view)
			end
		end

		return results
	end

	function uiController:searchSubViews(parentView_, viewNameOrNil_, viewTypeOrNil_, mainModulePathOrNil_, modulePathOrNil_ )
		assert(parentView_, "parentView is nil")

		local results = {}

		local function search(parentView, modulePathOrNil, mainModulePathOrNil, viewTypeOrNil, viewNameOrNil)
			if allViews[parentView] then
				for _, subView in pairs(allViews[parentView].subViews) do
					local subViewInfos = allViews[subView]

					if subViewInfos then
						if (not modulePathOrNil or subViewInfos.modulePath == modulePathOrNil) and
							(not mainModulePathOrNil or subViewInfos.mainModulePath == mainModulePathOrNil) and
							(not viewTypeOrNil or subViewInfos.viewType == viewTypeOrNil) and 
							(not viewNameOrNil or subViewInfos.name == viewNameOrNil) then
							table.insert(results, subView)
						end

						search(subView, modulePathOrNil, mainModulePathOrNil, viewTypeOrNil, viewNameOrNil)
					end
				end
			end
		end

		search(parentView_, modulePathOrNil_, mainModulePathOrNil_, viewTypeOrNil_, viewNameOrNil_)

		return results
	end
end		

return uiController