local M = {}
local ns_id = vim.api.nvim_create_namespace("soluna_ghost_lines")
local lint_ns = vim.api.nvim_create_namespace("soluna_linter")
local current_job_id = nil

M.defaults = {
	linter_delay = 500,
	lint_on_change = true,
	lint_on_save = true,
	ghost_text_prefix = "󰈑 ",
	error_prefix = "󰅚 ",
	evaluatation_style = "ghost",
	highlight_groups = {
		result = "Comment",
		error = "DiagnosticError",
	}
}

function M.setup(user_config)
	M.config = vim.tbl_deep_extend("force", M.defaults, user_config or {})
	if M.config.lint_on_change then
		vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
			pattern = "*.luna",
			callback = function() M.diagnostic_lint_on_the_fly() end,
		})
	end
	if M.config.lint_on_save then
		vim.api.nvim_create_autocmd({ "BufWritePost" }, {
			pattern = "*.luna",
			callback = function() M.diagnostic_lint_on_the_fly() end,
		})
	end
end

local output_buf = nil

local function get_output_buffer()
	local current_win = vim.api.nvim_get_current_win()
    if not output_buf or not vim.api.nvim_buf_is_valid(output_buf) then
        output_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(output_buf, "Soluna Output")
        vim.api.nvim_buf_set_option(output_buf, "buftype", "nofile")
    end
    local win = vim.fn.bufwinid(output_buf)
    if win == -1 then
        vim.cmd("botright split")
        vim.api.nvim_win_set_buf(0, output_buf)
		vim.wo.number = false
		vim.wo.relativenumber = false
		vim.wo.winfixwidth = true
		vim.api.nvim_set_current_win(current_win)
		vim.cmd("horizontal resize " .. (M.config.evaluatation_buffer_width or 30))
    end
    return output_buf
end

local function strip_ansi(text)
	if not text then return "" end
	local clean = text:gsub("\27%[[%d;]*m", "")
	clean = clean:gsub("\27%[K", "")
	return clean
end

local lint_timer = vim.loop.new_timer()

function M.diagnostic_lint_on_the_fly()
	local buf = vim.api.nvim_get_current_buf()
	lint_timer:stop()
	lint_timer:start(M.config.linter_delay, 0, vim.schedule_wrap(function()
		if not vim.api.nvim_buf_is_valid(buf) then return end
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local content = table.concat(lines, "\n")
		vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
		vim.diagnostic.reset(lint_ns, buf)
		M.evaluate(buf, content, #lines, false, 0, M.config.evaluatation_style)
	end))
end

function M.diagnostic_lint()
	local buf = vim.api.nvim_get_current_buf()
	local diagnostics = {}
	vim.fn.jobstart({"soluna", vim.api.nvim_buf_get_name(buf)}, {
		on_stderr = function(_, data)
			if not data then return end
			for _, line in ipairs(data) do
				local clean = strip_ansi(line)
				local l, msg = clean:match("%[Soluna ERROR%].-%:(%d+)%s*->%s*(.*)")
				if l and msg then
					table.insert(diagnostics, {
						lnum = tonumber(l) - 1,
						col = 0,
						end_lnum = tonumber(l) - 1,
						end_col = 999,
						severity = vim.diagnostic.severity.ERROR,
						message = msg,
						source = "Soluna",
					})
				end
			end
		end,
		on_exit = function()
			vim.diagnostic.set(lint_ns, buf, diagnostics)
		end
	})
end

function M.evaluate(buf, content, target, nl, line_offset, output_mode)
	line_offset = line_offset or 0
	local stdout_output = {}
	local diagnostics = {}
	local hl_result = M.config.highlight_groups.result
	local hl_error = M.config.highlight_groups.error
	if current_job_id then
        vim.fn.jobstop(current_job_id)
        current_job_id = nil
    end

	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
	vim.diagnostic.reset(lint_ns, buf)
	current_job_id = vim.fn.jobstart({"soluna", "-e", content}, {
		stdout_buffered = false,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line ~= "" then 
						table.insert(stdout_output, strip_ansi(line)) 
					end
				end
			end
		end,
		on_stderr = function(_, data)
			if data then
				for _, line in ipairs(data) do
					local clean_line = strip_ansi(line)
					local l, msg = clean_line:match("%[Soluna ERROR%].-%:(%d+)%s*->%s*(.*)")
					if l and msg then
						local actual_line = tonumber(l) - 1 + line_offset
						local line_count = vim.api.nvim_buf_line_count(buf)
						if actual_line >= 0 and actual_line < line_count then
							table.insert(diagnostics, {
								lnum = actual_line,
								col = 0,
								end_lnum = actual_line,
								end_col = 999,
								severity = vim.diagnostic.severity.ERROR,
								message = msg,
								source = "Soluna",
							})
							vim.api.nvim_buf_set_extmark(buf, ns_id, actual_line, 0, {
								virt_lines = { { { M.config.error_prefix .. msg, hl_error } } },
								virt_lines_above = false,
							})
						end
					end
				end
			end
		end,
		on_exit = function()
			current_job_id = nil
			vim.diagnostic.set(lint_ns, buf, diagnostics)
			if #stdout_output > 0 then
				if output_mode == "buffer" then
					local obuf = get_output_buffer()
					vim.api.nvim_buf_set_lines(obuf, 0, -1, false, stdout_output)
					local win = vim.fn.bufwinid(obuf)
					if win ~= -1 then
						vim.api.nvim_win_set_cursor(win, {vim.api.nvim_buf_line_count(obuf), 0})
					end
				else
					local line_count = vim.api.nvim_buf_line_count(buf)
					local safe_target = math.min(target - 1, line_count - 1)
					if safe_target >= 0 then
						local virt_lines = {}
						if nl then table.insert(virt_lines, "\n") end
						for _, text in ipairs(stdout_output) do
							table.insert(virt_lines, { { M.config.ghost_text_prefix .. text, hl_result } })
						end
						vim.api.nvim_buf_set_extmark(buf, ns_id, safe_target, 0, {
							virt_lines = virt_lines,
							virt_lines_above = false,
						})
					end
				end
			end
		end
	})
end

function M.evaluate_file()
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local content = table.concat(lines, "")
	local last_line = vim.api.nvim_buf_line_count(buf)
	M.evaluate(buf, content, last_line, false, M.config.evaluation_style)
end

function M.evaluate_lines()
	local buf = vim.api.nvim_get_current_buf()
	local _, s_row, _, _ = unpack(vim.fn.getpos("v"))
	local _, e_row, _, _ = unpack(vim.fn.getpos("."))
	if s_row > e_row then
		s_row, e_row = e_row, s_row
	end
	local lines = vim.api.nvim_buf_get_lines(0, s_row - 1, e_row, false)
	if #lines == 0 then return end
	local content = table.concat(lines, "")
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
	M.evaluate(buf, content, e_row, false, s_row - 1, M.config.evaluation_style)
end

function M.evaluate_clear()
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
end

return M
