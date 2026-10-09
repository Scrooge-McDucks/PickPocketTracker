-------------------------------------------------------------------------------
-- test_chart.lua — bar chart renderer: pooled widgets, reuse across redraws,
-- and tooltips that follow the data
-------------------------------------------------------------------------------
local H = dofile(TESTS_DIR .. "/wow_stub.lua")
local MODULES = { "config.lua", "utils.lua", "chart.lua" }

local NS = H.newEnv(MODULES)
local Chart = NS.Chart

local function bars(n)
  local data = {}
  for i = 1, n do data[i] = { name = "Char" .. i, value = i * 100 } end
  return data
end

local function counts(holder)
  return select("#", holder:GetRegions()), select("#", holder:GetChildren())
end

local function shownBars(holder)
  local n = 0
  for _, b in ipairs(holder.pptBars or {}) do
    if b.label:IsShown() then n = n + 1 end
  end
  return n
end

H.section("redrawing the same data creates no new widgets")
local holder = CreateFrame("Frame")
Chart:Render(holder, { data = bars(3), maxBars = 10 })
local r1, c1 = counts(holder)
for _ = 1, 100 do Chart:Render(holder, { data = bars(3), maxBars = 10 }) end
local r2, c2 = counts(holder)
H.eq("regions flat after 100 redraws", r2, r1)
H.eq("child frames flat after 100 redraws", c2, c1)
H.eq("one hit frame per bar", c1, 3)

H.section("fewer bars hides the extras, more bars reuses then grows the pool")
Chart:Render(holder, { data = bars(1), maxBars = 10 })
H.eq("one bar shown", shownBars(holder), 1)
H.eq("pool kept", #holder.pptBars, 3)
Chart:Render(holder, { data = bars(5), maxBars = 10 })
H.eq("five bars shown", shownBars(holder), 5)
H.eq("pool grew to five", #holder.pptBars, 5)
local r3, c3 = counts(holder)
Chart:Render(holder, { data = bars(2), maxBars = 10 })
Chart:Render(holder, { data = bars(5), maxBars = 10 })
local r4, c4 = counts(holder)
H.eq("shrink then regrow allocates nothing", r4 + c4, r3 + c3)

H.section("grouping past maxBars draws the Other bar from the pool")
Chart:Render(holder, { data = bars(8), maxBars = 3 })
H.eq("3 bars + Other", shownBars(holder), 4)
H.check("Other label", (holder.pptBars[4].label:GetText() or ""):find("Other Characters (5)", 1, true) ~= nil)

H.section("empty data shows one reused no-data line and hides every bar")
local r5 = counts(holder)
Chart:Render(holder, { data = {}, noDataText = "Nothing yet" })
Chart:Render(holder, { data = {}, noDataText = "Nothing yet" })
H.eq("no bars shown", shownBars(holder), 0)
H.check("no-data text shown", holder.pptNoData:IsShown())
H.eq("no-data text set", holder.pptNoData:GetText(), "Nothing yet")
H.eq("empty renders allocate nothing", counts(holder), r5)
Chart:Render(holder, { data = bars(2), maxBars = 10 })
H.check("no-data text hidden again", not holder.pptNoData:IsShown())

H.section("tooltips show the current entry after a redraw")
local seen
local function builder(entry) seen = entry.name end
local h2 = CreateFrame("Frame")
Chart:Render(h2, { data = { { name = "Old", value = 5 } }, tooltipBuilder = builder })
Chart:Render(h2, { data = { { name = "New", value = 5 } }, tooltipBuilder = builder })
h2.pptBars[1].hit:Fire("OnEnter")
H.eq("hover reports the latest data", seen, "New")
H.eq("value text updated", h2.pptBars[1].value:GetText(), "5")

H.report()
