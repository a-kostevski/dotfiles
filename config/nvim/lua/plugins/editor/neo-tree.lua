return {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
        '3rd/image.nvim',
    },
    cmd = "NeoTree",
    init = function()
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1
    end,
    keys = {
        { '<Leader>e', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
        {
            '<Leader>o',
            function()
                if vim.bo.filetype == 'neo-tree' then
                    vim.cmd.wincmd 'p'
                else
                    vim.cmd.Neotree 'focus'
                end
            end,
            desc = "Toggle explorer focus"
        },
    },
    opts = {
        enable_git_status = true,
        source_selector = {
            winbar = true,
            content_layout = 'center',
            sources = {
                { source = "filesystem", display_name = "File" },
                { source = "buffers",    display_name = "Bufs" },
            }
        },
        filesystem = {
            filtered_items = {
                visible = false,
                hide_dotfiles = false,
                hide_gitignored = false,
                never_show = {
                    ".DS_Store",
                }
            },
        },
        commands = {
            system_open = function(state)
                -- TODO: remove deprecated method check after dropping support for neovim v0.9
                (vim.ui.open)(state.tree:get_node():get_id())
            end,
            parent_or_close = function(state)
                local node = state.tree:get_node()
                if node:has_children() and node:is_expanded() then
                    state.commands.toggle_node(state)
                else
                    require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
                end
            end,
            child_or_open = function(state)
                local node = state.tree:get_node()
                if node:has_children() then
                    if not node:is_expanded() then     -- if unexpanded, expand
                        state.commands.toggle_node(state)
                    else                               -- if expanded and has children, seleect the next child
                        if node.type == "file" then
                            state.commands.open(state)
                        else
                            require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
                        end
                    end
                else     -- if has no children
                    state.commands.open(state)
                end
            end,
        },
        window = {
            width = 30,
            mappings = {
                ["<S-CR>"] = "system_open",
                ["<Space>"] = false,
                ["[b"] = "prev_source",
                ["]b"] = "next_source",
                O = "system_open",
                h = "parent_or_close",
                l = "child_or_open",
            },
        }
    }
}
