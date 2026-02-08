-- Small chat helper so core logic stays clean.
local _, NS = ...

local function color(hex, text)
  return "|cff" .. hex .. tostring(text) .. "|r"
end

NS.tag = color("00ff66", NS.name .. ":") .. " "

function NS.msg(hex, text)
  if hex then
    print(NS.tag .. color(hex, text))
  else
    print(NS.tag .. tostring(text))
  end
end
