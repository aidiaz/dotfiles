return {
	dir = vim.fn.stdpath("config"),
	name = "custom-notes-sync",
	lazy = false,
	priority = 1000,
	config = function()
		-- Configuration: Your Notes Path
		local vault_path = vim.fn.expand("~") .. "/notes-vault"

		-- Helper: Check if we are in the "Notes Context"
		-- Returns true if the File OR the Directory is inside the vault
		local function is_vault_context()
			local cwd = vim.fn.getcwd()
			local file_path = vim.api.nvim_buf_get_name(0)

			-- 1. Is the Current Working Directory inside the vault?
			if string.find(cwd, vault_path, 1, true) then
				return true
			end

			-- 2. Is the specific file open inside the vault?
			if string.find(file_path, vault_path, 1, true) then
				return true
			end

			return false
		end

		-- Helper: Generate commit message
		local function get_commit_msg()
			local host = vim.loop.os_gethostname()
			local date = os.date("%Y-%m-%d %H:%M")
			return "auto-save: " .. date .. " (" .. host .. ")"
		end

		-- 1. Auto-Pull on Startup
		-- Triggers if you open a file inside the vault OR if you open Neovim inside the folder
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				if is_vault_context() then
					-- Async pull so it doesn't freeze your startup
					vim.fn.jobstart({ "git", "-C", vault_path, "pull", "--rebase", "--autostash" }, {
						on_exit = function()
							print("Notes pulled from repo")
						end,
					})
				end
			end,
		})

		-- 2. Auto-Push on Save
		-- Only triggers when a file *inside* the vault path is saved
		vim.api.nvim_create_autocmd("BufWritePost", {
			pattern = vault_path .. "/*",
			callback = function()
				local msg = get_commit_msg()
				print("Syncing: " .. msg .. " ...")
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
