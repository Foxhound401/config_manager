require("neodev").setup {}

vim.lsp.set_log_level(vim.lsp.log_levels.DEBUG)

local lspconfig = vim.F.npcall(require, "lspconfig")
if not lspconfig then
  return
end

local imap = require("tj.keymap").imap
local nmap = require("tj.keymap").nmap
local autocmd = require("tj.auto").autocmd
local autocmd_clear = vim.api.nvim_clear_autocmds

local telescope_mapper = require "tj.telescope.mappings"
local handlers = require "tj.lsp.handlers"

local ts_util = require "nvim-lsp-ts-utils"
local inlays = require "tj.lsp.inlay"

local custom_init = function(client)
  client.config.flags = client.config.flags or {}
  client.config.flags.allow_incremental_sync = true
end

local augroup_highlight = vim.api.nvim_create_augroup("custom-lsp-references", { clear = true })
local augroup_codelens = vim.api.nvim_create_augroup("custom-lsp-codelens", { clear = true })

local filetype_attach = setmetatable({
  ocaml = function()
    -- Display type information
    autocmd_clear { group = augroup_codelens, buffer = 0 }
    autocmd {
      { "BufEnter", "BufWritePost", "CursorHold" },
      augroup_codelens,
      require("tj.lsp.codelens").refresh_virtlines,
      0,
    }

    vim.keymap.set(
      "n",
      "<space>tt",
      require("tj.lsp.codelens").toggle_virtlines,
      { silent = true, desc = "[T]oggle [T]ypes", buffer = 0 }
    )
  end,

  rust = function()
    telescope_mapper("<space>wf", "lsp_workspace_symbols", {
      ignore_filename = true,
      query = "#",
    }, true)
  end,
}, {
  __index = function()
    return function() end
  end,
})

local buf_nnoremap = function(opts)
  if opts[3] == nil then
    opts[3] = {}
  end
  opts[3].buffer = 0

  nmap(opts)
end

local buf_inoremap = function(opts)
  if opts[3] == nil then
    opts[3] = {}
  end
  opts[3].buffer = 0

  imap(opts)
end

local custom_attach = function(client, bufnr)
  if client.name == "copilot" then
    return
  end

  local filetype = vim.api.nvim_buf_get_option(0, "filetype")

  buf_inoremap { "<c-s>", vim.lsp.buf.signature_help }

  buf_nnoremap { "<space>cr", vim.lsp.buf.rename }
  buf_nnoremap { "<space>ca", vim.lsp.buf.code_action }

  buf_nnoremap { "gd", vim.lsp.buf.definition }
  buf_nnoremap { "gD", vim.lsp.buf.declaration }
  buf_nnoremap { "gT", vim.lsp.buf.type_definition }
  buf_nnoremap { "K", vim.lsp.buf.hover, { desc = "lsp:hover" } }

  buf_nnoremap { "<space>gI", handlers.implementation }
  buf_nnoremap { "<space>lr", "<cmd>lua R('tj.lsp.codelens').run()<CR>" }
  buf_nnoremap { "<space>rr", "LspRestart" }

  telescope_mapper("gr", "lsp_references", nil, true)
  telescope_mapper("gI", "lsp_implementations", nil, true)
  telescope_mapper("<space>wd", "lsp_document_symbols", { ignore_filename = true }, true)
  telescope_mapper("<space>ww", "lsp_dynamic_workspace_symbols", { ignore_filename = true }, true)

  vim.bo.omnifunc = "v:lua.vim.lsp.omnifunc"

  -- Set autocommands conditional on server_capabilities
  if client.server_capabilities.documentHighlightProvider then
    autocmd_clear { group = augroup_highlight, buffer = bufnr }
    autocmd { "CursorHold", augroup_highlight, vim.lsp.buf.document_highlight, bufnr }
    autocmd { "CursorMoved", augroup_highlight, vim.lsp.buf.clear_references, bufnr }
  end

  if false and client.server_capabilities.codeLensProvider then
    if filetype ~= "elm" then
      autocmd_clear { group = augroup_codelens, buffer = bufnr }
      autocmd { "BufEnter", augroup_codelens, vim.lsp.codelens.refresh, bufnr, once = true }
      autocmd { { "BufWritePost", "CursorHold" }, augroup_codelens, vim.lsp.codelens.refresh, bufnr }
    end
  end

  if filetype == "typescript" or filetype == "lua" or filetype == "clojure" then
    client.server_capabilities.semanticTokensProvider = nil
  end

  -- Attach any filetype specific options to the client
  filetype_attach[filetype]()
end

local updated_capabilities = vim.lsp.protocol.make_client_capabilities()
updated_capabilities.textDocument.completion.completionItem.snippetSupport = true
updated_capabilities.workspace.didChangeWatchedFiles.dynamicRegistration = false

