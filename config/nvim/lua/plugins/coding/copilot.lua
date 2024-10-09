return {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    build = ":Copilot auth",
    opts = {
        auto_refresh = true,
        suggestion = { enabled = false, },
        panel = { enabled = false },
    },
}
