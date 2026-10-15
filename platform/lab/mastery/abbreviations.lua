--[[ abbreviations.lua — define every abbreviation at first use, then cross-reference it.

For each document (each book chapter is rendered on its own):
  * the FIRST time an abbreviation in abbreviations.txt appears in the prose, it is
    written out:  "Azure Data Factory (ADF)";
  * every LATER use becomes <abbr title="Azure Data Factory">ADF</abbr>, linked to
    its entry in the Abbreviations appendix (hover for the meaning, click for the list);
  * code, headings, link text and images are never changed;
  * if the author already wrote "full name (ABBR)", that counts as the definition.

A Div with id "abbreviation-list" is replaced by the full alphabetical table.
Options (document or project metadata):
  abbr-expand: false              -- switch the filter off for a document
  abbreviations-link: "<url>"     -- where the appendix lives (default e-abbreviations.html)
]]

local DICT, KEYS, PROTECT = {}, {}, {}
local UNITS = { GB = true, MB = true, KB = true }
local seen, buffer = {}, ""
local link_base = "e-abbreviations.html"
local enabled = true

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function slug(k) return "abbr-" .. k:lower():gsub("[^%w]+", "-") end
local function esc(s) return (s:gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
local function norm(s) return (s:lower():gsub("[%-–—]", " "):gsub("%s+", " ")) end

local function load_dict()
  local dir = PANDOC_SCRIPT_FILE:match("(.*[/\\])") or "./"
  local f = io.open(dir .. "abbreviations.txt", "r")
  if not f then return end
  for line in f:lines() do
    local prot = line:match("^!%s*(.-)%s*$")
    if prot then PROTECT[#PROTECT + 1] = prot
    elseif not line:match("^%s*#") and line:match("|") then
      local parts = {}
      for p in (line .. "|"):gmatch("(.-)|") do parts[#parts + 1] = trim(p) end
      local key, name, plural = parts[1], parts[2], parts[3]
      if key ~= "" and name and name ~= "" then
        local main = trim(name:gsub("%s*%b()%s*$", ""))   -- drop a trailing "(note)"
        DICT[key] = { name = name, main = main,
                      plural = (plural and plural ~= "") and plural or (main .. "s") }
        KEYS[#KEYS + 1] = key
      end
    end
  end
  f:close()
  table.sort(KEYS, function(a, b) return a:lower() < b:lower() end)
end

-- Is this token an abbreviation we know? Returns key, is_plural.
local function lookup(tok)
  if DICT[tok] then return tok, false end
  local stem = tok:match("^(.-)s$")
  if stem and #stem >= 2 and DICT[stem] and stem:upper() == stem then return stem, true end
  return nil
end

local function sentence_start()
  local b = buffer:gsub("%s+$", "")
  return b == "" or b:match("[%.!?]$") ~= nil
end

local function cap(s) return (s:gsub("^%l", string.upper)) end

-- Build the inline(s) for one occurrence of `tok` (key `key`).
local function render(tok, key, plural, in_link, before, after, num)
  local d = DICT[key]
  local ctx = buffer .. before .. tok .. after
  for _, ph in ipairs(PROTECT) do
    local ts = #buffer + #before + 1
    local i = ctx:find(ph, math.max(1, ts - #ph), true)
    while i and i <= ts do
      if i + #ph - 1 >= ts + #tok - 1 then return { pandoc.Str(tok) } end
      i = ctx:find(ph, i + 1, true)
    end
  end
  if UNITS[key] and (buffer .. before):match("%d[%d%.,]*%s*$") and not (buffer .. before):match("%f[%d]1%s*$") then
    plural = true
  end
  if not seen[key] then
    seen[key] = true
    -- author already defined it: "... full name (ABBR"
    if before:sub(-1) == "(" then
      local prior = norm(buffer .. before:sub(1, -2))
      local want = norm(plural and d.plural or d.main)
      if prior:gsub("%s+$", ""):sub(-#want) == want then return { pandoc.Str(tok) } end
    end
    local full = plural and d.plural or d.main
    if num then full = full .. " " .. num end   -- a code like FY2025 -> "financial year 2025 (FY2025)"
    if sentence_start() and before == "" then full = cap(full) end
    return { pandoc.Str(full .. " (" .. tok .. ")") }
  end
  if in_link then return { pandoc.Str(tok) } end
  return { pandoc.RawInline("html", string.format(
    '<a class="abbr-ref" href="%s#%s"><abbr title="%s">%s</abbr></a>',
    link_base, slug(key), esc(d.name), esc(tok))) }
end

-- Split one Str into plain text and abbreviation pieces.
local function process_str(s, in_link)
  local out, text, pos, changed = {}, s, 1, false
  for start, tok, stop in text:gmatch("()([%w&/%-]+)()") do
    local pieces = {}
    local key, plural = lookup(tok)
    local pre = tok:match("^(%l+%-)%u")             -- "non-UTF-8", "re-API"
    local k3, pl3
    if not key and pre then k3, pl3 = lookup(tok:sub(#pre + 1)) end
    local pfx, num = tok:match("^(%u%u+)(%d+)$")      -- "FY2025" -> financial year 2025 (FY2025)
    if key then
      pieces = { { tok = tok, off = 0, key = key, plural = plural } }
    elseif pfx and DICT[pfx] then
      pieces = { { tok = tok, off = 0, key = pfx, plural = false, num = num } }
    elseif k3 then
      pieces = { { tok = tok:sub(#pre + 1), off = #pre, key = k3, plural = pl3 } }
    else  -- try the parts of "Fivetran/ADF", "OT/IT", "TF-IDF"
      for ps, part in tok:gmatch("()([^/%-]+)") do
        local k2, pl2 = lookup(part)
        if k2 then pieces[#pieces + 1] = { tok = part, off = ps - 1, key = k2, plural = pl2 } end
      end
    end
    for _, p in ipairs(pieces) do
      local a = start + p.off
      local before = text:sub(pos, a - 1)
      if before ~= "" then out[#out + 1] = pandoc.Str(before) end
      for _, il in ipairs(render(p.tok, p.key, p.plural, in_link, text:sub(1, a - 1), text:sub(a + #p.tok), p.num)) do
        out[#out + 1] = il
      end
      pos = a + #p.tok
      changed = true
    end
  end
  buffer = buffer .. s
  if not changed then return nil end
  if pos <= #text then out[#out + 1] = pandoc.Str(text:sub(pos)) end
  return out
end

local process_inlines

local function walk_inline(el, in_link, out)
  local t = el.t
  if t == "Str" then
    local r = process_str(el.text, in_link)
    if r then for _, x in ipairs(r) do out[#out + 1] = x end else out[#out + 1] = el end
    return
  elseif t == "Space" or t == "SoftBreak" or t == "LineBreak" then
    buffer = buffer .. " "
  elseif t == "Code" then
    buffer = buffer .. el.text
  elseif t == "Link" then
    el.content = process_inlines(el.content, true)
  elseif t == "Emph" or t == "Strong" or t == "Span" or t == "Underline" or t == "Strikeout"
      or t == "SmallCaps" or t == "Quoted" or t == "Superscript" or t == "Subscript" then
    el.content = process_inlines(el.content, in_link)
  elseif t == "Note" then
    el.content = el.content:walk({ traverse = "topdown", Header = function(h) return h, false end,
      Inlines = function(ils) return process_inlines(ils, false), false end })
  end
  out[#out + 1] = el
end

process_inlines = function(ils, in_link)
  local out = pandoc.Inlines({})
  for _, el in ipairs(ils) do walk_inline(el, in_link, out) end
  return out
end

local function abbreviation_table()
  local rows = { "| Abbreviation | Meaning |", "|:--|:--|" }
  for _, k in ipairs(KEYS) do
    rows[#rows + 1] = string.format('| []{#%s}**%s** | %s |', slug(k), k:gsub("|", "\\|"), DICT[k].name)
  end
  return pandoc.read(table.concat(rows, "\n"), "markdown").blocks
end

local BODY
BODY = {
    traverse = "topdown",
    Div = function(d)
      if d.identifier == "abbreviation-list" then return abbreviation_table(), false end
      -- Quarto's hidden navigation/metadata envelopes (sidebar titles etc.)
      if d.identifier:match("^quarto%-") or d.classes:includes("hidden") then return d, false end
    end,
    Header = function(h) return h, false end,
    CodeBlock = function(c) return c, false end,
    RawBlock = function(r) return r, false end,
    Inlines = function(ils)
      if not enabled then return ils, false end
      buffer = ""
      return process_inlines(ils, false), false
    end,
  }

return {
  {
    Meta = function(m)
      load_dict()
      if m["abbr-expand"] ~= nil and pandoc.utils.stringify(m["abbr-expand"]) == "false" then enabled = false end
      if m["abbreviations-link"] then link_base = pandoc.utils.stringify(m["abbreviations-link"]) end
      if quarto and quarto.doc then
        quarto.doc.include_text("in-header", [[<style>
a.abbr-ref{color:inherit;text-decoration:none}
a.abbr-ref abbr{text-decoration:underline dotted;text-underline-offset:2px;cursor:help}
a.abbr-ref:hover abbr{text-decoration-style:solid}
</style>]])
      end
    end
  },
  {
    -- Walk the body only: Quarto keeps navigation (sidebar titles) in metadata,
    -- and those must never receive links or expansions.
    Pandoc = function(doc)
      doc.blocks = doc.blocks:walk(BODY)
      return doc
    end
  }
}
