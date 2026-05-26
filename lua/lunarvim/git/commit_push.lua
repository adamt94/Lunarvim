local M = {}

local data_dir   = vim.fn.stdpath("data") .. "/lunarvim"
local cfg_path   = data_dir .. "/commit_push.json"

local MODELS = {
  { id = "claude-opus-4-7",           label = "Opus 4.7    (most capable)" },
  { id = "claude-sonnet-4-6",         label = "Sonnet 4.6  (recommended)"  },
  { id = "claude-haiku-4-5-20251001", label = "Haiku 4.5   (fastest)"      },
}

local defaults = { model = "claude-sonnet-4-6", auto_push = true }

local function read_cfg()
  if vim.fn.filereadable(cfg_path) == 0 then return vim.deepcopy(defaults) end
  local lines = vim.fn.readfile(cfg_path)
  if #lines == 0 then return vim.deepcopy(defaults) end
  local ok, data = pcall(vim.json.decode, table.concat(lines, ""))
  return ok and data or vim.deepcopy(defaults)
end

local function write_cfg(cfg)
  vim.fn.mkdir(data_dir, "p")
  vim.fn.writefile({ vim.json.encode(cfg) }, cfg_path)
end

function M.get_config() return read_cfg() end

function M.set_model(model)
  local cfg = read_cfg()
  cfg.model = model
  write_cfg(cfg)
  vim.notify("[git] Commit model → " .. model, vim.log.levels.INFO)
end

function M.pick_model()
  local cfg = read_cfg()
  vim.ui.select(MODELS, {
    prompt      = "Commit message model (current: " .. cfg.model .. "):",
    format_item = function(item) return item.label end,
  }, function(choice)
    if not choice then return end
    M.set_model(choice.id)
  end)
end

-- Run cmd (list), optionally in cwd. callback(stdout_str, err_str_or_nil).
local function run(cmd, cwd, callback)
  local out, err = {}, {}
  local opts = {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      for _, l in ipairs(data) do if l ~= "" then out[#out + 1] = l end end
    end,
    on_stderr = function(_, data)
      for _, l in ipairs(data) do if l ~= "" then err[#err + 1] = l end end
    end,
    on_exit = function(_, code)
      local o = table.concat(out, "\n")
      local e = code ~= 0 and (next(err) and table.concat(err, "\n") or ("exit " .. code)) or nil
      callback(o, e)
    end,
  }
  if cwd then opts.cwd = cwd end
  vim.fn.jobstart(cmd, opts)
end

local function notify(msg, level)
  vim.notify("  " .. msg, level or vim.log.levels.INFO)
end

function M.commit_and_push(project)
  if not project then
    notify("No project at cursor", vim.log.levels.WARN)
    return
  end
  -- SSH paths can't be operated on locally
  if project:match("^[^/%s][^:]*:/") then
    notify("SSH project – open a terminal to commit there", vim.log.levels.WARN)
    return
  end
  if vim.fn.isdirectory(project) == 0 then
    notify("Directory not found: " .. project, vim.log.levels.WARN)
    return
  end

  local cfg = read_cfg()

  notify("Staging all changes…")

  run({ "git", "add", "-A" }, project, function(_, add_err)
    if add_err then
      vim.schedule(function() notify("Stage failed: " .. add_err, vim.log.levels.ERROR) end)
      return
    end

    run({ "git", "diff", "--cached", "--name-only" }, project, function(names, diff_err)
      if diff_err then
        vim.schedule(function() notify("Diff check failed: " .. diff_err, vim.log.levels.ERROR) end)
        return
      end

      if names == "" then
        vim.schedule(function() notify("Nothing to commit", vim.log.levels.INFO) end)
        return
      end

      -- Collect diff for prompt (truncate to keep tokens sane)
      run({ "git", "diff", "--cached" }, project, function(diff, _)
        local prompt_diff = (diff ~= "" and diff or names):sub(1, 8000)

        local prompt = table.concat({
          "Write a git commit message in imperative mood.",
          "Subject line: ≤72 chars. If body is needed, add a blank line then bullet points.",
          "Output ONLY the commit message — no quotes, no markdown fences, no explanation.",
          "",
          "Diff:",
          prompt_diff,
        }, "\n")

        vim.schedule(function()
          notify("Generating commit message with " .. cfg.model .. "…")
        end)

        run({ "claude", "-p", prompt, "--model", cfg.model }, nil, function(msg, claude_err)
          vim.schedule(function()
            if claude_err or not msg or msg:match("^%s*$") then
              notify("Claude failed: " .. (claude_err or "empty response"), vim.log.levels.ERROR)
              return
            end

            msg = msg:match("^%s*(.-)%s*$")

            vim.ui.input({ prompt = "Commit: ", default = msg }, function(final)
              if not final or final == "" then
                notify("Commit cancelled")
                return
              end

              run({ "git", "commit", "-m", final }, project, function(_, commit_err)
                vim.schedule(function()
                  if commit_err then
                    notify("Commit failed: " .. commit_err, vim.log.levels.ERROR)
                    return
                  end

                  if not cfg.auto_push then
                    notify("Committed ✓")
                    return
                  end

                  notify("Pushing…")
                  run({ "git", "push" }, project, function(_, push_err)
                    vim.schedule(function()
                      if push_err then
                        -- Try with --set-upstream on first push of a branch
                        run(
                          { "git", "push", "--set-upstream", "origin", "HEAD" },
                          project,
                          function(_, su_err)
                            vim.schedule(function()
                              if su_err then
                                notify("Push failed: " .. push_err, vim.log.levels.ERROR)
                              else
                                notify("Committed & pushed ✓")
                              end
                            end)
                          end
                        )
                      else
                        notify("Committed & pushed ✓")
                      end
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end)
end

return M
