--!strict
--[[
	ApiHealth (server)

	Tells apart the two DataStore failures that look identical from a pcall:

	  * The API is switched off -- Studio without "Studio Access to API
	    Services", or a place with DataStores disabled. This will never
	    succeed, so retrying is wasted and the feature should degrade openly.

	  * A transient error. Worth retrying, and worth refusing to overwrite
	    good data in the meantime.

	Shared by Persistence and LeaderboardService because they must agree: if
	one decides the API is dead and the other keeps hammering it, the console
	fills with noise and the boards lie about why they are empty.

	Note that GetDataStore/GetOrderedDataStore SUCCEED even when the API is
	disabled -- only the Get/Set calls fail. So availability cannot be decided
	up front; it has to be learned from the first real call.
]]

local ApiHealth = {}

function ApiHealth.isDisabled(err: any): boolean
	local text = string.lower(tostring(err))
	return string.find(text, "studio access to apis", 1, true) ~= nil
		or string.find(text, "studioaccesstoapisnotallowed", 1, true) ~= nil
		or string.find(text, "datastore requests are not allowed", 1, true) ~= nil
		or string.find(text, "not allowed", 1, true) ~= nil
end

return ApiHealth
