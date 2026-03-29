--- state.lua
--- Manages per-buffer plugin state.  Each buffer gets an independent state
--- record that tracks current mode, the parsed table, and cursor position.
---
--- State shape:
---   {
---     mode = "table" | "cell" | nil,
---     tbl  = <table struct from parser>,
---     row  = number,   -- 1-indexed current row
---     col  = number,   -- 1-indexed current column
---   }

local M = {}

local _state = {}  -- [bufnr] = state_record

function M.get(bufnr)
  return _state[bufnr]
end

--- Create (or reset) a state record for bufnr and return it.
function M.init(bufnr)
  _state[bufnr] = { mode = nil, tbl = nil, row = 1, col = 1 }
  return _state[bufnr]
end

function M.clear(bufnr)
  _state[bufnr] = nil
end

--- Convenience: return true if the buffer is in the given mode.
function M.in_mode(bufnr, mode)
  local st = _state[bufnr]
  return st ~= nil and st.mode == mode
end

return M
