-- Whether a testcase's output matches its expected file.
--
--   * whitespace between tokens is insignificant; token boundaries remain
--   * valid JSON preserves string content and compares parsed values
--   * a single float on both sides matches within 1e-5
--   * an expected file starting with a `!unordered` line (written by leetgen
--     for "in any order" problems) compares JSON with every array sorted,
--     recursively; non-JSON falls back to the squashed comparison

local UNORDERED = "!unordered"

local function tokens(s)
  return (vim.trim(tostring(s or "")):gsub("%s+", " "))
end

local function canon(v, unordered)
  if type(v) ~= "table" then
    return vim.json.encode(v)
  end
  local parts = {}
  if vim.islist(v) then
    for i = 1, #v do
      parts[i] = canon(v[i], unordered)
    end
    if unordered then
      table.sort(parts)
    end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  local keys = vim.tbl_keys(v)
  table.sort(keys)
  for _, key in ipairs(keys) do
    parts[#parts + 1] = vim.json.encode(key) .. ":" .. canon(v[key], unordered)
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function normalise(s, unordered)
  local ok, decoded = pcall(vim.json.decode, vim.trim(tostring(s or "")))
  return ok and canon(decoded, unordered) or tokens(s)
end

---@param output string
---@param expected string
---@return boolean
return function(output, expected)
  expected = tostring(expected or "")
  local unordered = false
  local first, rest = expected:match("^%s*([^\n]*)\n(.*)$")
  if first and vim.trim(first) == UNORDERED then
    unordered, expected = true, rest
  end

  local so, se = vim.trim(tostring(output or "")), vim.trim(expected)
  local a, b = tonumber(so), tonumber(se)
  if a and b and (so:find(".", 1, true) or se:find(".", 1, true)) then
    return math.abs(a - b) < 1e-5
  end
  return normalise(output, unordered) == normalise(expected, unordered)
end
