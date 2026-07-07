-- monoref.lua
-- Lua backend for the monoref package.
--
-- Copyright (C) 2026 Srikanth Mohankumar <srikanthmohankumar@gmail.com>
-- This work may be distributed and/or modified under the conditions of
-- the LaTeX Project Public License, version 1.3c or later.
--   http://www.latex-project.org/lppl.txt

monoref = monoref or {}

monoref.labels    = {}   -- name -> {ref=, page=}
monoref.slots     = {}   -- id   -> {name=, font=, kind=}   kind: ref | page | total
monoref.marks     = {}   -- id   -> {kind=, key=}           kind: label | toc
monoref.toc       = {}   -- ordered list of {level=, num=, title=, page=}
monoref.held      = {}   -- body pages (arabic)
monoref.toc_pages = {}   -- front-matter pages (roman)
monoref.queue     = {}   -- final ship order
monoref.target    = "body"
monoref.sid, monoref.mid, monoref.total = 0, 0, 0

monoref.slotattr = luatexbase.new_attribute("monorefslot")
monoref.markattr = luatexbase.new_attribute("monorefmark")

local HLIST = node.id("hlist")
local VLIST = node.id("vlist")
local GLYPH = node.id("glyph")
local GLUE  = node.id("glue")

--------------------------------------------------------------------------
-- Registration (all print/sprint straight back into the TeX stream)
--------------------------------------------------------------------------
function monoref.known(name)
  tex.print(monoref.labels[name] and 1 or 0)
end

function monoref.newslot(name, kind)
  monoref.sid = monoref.sid + 1
  monoref.slots[monoref.sid] = { name = name, font = font.current(), kind = kind }
  tex.print(monoref.sid)
end

local function newmark(kind, key)
  monoref.mid = monoref.mid + 1
  monoref.marks[monoref.mid] = { kind = kind, key = key }
  return monoref.mid
end

function monoref.label_begin(name, ref)
  monoref.labels[name] = { ref = ref, page = 0 }
  tex.print(newmark("label", name))
end

function monoref.ref_value(name)
  local L = monoref.labels[name]
  tex.sprint(L and L.ref or "??")
end

function monoref.toc_begin(level, num, title)
  monoref.toc[#monoref.toc + 1] = { level = level, num = num, title = title, page = 0 }
  tex.print(newmark("toc", #monoref.toc))
end

function monoref.toc_count()  tex.print(#monoref.toc)          end
function monoref.toc_level(i) tex.print(monoref.toc[i].level)  end
function monoref.toc_num(i)   tex.sprint(monoref.toc[i].num)   end
function monoref.toc_title(i) tex.sprint(monoref.toc[i].title) end
function monoref.toc_page(i)  tex.print(monoref.toc[i].page)   end

--------------------------------------------------------------------------
-- Marker scan: stamp every label / TOC entry with the TRUE page it is on
--------------------------------------------------------------------------
local function scan(head, pg)
  local n = head
  while n do
    local m = node.get_attribute(n, monoref.markattr)
    if m and monoref.marks[m] then
      local r = monoref.marks[m]
      if r.kind == "label" and monoref.labels[r.key] then
        monoref.labels[r.key].page = pg
      elseif r.kind == "toc" and monoref.toc[r.key] then
        monoref.toc[r.key].page = pg
      end
    end
    local id = n.id
    if id == HLIST or id == VLIST then scan(n.head, pg) end
    n = n.next
  end
end

function monoref.hold(reg, pg)
  local b = tex.getbox(reg)
  if not b then return end
  local c = node.copy(b)
  scan(c.head, pg)
  local dest = (monoref.target == "toc") and monoref.toc_pages or monoref.held
  dest[#dest + 1] = c
end

--------------------------------------------------------------------------
-- Slot filling at flush (fixed width kept -> never reflows)
--------------------------------------------------------------------------
local function glyphs_of(s, fid)
  local fnt = font.getfont(fid)
  local first, last
  for i = 1, #s do
    local code = s:byte(i)
    local g = node.new(GLYPH)
    g.font, g.char, g.subtype = fid, code, 0
    if fnt and fnt.characters and fnt.characters[code] then
      local ci = fnt.characters[code]
      g.width, g.height, g.depth = ci.width or 0, ci.height or 0, ci.depth or 0
    end
    if first then last.next = g; g.prev = last; last = g
    else first, last = g, g end
  end
  return first, last
end

local function value_of(rec)
  if rec.kind == "total" then return tostring(monoref.total) end
  local L = monoref.labels[rec.name]
  if not L then return "??" end
  if rec.kind == "page" then
    return (L.page and L.page > 0) and tostring(L.page) or "??"
  end
  return L.ref
end

-- Fill one placeholder hbox to the value's NATURAL width (the enclosing
-- line is re-justified afterwards so the reserved slack disappears).
local function fill_slot(hbox, id)
  local val = value_of(monoref.slots[id])
  if hbox.head then node.flush_list(hbox.head); hbox.head = nil end
  local gf = glyphs_of(val, monoref.slots[id].font)
  local packed = node.hpack(gf or node.new(GLUE))
  hbox.head       = packed.head
  hbox.width      = packed.width
  hbox.height     = packed.height
  hbox.depth      = packed.depth
  hbox.glue_set   = 0
  hbox.glue_sign  = 0
  hbox.glue_order = 0
  packed.head = nil
  node.free(packed)
end

-- Re-pack a line to its original width so its interword glue absorbs the
-- space freed by shrinking a slot (keeps the line justified, no gap).
local function rejustify(hbox)
  local packed = node.hpack(hbox.head, hbox.width, "exactly")
  hbox.head       = packed.head
  hbox.glue_set   = packed.glue_set
  hbox.glue_sign  = packed.glue_sign
  hbox.glue_order = packed.glue_order
  hbox.height     = packed.height
  hbox.depth      = packed.depth
  packed.head = nil
  node.free(packed)
end

-- Patch every slot in a box; re-justify each line that contained one.
local function patch_box(box)
  local direct = false
  local n = box.head
  while n do
    local id = n.id
    if id == HLIST or id == VLIST then
      local a = node.get_attribute(n, monoref.slotattr)
      if a and monoref.slots[a] then
        fill_slot(n, a)
        direct = true
      else
        patch_box(n)
      end
    end
    n = n.next
  end
  if direct and box.id == HLIST then rejustify(box) end
end

--------------------------------------------------------------------------
-- Finalisation and shipping
--------------------------------------------------------------------------
function monoref.finalize()
  monoref.total = #monoref.held
  for i = 1, #monoref.toc_pages do patch_box(monoref.toc_pages[i]) end
  for i = 1, #monoref.held      do patch_box(monoref.held[i])      end
  monoref.queue = {}
  for i = 1, #monoref.toc_pages do monoref.queue[#monoref.queue + 1] = monoref.toc_pages[i] end
  for i = 1, #monoref.held      do monoref.queue[#monoref.queue + 1] = monoref.held[i]      end
end

function monoref.qcount() tex.print(#monoref.queue) end
function monoref.qpop()   tex.setbox(monoref.shipreg, table.remove(monoref.queue, 1)) end

return monoref
