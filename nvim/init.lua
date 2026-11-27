-- Neovim config, kept independent of vim/vimrc. dot install hooks it into ~/.config/nvim/init.lua.

vim.opt.number = true
vim.opt.smartindent = true
vim.opt.tabstop = 4
vim.opt.expandtab = true
vim.opt.signcolumn = "yes" -- keep the gitsigns column so text doesn't shift

-- ssh config: Enter and o/O don't continue a # comment, and Enter doesn't re-indent the line it leaves
vim.api.nvim_create_autocmd("FileType", {
    pattern = "sshconfig",
    callback = function()
        vim.opt_local.formatoptions:remove({ "r", "o" })
        vim.opt_local.indentkeys:remove("*<Return>")
    end,
})

-- Plugins: vim.pack (built into nvim 0.12) downloads them on first launch; versions aren't pinned
vim.pack.add({ "https://github.com/lewis6991/gitsigns.nvim" })

-- gitsigns: same keys as vim-gitgutter in vim
require("gitsigns").setup({
    on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
        end
        -- in diff mode ]c / [c keep their built-in meaning
        map("]c", function()
            if vim.wo.diff then vim.cmd.normal({ "]c", bang = true }) else gs.nav_hunk("next") end
        end, "next git change")
        map("[c", function()
            if vim.wo.diff then vim.cmd.normal({ "[c", bang = true }) else gs.nav_hunk("prev") end
        end, "previous git change")
        map("<leader>hp", gs.preview_hunk, "preview git change")
        map("<leader>hs", gs.stage_hunk, "stage git change")
        map("<leader>hu", gs.reset_hunk, "undo git change")
    end,
})
