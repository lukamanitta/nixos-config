-- colourme owns the active scheme name (docs/THEME-PIPELINE.md). The generated
-- file lives in the state directory so a scheme switch never dirties the repo;
-- this shim loads it and keeps a Gruvbox fallback for a fresh session.
local runtime = vim.fs.joinpath(
    vim.fn.expand("~/.local/state/colourme/nvim"),
    "set_colourscheme.lua"
)

local chunk = loadfile(runtime)
if chunk then
    chunk()
else
    vim.cmd.set("background=dark")
    vim.g.colourscheme = "Gruvbox"
end
