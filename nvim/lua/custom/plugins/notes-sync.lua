return {
	dir = vim.fn.stdpath("config"),
	name = "custom-notes-sync",
	lazy = false,
	priority = 1000,
	config = function()
		local vault_path = vim.fn.expand("~") .. "/notes-vault"

		-- We use a global variable to ensure we only pull ONCE per session.
		-- If you open 10 note files, we don't want to git pull 10 times.
		if _G.notes_synced_this_session == nil then
			_G.notes_synced_this_session = false
		end

		-- Helper: Blocking Git Pull
		local function git_pull_sync()
			if _G.notes_synced_this_session then
				return
			end

			-- Notify user (This will pause the UI briefly)
			print("Checking for updates from repo...")

			-- 'system' blocks Neovim until the command finishes
			local output = vim.fn.system("git -C " .. vault_path .. " pull --rebase --autostash")

			_G.notes_synced_this_session = true
			print("Notes ready: " .. output)
		end

		-- 1. Trigger on File Open (BEFORE Load)
		-- This handles "nvim ~/notes-vault/todo.md"
		vim.api.nvim_create_autocmd("BufReadPre", {
			pattern = vault_path .. "/*",
			callback = function()
				git_pull_sync()
			end,
		})

		-- 2. Trigger on Directory Open
		-- This handles "nvim ." inside the folder (updates the file list)
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				-- Only run if we haven't pulled yet AND we are in the vault root
				if not _G.notes_synced_this_session and string.find(vim.fn.getcwd(), vault_path, 1, true) then
					git_pull_sync()
				end
			end,
		})

		-- 3. Auto-Push on Save (Unchanged)
		local function get_commit_msg()
			local host = vim.loop.os_gethostname()
			local date = os.date("%Y-%m-%d %H:%M")
			return "auto-save: " .. date .. " (" .. host .. ")"
		end

		vim.api.nvim_create_autocmd("BufWritePost", {
			pattern = vault_path .. "/*",
			callback = function()
				local msg = get_commit_msg()
				print("Syncing... " .. msg .. " ...")
				local cmd = "git -C "
					.. vault_path
					.. " add . && git -C "
					.. vault_path
					.. " commit -m '"
					.. msg
					.. "' && git -C "
					.. vault_path
					.. " push"
				vim.fn.system(cmd)
				print("Notes synced!")
			end,
		})
	end,
}