-- Completion configuration
vim.tbl_deep_extend("force", updated_capabilities, require("cmp_nvim_lsp").default_capabilities())
updated_capabilities.textDocument.completion.completionItem.insertReplaceSupport = false

updated_capabilities.textDocument.codeLens = { dynamicRegistration = false }

-- local rust_analyzer, rust_analyzer_cmd = nil, { "rustup", "run", "1.73", "rust-analyzer" }
local rust_analyzer = {
  cmd = { "rustup", "run", "nightly", "rust-analyzer" },
  -- settings = {
  --   ["rust-analyzer"] = {
  --     checkOnSave = {
  --       command = "clippy",
  --     },
  --   },
  -- },
}

local servers = {
  -- Also uses `shellcheck` and `explainshell`
  bashls = true,
  lua_ls = {
    Lua = {
      workspace = {
        checkThirdParty = false,
      },
    },
  },

  -- phpactor = {
  --   filetypes = {
  --     "blade",
  --   },
  -- },

  tailwindcss = {
    init_options = {
      userLanguages = {
        elixir = "phoenix-heex",
        eruby = "erb",
        heex = "phoenix-heex",
      },
    },
    settings = {
      tailwindCSS = {
        experimental = {
          classRegex = {
            [[class: "([^"]*)]],
          },
        },
        -- filetypes_include = { "heex" },
        -- init_options = {
        --   userLanguages = {
        --     elixir = "html-eex",
        --     eelixir = "html-eex",
        --     heex = "html-eex",
        --   },
        -- },
      },
    },
  },
  intelephense = {
    -- filetypes = { "blade", "php" },
    settings = {
      intelephense = {
        format = {
          -- braces = "allman",
        },
      },
    },
  },

  pyright = true,
  -- ruff_lsp = true,
  -- pylyzer = true,

  gdscript = true,
  -- graphql = true,
  html = true,
  vimls = true,
  yamlls = true,
  ocamllsp = {
    -- cmd = { "/home/tjdevries/git/ocaml-lsp/_build/default/ocaml-lsp-server/bin/main.exe" },
    settings = {
      codelens = { enable = true },
    },

    filetypes = { "ocaml" },

    get_language_id = function(_, ftype)
      return ftype
    end,
  },

  clojure_lsp = {
    settings = {
      ["semantic-tokens?"] = false,
    },
  },

  -- Enable jsonls with json schemas
  jsonls = {
    settings = {
      json = {
        schemas = require("schemastore").json.schemas(),
        validate = { enable = true },
      },
    },
  },

  -- TODO: Test the other Ruby LSPs?
  -- solargraph = { cmd = { "bundle", "exec", "solargraph", "stdio" } },
  -- sorbet = true,

  cmake = (1 == vim.fn.executable "cmake-language-server"),
  dartls = pcall(require, "flutter-tools"),

  clangd = {
    cmd = {
      "clangd",
      "--background-index",
      "--suggest-missing-includes",
      "--clang-tidy",
      "--header-insertion=iwyu",
    },
    init_options = {
      clangdFileStatus = true,
    },
    filetypes = {
      "c",
    },
  },

  svelte = true,

  -- Elixir
  -- elixirls = true,
  lexical = {
    cmd = { "/home/tjdevries/.local/share/nvim/mason/bin/lexical", "server" },
    root_dir = require("lspconfig.util").root_pattern { "mix.exs" },
  },

  templ = true,
  gopls = {
    -- root_dir = function(fname)
    --   local Path = require "plenary.path"
    --
    --   local absolute_cwd = Path:new(vim.loop.cwd()):absolute()
    --   local absolute_fname = Path:new(fname):absolute()
    --
    --   if string.find(absolute_cwd, "/cmd/", 1, true) and string.find(absolute_fname, absolute_cwd, 1, true) then
    --     return absolute_cwd
    --   end
    --
    --   return lspconfig_util.root_pattern("go.mod", ".git")(fname)
    -- end,

    settings = {
      gopls = {
        codelenses = { test = true },
        hints = inlays and {
          assignVariableTypes = true,
          compositeLiteralFields = true,
          compositeLiteralTypes = true,
          constantValues = true,
          functionTypeParameters = true,
          parameterNames = true,
          rangeVariableTypes = true,
        } or nil,
      },
    },

    flags = {
      debounce_text_changes = 200,
    },
  },

  omnisharp = {
    cmd = { vim.fn.expand "~/build/omnisharp/run", "--languageserver", "--hostPID", tostring(vim.fn.getpid()) },
  },

  rust_analyzer = rust_analyzer,

  racket_langserver = true,

  elmls = true,
  cssls = true,
  perlnavigator = true,

  -- nix language server
  nil_ls = true,

  -- eslint = true,
  tsserver = {
    init_options = ts_util.init_options,
    cmd = { "typescript-language-server", "--stdio" },
    filetypes = {
      "javascript",
      "javascriptreact",
      "javascript.jsx",
      "typescript",
      "typescriptreact",
      "typescript.tsx",
    },

    on_attach = function(client)
      custom_attach(client)

      ts_util.setup { auto_inlay_hints = false }
      ts_util.setup_client(client)
    end,
  },
}

