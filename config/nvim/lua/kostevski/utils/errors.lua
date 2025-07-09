---@class UtilsErrors Error handling utilities
local M = {}

---@alias ErrorHandlerFn fun(err: string, context?: table): nil

---@class ErrorHandler
---@field on_error? ErrorHandlerFn Custom error handler
---@field notify? boolean Whether to show notifications (default: true)
---@field log? boolean Whether to log errors (default: true)
---@field context? table Additional context to include

---@class ErrorContext
---@field func string Function name/string representation
---@field args any[] Function arguments
---@field timestamp integer Unix timestamp
---@field [string] any Additional context fields

---@class ErrorConfig
---@field notify boolean Whether to show notifications
---@field log boolean Whether to log errors
---@field max_retries integer Maximum retry attempts
---@field retry_delay integer Delay between retries in milliseconds

-- Default error handler configuration
---@type ErrorConfig
M.config = {
   notify = true,
   log = true,
   max_retries = 3,
   retry_delay = 100, -- milliseconds
}

---Configure error handling
---@param opts? ErrorConfig Configuration options
function M.setup(opts)
   if opts then
      M.config = vim.tbl_deep_extend("force", M.config, opts)
   end
end

---Wrap a function with error handling. Returns result and error separately.
---@generic T
---@param fn fun(...): T Function to wrap
---@param opts? ErrorHandler Options
---@return fun(...): T?, string? wrapped_function Function that returns (result, error)
function M.wrap(fn, opts)
   opts = vim.tbl_deep_extend("force", {
      notify = M.config.notify,
      log = M.config.log,
   }, opts or {})

   return function(...)
      local args = { ... }
      local ok, result = pcall(fn, unpack(args))

      if ok then
         return result
      end

      -- Handle error
      local err_msg = tostring(result)
      local context = vim.tbl_extend("force", {
         func = tostring(fn),
         args = args,
         timestamp = os.time(),
      }, opts.context or {})

      -- Custom error handler
      if opts.on_error then
         opts.on_error(err_msg, context)
      end

      -- Log error
      if opts.log then
         M.log_error(err_msg, context)
      end

      -- Notify user
      if opts.notify then
         vim.notify(err_msg, vim.log.levels.ERROR, {
            title = "Error",
         })
      end

      return nil, err_msg
   end
end

---@alias RetryHandler fun(attempt: integer, error: string): nil

---@class RetryOptions
---@field retries? integer Number of retry attempts
---@field delay? integer Base delay between retries in milliseconds
---@field on_retry? RetryHandler Callback on each retry

---Try to execute a function with retries
---@generic T
---@param fn fun(...): T Function to execute
---@param opts? RetryOptions Options
---@return T? result Result on success
---@return string? error Error message on failure
function M.try_with_retry(fn, opts)
   opts = vim.tbl_deep_extend("force", {
      retries = M.config.max_retries,
      delay = M.config.retry_delay,
   }, opts or {})

   local last_error

   for attempt = 1, opts.retries + 1 do
      local ok, result = pcall(fn)

      if ok then
         return result
      end

      last_error = tostring(result)

      -- Don't retry on last attempt
      if attempt <= opts.retries then
         if opts.on_retry then
            opts.on_retry(attempt, last_error)
         end

         -- Wait before retry
         vim.wait(opts.delay * attempt)
      end
   end

   return nil, last_error
end

---@class SafeRequireOptions
---@field silent? boolean Don't show error notifications
---@field default? any Default value to return on failure

---Protected require with error handling
---@param module string Module name
---@param opts? SafeRequireOptions Options
---@return any? module Module or default value
---@return boolean loaded Whether module was loaded successfully
function M.safe_require(module, opts)
   opts = opts or {}

   local ok, result = pcall(require, module)

   if ok then
      return result, true
   end

   if not opts.silent then
      vim.notify(string.format("Failed to load module '%s': %s", module, result), vim.log.levels.ERROR)
   end

   return opts.default, false
end

