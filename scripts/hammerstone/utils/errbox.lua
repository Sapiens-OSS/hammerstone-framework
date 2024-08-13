--- Wrapped error handling in Lua
--- @author SirLich

local errbox = {}

-- Hammerstone
local utils = mjrequire "hammerstone/utils/utils"

-- Private setup for errbox. See make_error and make_success
function errbox._new ()
   local op = {}

   -- Whether the errbox was a success
   op.success = true
   op._error_stack = {}

   function op:add_context(error, depth)
      if depth == nil then
         depth = 3
      end

      self.success = false
      table.insert(self._error_stack, {
         error = error,
         info = debug.getinfo(depth)
      })
   end

   -- Panics and quites, printing as much information as possible about the failure
   function op:panic()
      self:add_context("Thread has paniced. Nothing we can do.")

      mj:log("Panic:")
      for i, err in ipairs(self._error_stack) do
         mj:log(" ! " .. err.error)
         mj:log("    - " .. err.info.currentline .. " " .. err.info.source)
      end
      mj:log("Finished panic")
      os.exit(1)
   end

   return op
end

--- Configures the errbox as successful
function errbox.make_success()
   local op = errbox._new()
   return op
end

--- Configure the errbox as a failure
function errbox.make_error(error)
   local op = errbox._new()
   op:add_context(error, 3)
   return op
end

return errbox