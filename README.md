# ascii-table.nvim

A pure-Lua Neovim plugin for editing ASCII tables with two dedicated modes — 
**Table mode** (structural navigation and editing) and **Cell mode** (content editing).

```
+----------+-----+----------+
| Name     | Age | City     |
+----------+-----+----------+
| Alice    | 30  | New York |
| Bob      | 25  | LA       |
+----------+-----+----------+
```

---

## Installation

### lazy.nvim
```lua
{
  "you/ascii-table.nvim",
  config = function()
    require("ascii-table").setup({
      enter_key = "<leader>tt",   -- default
    })
  end,
}
```

### packer.nvim
```lua
use {
  "you/ascii-table.nvim",
  config = function()
    require("ascii-table").setup()
  end,
}
```

---

## Quick start

| Action | How |
|--------|-----|
| Enter Table mode on an existing table | Place cursor on any table line → `<leader>tt` or `:AsciiTable` |
| Create a new 3×3 table | `:AsciiTableNew` |
| Create a 5×4 table | `:AsciiTableNew 5 4` |
| Exit Table mode | `q` or `<Esc>` |

---

## Modes

### Table mode  _(analogous to Normal mode)_

The primary interaction layer.  Active when the cursor is on a table and you
have entered via `<leader>tt` (or `:AsciiTable`).  The current cell is
highlighted.

| Key | Action |
|-----|--------|
| `h` / `←` | Move left one cell |
| `l` / `→` | Move right one cell |
| `k` / `↑` | Move up one row |
| `j` / `↓` | Move down one row |
| `<Tab>` | Next cell (wraps to next row at end of row) |
| `<S-Tab>` | Previous cell (wraps to previous row) |
| `i` / `<CR>` | **Enter Cell mode** |
| `o` | Insert empty row **below** current row |
| `O` | Insert empty row **above** current row |
| `D` | Delete current row |
| `A` | Append column **after** current column |
| `I` | Insert column **before** current column |
| `X` | Delete current column |
| `=` | Re-align / format the whole table |
| `q` / `<Esc>` | Exit Table mode |

### Cell mode  _(analogous to Insert mode)_

Opens a small **floating window** containing only the current cell's content.
Edit freely; the table is not touched until you commit.

| Key | Action |
|-----|--------|
| `<Tab>` | Commit and move to the **next** cell |
| `<S-Tab>` | Commit and move to the **previous** cell |
| `<CR>` | Commit and move **down** one row |
| `<Esc>` | Commit and **stay** on the same cell |

On commit the column width automatically expands if the new content is wider
than the current column, and shrinks to the longest remaining value if it is
narrower.

---

## Architecture

```
ascii-table.nvim/
├── lua/ascii-table/
│   ├── init.lua        – public API & setup()
│   ├── parser.lua      – detect tables, parse → struct, cursor→cell mapping
│   ├── renderer.lua    – struct → buffer lines, cursor positioning
│   ├── state.lua       – per-buffer state (mode, tbl, row, col)
│   ├── table_mode.lua  – Table mode keymaps and structural operations
│   └── cell_mode.lua   – Cell mode floating window editor
└── plugin/
    └── ascii-table.lua – user commands, double-load guard
```

### Data flow

```
Buffer lines
    │
    ▼  parser.find_bounds()  →  parser.parse()
Table struct { rows, ncols, nrows, col_widths, … }
    │
    ├──▶  table_mode  (navigate, add/remove rows/cols)
    │         │
    │         ▼  renderer.write()
    │     Buffer lines (aligned)
    │
    └──▶  cell_mode  (floating window editor)
              │
              ▼  commit(): update struct → renderer.write() → re-parse
          Buffer lines (aligned)
```

### Table struct

```lua
{
  rows        = { {"cell", …}, … },  -- 1-indexed
  nrows       = number,
  ncols       = number,
  col_widths  = { number, … },       -- content widths (no padding)
  start_line  = number,              -- 1-indexed buffer line
  end_line    = number,              -- 1-indexed buffer line
  row_to_line = { [row_idx] = relative_line_index },
}
```

---

## Supported table format

```
+--------+-----+------+
| Header | Age | City |   ← row 1 is always treated as the header
+--------+-----+------+
| Alice  | 30  | NYC  |   ← rows 2-N are body rows
| Bob    | 25  | LA   |
+--------+-----+------+
```

The plugin can **read** any table that uses `|` column separators and
`+---+---+` row separators, even if the columns are not aligned.  It always
**writes** a fully-aligned table.

---

## Lua API

```lua
local at = require("ascii-table")

at.setup({ enter_key = "<leader>tt" })

at.enter()                 -- enter Table mode (current buffer)
at.exit()                  -- exit Table mode  (current buffer)
at.create_table(rows, cols)-- insert a new table and enter Table mode
```
