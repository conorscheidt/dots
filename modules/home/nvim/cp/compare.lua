-- competitest output_compare_method.
--
--   * whitespace is insignificant (squashed on both sides)
--   * a single float on both sides matches within 1e-5
--   * an expected file starting with a `!unordered` line (written by leetgen
--     for "in any order" problems) compares JSON with every array sorted,
--     recursively; non-JSON falls back to the squashed comparison

local UNORDERED = "!unordered"

local function squash(s)
  return (tostring(s or ""):gsub("%s+", ""))
end

local function canon(v)
  if type(v) ~= "table" then
    return vim.json.encode(v)
  end
  local parts = {}
  for i = 1, #v do
    parts[i] = canon(v[i])
  end
  table.sort(parts)
  return "[" .. table.concat(parts, ",") .. "]"
end

local function normalise(s)
  local ok, decoded = pcall(vim.json.decode, vim.trim(tostring(s or "")))
  return ok and canon(decoded) or squash(s)
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

  local so, se = squash(output), squash(expected)
  local a, b = tonumber(so), tonumber(se)
  if a and b and (so:find(".", 1, true) or se:find(".", 1, true)) then
    return math.abs(a - b) < 1e-5
  end
  if not unordered then
    return so == se
  end
  return normalise(output) == normalise(expected)
end