---Validate function arguments using vim.validate
---@param validations table<string, any> Validation spec (same as vim.validate)
---@return boolean valid Whether validation passed
---@return string? error Error message if validation failed
function M.validate(validations)
   local ok, err = pcall(vim.validate, validations)

   if not ok then
      return false, err
   end

   return true
end

---Create assertion function. Throws error if condition is false.
---@param condition boolean Condition to check
---@param message string Error message if condition is false
---@param level? integer Stack level for error (default: 2)
function M.assert(condition, message, level)
   if not condition then
      error(message, level or 2)
   end
end

---@class ErrorLogEntry
---@field timestamp string Formatted timestamp
---@field error string Error message
---@field context? table Additional context
---@field traceback string Stack traceback

---Log error to file or internal log
---@param error string Error message
---@param context? table Additional context
function M.log_error(error, context)
   local entry = {
      timestamp = os.date("%Y-%m-%d %H:%M:%S"),
      error = error,
      context = context,
      traceback = debug.traceback(),
   }

   -- Use debug module if available
   local Utils = require("kostevski.utils")
   if rawget(Utils, "debug") then
      Utils.debug.log("ERROR", "errors", error, entry)
   end

   -- Also log to file if configured
   if vim.g.error_log_file then
      local log_line = vim.json.encode(entry) .. "\n"
      local file = io.open(vim.g.error_log_file, "a")
      if file then
         file:write(log_line)
         file:close()
      end
   end
end

---Create error boundary for async operations
---@generic T
---@param fn fun(...): T Async function to protect
---@param opts? ErrorHandler Options
---@return fun(...): T?, string? protected_function Schedule-wrapped function
function M.async_wrap(fn, opts)
   opts = opts or {}

   return vim.schedule_wrap(function(...)
      local wrapped = M.wrap(fn, opts)
      return wrapped(...)
   end)
end

---@class ChainOptions
---@field stop_on_error? boolean Stop execution on first error
---@field collect_errors? boolean Collect all errors (only with stop_on_error=false)

---Chain multiple operations with error handling
---@param operations function[] Array of functions to execute in sequence
---@param opts? ChainOptions Options
---@return any[] results Array of results (nil for failed operations)
---@return string[] errors Array of error messages
function M.chain(operations, opts)
   opts = vim.tbl_deep_extend("force", {
      stop_on_error = true,
      collect_errors = false,
   }, opts or {})

   local results = {}
   local errors = {}

   for i, operation in ipairs(operations) do
      local ok, result = pcall(operation)

      if ok then
         results[i] = result
      else
         local err_msg = tostring(result)

         if opts.collect_errors then
            errors[i] = err_msg
         end

         if opts.stop_on_error then
            return results, errors
         end
      end
   end

   return results, errors
end

---@class TypedError
---@field type string Error type/category
---@field message string Error message
---@field details? table Additional error details
---@field timestamp integer Unix timestamp
---@field traceback string Stack traceback

---Create typed error object
---@param type string Error type/category
---@param message string Error message
---@param details? table Additional details
---@return TypedError error Error object
function M.create_error(type, message, details)
   return {
      type = type,
      message = message,
      details = details,
      timestamp = os.time(),
      traceback = debug.traceback(),
   }
end

---Check if value is an error object created by create_error
---@param value any Value to check
---@return boolean is_error True if value is a TypedError
function M.is_error(value)
   return type(value) == "table" and value.type ~= nil and value.message ~= nil and value.traceback ~= nil
end

---@class FormatErrorOptions
---@field include_traceback? boolean Include stack traceback in output

---Format error for display
---@param error string|TypedError|any Error to format
---@param opts? FormatErrorOptions Options
---@return string formatted Formatted error string
function M.format_error(error, opts)
   opts = opts or {}

   if type(error) == "string" then
      return error
   end

   if M.is_error(error) then
      local parts = {
         string.format("[%s] %s", error.type, error.message),
      }

      if error.details then
         table.insert(parts, "Details: " .. vim.inspect(error.details))
      end

      if opts.include_traceback and error.traceback then
         table.insert(parts, "Traceback:\n" .. error.traceback)
      end

      return table.concat(parts, "\n")
   end

   return vim.inspect(error)
end

return M
