-- Platform differences and the shared C/C++ flag set, in one place.
--
-- macOS uses Apple clang + libc++, Linux GCC or clang + libstdc++. They
-- differ in ways that matter, and hardcoding either side silently breaks the
-- other: a wrong hardening macro is simply ignored, not an error.

local M = {}

M.is_mac = vim.uv.os_uname().sysname == "Darwin"

---Bounds-checked containers and iterator validation: turns a silent overrun
---into a clear abort. libc++ and libstdc++ spell this differently.
---@return string[]
function M.hardening()
  if M.is_mac then
    return { "-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_DEBUG" }
  end
  -- LeetCode's judge is libstdc++ too, so this matches what it would catch.
  return { "-D_GLIBCXX_DEBUG", "-D_GLIBCXX_ASSERTIONS" }
end

---rustc's `-Zsanitizer` (nightly) needs an explicit --target on macOS.
---@return string[]
function M.rust_sanitizer()
  local args = { "-Zsanitizer=address" }
  if M.is_mac then
    local arm = vim.uv.os_uname().machine == "arm64"
    vim.list_extend(args, { "--target", arm and "aarch64-apple-darwin" or "x86_64-apple-darwin" })
  end
  return args
end

---The signedness subset of -Wconversion fires on `i < v.size()` in every
---competitive loop; the dangerous case (negative index) aborts at runtime
---under ASan plus hardening instead.
---@return string[]
function M.sign_noise()
  return { "-Wno-sign-conversion", "-Wno-sign-compare" }
end

---Compile flags shared by <leader>r*, the precompiled headers and
---competitest, so a PCH always matches the command that uses it.
---
---The <bits/stdc++.h> shim is only put on the path on macOS: libstdc++ ships
---the real header and the shim would shadow it. leetgen.hpp is needed on both.
---@param dirs { include: string, leetgen: string }
---@param sanitize boolean
---@param lang? "c"|"cpp"
---@return string[]
function M.cxx_flags(dirs, sanitize, lang)
  local flags = {
    lang == "c" and "-std=c17" or "-std=c++20",
    "-g",
    "-O0",
    "-Wall",
    "-Wextra",
    "-Wshadow",
    "-Wconversion",
    "-fno-omit-frame-pointer",
    -- Enables the `#ifdef LOCAL` main() that the leetcode.nvim injector adds;
    -- the judge never defines it, so the same file builds here and there.
    "-DLOCAL",
  }
  vim.list_extend(flags, M.sign_noise())
  if M.is_mac then
    table.insert(flags, "-I" .. dirs.include)
  end
  table.insert(flags, "-I" .. dirs.leetgen)
  if sanitize then
    vim.list_extend(flags, { "-fsanitize=address,undefined", "-fno-sanitize-recover=undefined" })
    vim.list_extend(flags, M.hardening())
  end
  return flags
end

return M
