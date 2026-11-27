vim.pack.add({
    { src = "https://github.com/github/copilot.vim" },
})

require("h").overwrite_keys(vim.g, {
    copilot_no_tab_map = true,
    copilot_assume_mapped = true,
    -- Plain `npx` prints "package was not found and will be installed" on
    -- every launch even with a warm cache. `--yes` reuses it silently.
    copilot_npx_command = { "npx", "--yes" },
    -- copilot_filetypes = { rust = false },
})
