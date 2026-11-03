local M = {}

-- ncu preserves range style; install through the detected manager command.
function M.npm_upgrade(prerelease)
	local file = vim.api.nvim_buf_get_name(0)
	vim.cmd.update()
	local manager = require("package-info.config").options.package_manager
	local command = {
		"ncu",
		"--packageFile",
		file,
		"--packageManager",
		manager,
		"--target",
		prerelease and "greatest" or "latest",
		"--install",
		"always",
	}
	if prerelease then
		vim.list_extend(command, { "--pre", "1", "--interactive", "--interactiveSelect", "none" })
	else
		command[#command + 1] = "--upgrade"
	end
	Snacks.terminal(command, { cwd = vim.fs.dirname(file) })
end

function M.attach(buf)
	local file = vim.api.nvim_buf_get_name(buf)
	local name = vim.fs.basename(file)
	if name ~= "Cargo.toml" and name ~= "package.json" then
		return
	end
	local function map(key, action, desc, mode)
		vim.keymap.set(mode or "n", "<leader>p" .. key, action, { buffer = buf, desc = desc })
	end

	if name == "Cargo.toml" then
		local crates = require("crates")
		map("p", crates.toggle, "Toggle Versions")
		map("r", crates.reload, "Refresh Versions")
		map("v", crates.show_versions_popup, "Versions (Including Prereleases)")
		map("f", crates.show_features_popup, "Features")
		map("u", crates.update_crate, "Update Package (Within Requirement)")
		map("u", crates.update_crates, "Update Selected Packages", "x")
		map("a", crates.update_all_crates, "Update All (Within Requirements)")
		map("U", crates.upgrade_crate, "Upgrade Package (Latest)")
		map("U", crates.upgrade_crates, "Upgrade Selected Packages", "x")
		map("A", crates.upgrade_all_crates, "Upgrade All (Latest)")
		map("d", crates.open_documentation, "Documentation")
		map("l", function()
			vim.cmd.update()
			Snacks.terminal({ "cargo", "update", "--manifest-path", file }, { cwd = vim.fs.dirname(file) })
		end, "Update Cargo Lockfile")
	else
		local packages = require("package-info")
		map("p", packages.toggle, "Toggle Versions")
		map("r", function()
			packages.show({ force = true })
		end, "Refresh Versions")
		map("v", function()
			vim.cmd.update()
			packages.change_version()
		end, "Versions (Including Prereleases)")
		map("U", function()
			vim.cmd.update()
			packages.update()
		end, "Upgrade Package (Latest)")
		map("A", function()
			M.npm_upgrade(false)
		end, "Upgrade All (Latest)")
		map("N", function()
			M.npm_upgrade(true)
		end, "Choose Upgrades (Including Prereleases)")
		map("i", function()
			vim.cmd.update()
			packages.install()
		end, "Add Package")
	end
end

return M