-- if vim.fn.executable "llmsp" == 1 and vim.env.SRC_ACCESS_TOKEN then
--   vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
--     pattern = { "*" },
--     callback = function()
--       vim.lsp.start {
--         name = "llmsp",
--         cmd = { "llmsp" },
--         root_dir = vim.fs.dirname(vim.fs.find({ "go.mod", ".git" }, { upward = true })[1]),
--         capabilities = updated_capabilities,
--         on_attach = custom_attach,
--         settings = {
--           llmsp = {
--             sourcegraph = {
--               url = vim.env.SRC_ENDPOINT,
--               accessToken = vim.env.SRC_ACCESS_TOKEN,
--             },
--           },
--         },
--       }
--     end,
--   })
-- end

-- Can remove later if not installed (TODO: enable for not linux)
if vim.fn.executable "tree-sitter-grammar-lsp-linux" == 1 then
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    pattern = { "grammar.js", "*/corpus/*.txt" },
    callback = function()
      vim.lsp.start {
        name = "tree-sitter-grammar-lsp",
        cmd = { "tree-sitter-grammar-lsp-linux" },
        root_dir = "/",
        capabilities = updated_capabilities,
        on_attach = custom_attach,
      }
    end,
  })
end

require("mason").setup()
require("mason-lspconfig").setup {
  ensure_installed = { "lua_ls", "jsonls", "pyright" },
}

local setup_server = function(server, config)
  if not config then
    return
  end

  if type(config) ~= "table" then
    config = {}
  end

  config = vim.tbl_deep_extend("force", {
    on_init = custom_init,
    on_attach = custom_attach,
    capabilities = updated_capabilities,
  }, config)

  lspconfig[server].setup(config)
end

for server, config in pairs(servers) do
  setup_server(server, config)
end

--[ An example of using functions...
-- 0. nil -> do default (could be enabled or disabled)
-- 1. false -> disable it
-- 2. true -> enable, use defaults
-- 3. table -> enable, with (some) overrides
-- 4. function -> can return any of above
--
-- vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, method, params, client_id, bufnr, config)
--   local uri = params.uri
--
--   vim.lsp.with(
--     vim.lsp.diagnostic.on_publish_diagnostics, {
--       underline = true,
--       virtual_text = true,
--       signs = sign_decider,
--       update_in_insert = false,
--     }
--   )(err, method, params, client_id, bufnr, config)
--
--   bufnr = bufnr or vim.uri_to_bufnr(uri)
--
--   if bufnr == vim.api.nvim_get_current_buf() then
--     vim.lsp.diagnostic.set_loclist { open_loclist = false }
--   end
-- end
--]]

-- Only run stylua when we can find a root dir
require("conform.formatters.stylua").require_cwd = true

require("conform").setup {
  formatters_by_ft = {
    lua = { "stylua" },
    typescript = { { "prettierd", "prettier" } },
    javascript = { { "prettierd", "prettier" } },
    -- php = { "pint" },
    -- blade = { "prettierd" },
    blade = { "blade-formatter" },
  },
}

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function(args)
    require("conform").format { bufnr = args.buf, lsp_fallback = true }
  end,
})

-- require("null-ls").setup {
--   sources = {
--     -- require("null-ls").builtins.formatting.stylua,
--     -- require("null-ls").builtins.diagnostics.eslint,
--     -- require("null-ls").builtins.completion.spell,
--     -- require("null-ls").builtins.diagnostics.selene,
--     require("null-ls").builtins.formatting.prettierd,
--     require("null-ls").builtins.formatting.isort,
--     require("null-ls").builtins.formatting.black,
--   },
-- }

local has_metals = pcall(require, "metals")
if has_metals and false then
  local metals_config = require("metals").bare_config()
  metals_config.on_attach = custom_attach

  -- Example of settings
  metals_config.settings = {
    showImplicitArguments = true,
    excludedPackages = { "akka.actor.typed.javadsl", "com.github.swagger.akka.javadsl" },
  }

  -- Autocmd that will actually be in charging of starting the whole thing
  local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    -- NOTE: You may or may not want java included here. You will need it if you
    -- want basic Java support but it may also conflict if you are using
    -- something like nvim-jdtls which also works on a java filetype autocmd.
    pattern = { "scala", "sbt", "java" },
    callback = function()
      require("metals").initialize_or_attach(metals_config)
    end,
    group = nvim_metals_group,
  })
end

return {
  on_init = custom_init,
  on_attach = custom_attach,
  capabilities = updated_capabilities,
}
