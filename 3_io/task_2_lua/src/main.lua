local function load_manifest(filename)
    local files = {}
    local line_number = 0
    for line in io.lines(filename) do
        line_number = line_number + 1
        line = line:gsub("\r$", "")
        local path, size, hash = line:match("^([^\t]+)\t([0-9]+)\t([0-9a-fA-F]+)$")
        if not path or #hash ~= 64 or path:match("^[/\\]") or path:match("^[A-Za-z]:") then
            error(string.format("%s:%d: invalid manifest record", filename, line_number), 0)
        end
        if files[path] then
            error(string.format("%s:%d: duplicate path %s", filename, line_number, path), 0)
        end
        -- Compare decimal sizes exactly, even above the Lua integer range.
        size = size:gsub("^0+", "")
        files[path] = {size = size == "" and "0" or size, hash = hash:lower()}
    end
    return files
end

local function compare(old, new)
    local paths = {}
    for path in pairs(old) do paths[#paths + 1] = path end
    for path in pairs(new) do
        if not old[path] then paths[#paths + 1] = path end
    end
    table.sort(paths)

    local groups = {Added = {}, Removed = {}, Modified = {}, Unchanged = {}}
    for _, path in ipairs(paths) do
        local before, after = old[path], new[path]
        local status
        if not before then
            status = "Added"
        elseif not after then
            status = "Removed"
        elseif before.size ~= after.size or before.hash ~= after.hash then
            status = "Modified"
        else
            status = "Unchanged"
        end
        local group = groups[status]
        group[#group + 1] = path
    end
    return groups
end

local function main()
    if #arg ~= 2 then error("Usage: lua src/main.lua OLD.tsv NEW.tsv", 0) end
    local groups = compare(load_manifest(arg[1]), load_manifest(arg[2]))
    for _, status in ipairs({"Added", "Removed", "Modified", "Unchanged"}) do
        local paths = groups[status]
        print(string.format("%s (%d):", status, #paths))
        for _, path in ipairs(paths) do print("  " .. path) end
    end
end

local ok, message = pcall(main)
if not ok then
    io.stderr:write("Error: ", tostring(message), "\n")
    os.exit(1)
end
