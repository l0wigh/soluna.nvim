# soluna.nvim

**soluna.nvim** is an interactive Neovim plugin designed for the [**Soluna** language](https://github.com/L0Wigh/Soluna). It provides a seamless development experience with a real-time linter and integrated code evaluation (via Ghost Text or a dedicated Output Buffer).

<p align="center" width="100%">
    <img src="https://raw.githubusercontent.com/l0wigh/soluna.nvim/refs/heads/master/soluna.gif">
</p>

## Features

* **On-the-fly Linter**: Automatic syntax analysis as you type or upon saving.
* **Ghost Text**: Displays results and errors directly below the relevant line without moving your cursor.
* **Split Output**: A dedicated, automatic side-panel for full file execution results.
* **Native Diagnostics**: Full integration with Neovim's diagnostic system (red underlines and sign column).

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "L0Wigh/soluna.nvim",
    ft = "luna", 
    config = function()
        require("soluna").setup({
            -- Linter settings
            linter_delay = 500,             -- Delay (ms) before automatic analysis triggers
            eval_disabled_at_start = true,  -- If true, you'll need to use soluna.toggle_evaluation to enable auto-linter
            lint_on_change = true,          -- Run linter while typing
            lint_on_save = true,            -- Run linter on file save
            ghost_text_prefix = "󰈑 ",       -- Icon prefix for stdout results
            error_prefix = "󰅚 ",            -- Icon prefix for error messages
            
            -- Evaluation Behavior
            evaluation_style = "ghost",     -- Default display mode ("ghost" or "buffer")
            evaluation_buffer_width = 30,   -- Width of the right-side output panel
            
            -- Colors (Highlight Groups)
            highlight_groups = {
                result = "Comment",         -- Highlight group for ghost results
                error = "DiagnosticError",  -- Highlight group for ghost errors
            }

            -- Value to send when an input is asked
            input_to_send = "default_nvim_input"
        })
    end,
}
```

## Keybinds

```lua
local soluna = require("soluna")
vim.keymap.set("n", "<leader>sf", soluna.evaluate_file)
vim.keymap.set({"n", "v"}, "<leader>sl", soluna.evaluate_lines)
vim.keymap.set("n", "<leader>sc", soluna.evaluate_clear)
vim.keymap.set("n", "<leader>ss", soluna.set_input_value)
vim.keymap.set("n", "<leader>st", soluna.toggle_evaluation)
```
