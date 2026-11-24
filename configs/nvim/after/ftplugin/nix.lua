local U = require("h")

-- One decoration provider is enough for every nix buffer.
if vim.g.nix_embedded_bg_loaded then
    return
end
vim.g.nix_embedded_bg_loaded = true

local ns = vim.api.nvim_create_namespace("nix_embedded_bg")

local function set_hl()
    local bg = U.get_hl("CodeBlock", "bg#")
    if bg == "" then
        bg = U.get_hl("CursorLine", "bg#")
    end

    U.set_hl(
        "NixEmbeddedBg",
        bg ~= "" and { bg = bg } or { link = "CursorLine" }
    )
end

set_hl()

vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("NixEmbeddedBg", { clear = true }),
    callback = set_hl,
})

local query

local function get_query()
    if not query then
        local ok, parsed = pcall(
            vim.treesitter.query.parse,
            "nix",
            "(indented_string_expression) @block"
        )
        if ok then
            query = parsed
        end
    end
    return query
end

vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, _, bufnr, topline, botline)
        if vim.bo[bufnr].filetype ~= "nix" then
            return false
        end

        local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "nix")
        if not ok or not parser then
            return false
        end

        local tree = parser:parse()[1]
        local q = tree and get_query()
        if not q then
            return false
        end

        -- Scan from the top so strings that start above the viewport still
        -- get highlighted after scrolling.
        for _, node in q:iter_captures(tree:root(), bufnr, 0, botline + 1) do
            local start_row, _, end_row, end_col = node:range()
            if end_col == 0 and end_row > start_row then
                end_row = end_row - 1
            end

            for row = math.max(start_row, topline), math.min(end_row, botline) do
                -- line_hl_group is ignored for ephemeral extmarks, so use a
                -- line-wide hl_group range instead.
                vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
                    end_row = row + 1,
                    end_col = 0,
                    hl_group = "NixEmbeddedBg",
                    hl_eol = true,
                    ephemeral = true,
                    priority = 200,
                })
            end
        end

        return false
    end,
})
