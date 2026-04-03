local function find_dotnet_dll()
  -- Auto-detect the project dll under bin/Debug/{tfm}/{Name}.dll
  local dlls = vim.fn.glob(vim.fn.getcwd() .. "/**/bin/Debug/**/*.dll", false, true)
  local exe_dlls = vim.tbl_filter(function(path)
    -- Match exactly: …/bin/Debug/<tfm>/<name>.dll (one dll deep, not nested deps)
    return path:match("bin/Debug/[^/]+/[^/]+%.dll$") ~= nil
  end, dlls)
  if #exe_dlls == 1 then
    return exe_dlls[1]
  end
  return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
end

return {
  -- ── Core DAP ────────────────────────────────────────────────────────────────
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
      {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = { "williamboman/mason.nvim" },
        opts = {
          ensure_installed = { "netcoredbg" },
          handlers = {},
        },
      },
    },
    keys = {
      { "<F5>",        function() require("dap").continue() end,          desc = "Debug: Continue" },
      { "<F10>",       function() require("dap").step_over() end,         desc = "Debug: Step Over" },
      { "<F11>",       function() require("dap").step_into() end,         desc = "Debug: Step Into" },
      { "<F12>",       function() require("dap").step_out() end,          desc = "Debug: Step Out" },
      { "<leader>b",   function() require("dap").toggle_breakpoint() end, desc = "Debug: Toggle Breakpoint" },
      { "<leader>B",   function()
          require("dap").set_breakpoint(vim.fn.input("Condition: "))
        end,                                                               desc = "Debug: Conditional Breakpoint" },
      { "<leader>dr",  function() require("dap").repl.open() end,         desc = "Debug: Open REPL" },
      { "<leader>dl",  function() require("dap").run_last() end,          desc = "Debug: Run Last" },
      { "<leader>du",  function() require("dapui").toggle() end,          desc = "Debug: Toggle UI" },
      { "<leader>de",  function() require("dapui").eval(nil, { enter = true }) end,
                                                                           desc = "Debug: Eval Expression" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- ── DAP UI ──────────────────────────────────────────────────────────────
      dapui.setup({
        icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
        layouts = {
          {
            elements = {
              { id = "scopes",      size = 0.40 },
              { id = "breakpoints", size = 0.20 },
              { id = "stacks",      size = 0.20 },
              { id = "watches",     size = 0.20 },
            },
            size = 40,
            position = "left",
          },
          {
            elements = {
              { id = "repl",    size = 0.5 },
              { id = "console", size = 0.5 },
            },
            size = 10,
            position = "bottom",
          },
        },
      })

      -- Auto-open/close UI when a debug session starts/ends
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      -- ── Virtual text for inline variable values ──────────────────────────────
      require("nvim-dap-virtual-text").setup({
        display_callback = function(variable, _, _, _, options)
          if #variable.value > 50 then
            return " " .. string.sub(variable.value, 1, 50) .. "…"
          end
          return " " .. variable.value
        end,
      })

      -- ── Diagnostic signs ────────────────────────────────────────────────────
      vim.fn.sign_define("DapBreakpoint",          { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
      vim.fn.sign_define("DapBreakpointRejected",  { text = "○", texthl = "DiagnosticHint" })
      vim.fn.sign_define("DapStopped",             { text = "▶", texthl = "DiagnosticOk", linehl = "DapStoppedLine" })

      -- ── netcoredbg adapter ──────────────────────────────────────────────────
      dap.adapters.coreclr = {
        type = "executable",
        command = vim.fn.stdpath("data") .. "/mason/bin/netcoredbg",
        args = { "--interpreter=vscode" },
      }

      -- ── C# launch configurations ────────────────────────────────────────────
      dap.configurations.cs = {
        {
          type = "coreclr",
          name = "Launch (auto-detect dll)",
          request = "launch",
          program = find_dotnet_dll,
          cwd = "${workspaceFolder}",
          stopAtEntry = false,
          console = "integratedTerminal",
          env = {
            ASPNETCORE_ENVIRONMENT = "Development",
          },
        },
        {
          type = "coreclr",
          name = "Launch (pick dll)",
          request = "launch",
          program = function()
            return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopAtEntry = false,
          console = "integratedTerminal",
        },
        {
          type = "coreclr",
          name = "Attach to process",
          request = "attach",
          processId = function()
            return require("dap.utils").pick_process()
          end,
        },
      }
    end,
  },
}
