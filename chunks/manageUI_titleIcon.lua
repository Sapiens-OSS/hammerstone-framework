titleTextView = ModelTextView.new(titleView)
    titleTextView.font = Font(uiCommon.titleFontName, 36)
    titleTextView.relativePosition = ViewPosition(MJPositionCenter, MJPositionCenter)
    titleTextView.baseOffset = vec3(0, 0, 0)

    titleIcon = ModelView.new(titleView)
    titleIcon.relativePosition = ViewPosition(MJPositionOuterLeft, MJPositionCenter)
    titleIcon.relativeView = titleTextView
    titleIcon.baseOffset = vec3(-iconPadding, 0, 0)
    titleIcon.scale3D = vec3(iconHalfSize,iconHalfSize,iconHalfSize)
    titleIcon.size = vec2(iconHalfSize,iconHalfSize) * 2.0