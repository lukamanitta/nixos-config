-- colourme owns this palette (docs/THEME-PIPELINE.md). The generated file lives
-- in the state directory so a scheme switch never dirties the repo; the table
-- below is the Gruvbox fallback for a fresh session.
local runtime = vim.fs.joinpath(
    vim.fn.expand("~/.local/state/colourme/nvim"),
    "palette.lua"
)

local chunk = loadfile(runtime)
if chunk then
    local palette = chunk()
    if palette then
        return palette
    end
end

return {
    base00 = "#282828",
    base01 = "#3c3836",
    base02 = "#504945",
    base03 = "#665c54",
    base04 = "#928374",
    base05 = "#ebdbb2",
    base06 = "#fbf1c7",
    base07 = "#f9f5d7",
    base08 = "#cc241d",
    base09 = "#d65d0e",
    base0A = "#d79921",
    base0B = "#98971a",
    base0C = "#689d6a",
    base0D = "#458588",
    base0E = "#b16286",
    base0F = "#9d0006",
}
