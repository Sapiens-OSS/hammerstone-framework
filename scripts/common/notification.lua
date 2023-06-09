--- Hammerstone: notification.lua
--- @author SirLich

local shadow = mjrequire "hammerstone/utils/shadow"
local typeMaps = mjrequire "common/typeMaps"

local notification = {}

--- Allows you to register a new notification type, which can later be used to create notifications
--- @param key: The key to add, such as 'myNewNotification'
--- @param data: The object to add, containing all fields. Refer to the source code to see all fields.
function notification:addNotificationType(key, data)
	data.key = key
	typeMaps:insert("notifications", self.types, data)
end

--- Allows you to send a notification.
--- @param key string - name of the notification type, such as "myNewNotification"
--- @param objectInfo A table of information containing object information for the notification.
function notification:sendNotification(key, objectInfo)
	local notificationsUI = mjrequire "mainThread/ui/notificationsUI"
	notificationsUI:displayObjectNotification({
		typeIndex = self.types[key].index,
		objectInfo = objectInfo
	})
end

--- Sends a quick notification -no registration needed!
--- @param text - The text to show. Example: 'hello world!'
--- Optional:
--- @param objectInfo A table of information containing object information for the notification.
--- @param colorType - The color profile to use. Example: 'notification.colorTypes.bad'
--- @param soundTypeIndex - The sound to play. Example: 'notificationSound.types.notificationBad.index'
function notification:sendQuickNotification(text, objectInfo, colorType, soundTypeIndex)
	-- Add a temporary notification (or overwrite, if this isn't the first 'quick' notification.)
	self:addNotificationType("temp", {
		titleFunction = function(notificationInfo)
			return text
		end,
		soundTypeIndex = soundTypeIndex,
		colorType = colorType,
	})

	self:sendNotification("temp", objectInfo)
end


return shadow:shadow(notification, 0) -- Load order as early as possible