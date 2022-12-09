-- @file treefarm_install.lua

print("Tree Farm Install")
print(" ")

if fs.exists("bturtle.json") then
  print("  -- Deleting bturtle.json")
  shell.run("delete bturtle.json")
end
if fs.exists("bturtle") then
  print("  -- Deleting bturtle")
  shell.run("delete bturtle")
end
if fs.exists("startup") then
  print("  -- Deleting startup")
  shell.run("delete startup")
end

print("Instaling...")

shell.run("label set treefarm-" .. os.getComputerID())
shell.run("rom/programs/set modt.enabled false")
shell.run("rom/programs/http/wget https://raw.githubusercontent.com/renanmfd/treefarm/main/bturtle.lua bturtle")
shell.run("rom/programs/http/wget https://raw.githubusercontent.com/renanmfd/treefarm/main/treefarm.lua startup")

print("Done!")

-- wget https://raw.githubusercontent.com/renanmfd/treefarm/main/treefarm_install.lua install
