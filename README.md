# ascii-table.nvim

Neovim plugin that *solves* text-based tables for you.

This plugin implements two modes for table manipulation: Table and Cell mode.

## Table Mode (T)
This is the primary table manipulation mode. Virtual layer over Normal mode
This mode allows you:
 * Resize the table
 * Add rows, columns 
 * Move between the cells (swiftly and comfortably)
 * Create subtables inside the parent table (up to 3 nested levels)

### Table Mode commands
| Key      | Operation        | 
|:--------:|:-----------------|
|`j`    |  Move down  |
|`k`    | Move up  |
|`w` / `l`    | Move right |
|`h`   | Move left  |
|`J`    | Extend current cell down |
|`K`   | Extend current cell up   |
|`L`    | Extend current cell right |
|`H`    | Extend current cell left |
|`n`    | Enter subtable |
|`N`    | Exit subtable  |
|`i`    | Enter Cell mode (C) |
|`a`    | Move to the last cell in the row and switch to Cell mode  |
|`I`    | Insert empty rows **above** the current row |
|`o`    | Insert empty columns **after** the current column | 
|`O`    | Insert empty columns **before** the current collumn |
|`A`    | Insert empty rows **below** the current row |
|`<Tab>`      | Move right one cell   |
|`<Shift-Tab>` | Move left one cell    |
|`=`           | Realign/format the table |
|`q` / `<Esc>`       | Exit Table Mode |

Important note: other keys that work in Normal mode are disabled

## Cell Mode (C)
This is the editing mode. Virtual layer over Insert mode
In this mode you can:
 * Change the cell's content
 * Insert line breaks (the same as resizing)
 * Insert any ASCII symbol, except **`|`** and **`-`**

### Cell Mode commands
| Key      | Operation        | 
|:--------:|:-----------------|
|`<Esc>`   | Exit Cell Mode   |

## Approximate architecture

```
ascii_table 
    lua/ascii-table/
        init.lua
        parser.lua
        renderer.lua
        table_mode.lua
        cell_mode.lua
        state.lua
        types.lua
```

## Installation (lazy.nvim)

```lua
{
    "mizrot/ascii_table.nvim",
    config = function()
        require("ascii_table").setup()
    end,
}
```
