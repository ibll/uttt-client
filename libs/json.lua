--[[pod_format="raw",created="2025-07-07 16:25:32",modified="2025-07-18 22:30:11",revision=57,xstickers={}]]
json = {}

local function serialize_value(v, prev_visited)
    local v_type = type(v)
    
    if v_type == "string" then
        return '"' .. v:gsub('"', '\\"') .. '"'
    elseif v_type == "number" then
        return tostring(v)
    elseif v_type == "boolean" then
        return tostring(v)
    elseif v_type == "table" then
        return json.fromtable(v, prev_visited)
    elseif v == nil then
        return "null"
    else
        return '"' .. tostring(v) .. '"'
    end
end

json.fromtable = function(t, prev_visited)
    -- Check if table is array-like
    local is_array = true
    local max_index = 0
    local count = 0
    
    if prev_visited then
	    for k, v in pairs(prev_visited) do
	    	if v == t then return "\"VISITEDTABLE\"" end
	    end
	 else
	 	prev_visited = {}
    end
    table.insert(prev_visited, t) 
   
    for k, v in pairs(t) do
        count = count + 1
        if type(k) ~= "number" or k <= 0 or k % 1 ~= 0 then
            is_array = false
            break
        end
        max_index = math.max(max_index, k)
    end
    
    if is_array and count == max_index then
        -- Array format
        local result = "["
        for i = 1, max_index do
            if i > 1 then result = result .. "," end
            result = result .. serialize_value(t[i], prev_visited)
        end
        return result .. "]"
    else
        -- Object format
        local result = "{"
        local first = true
        for k, v in pairs(t) do
            if not first then result = result .. "," end
            first = false
            result = result .. '"' .. tostring(k) .. '":' .. serialize_value(v, prev_visited)
        end
        return result .. "}"
    end
end

json.totable = function(json_str, explicit_null)
    local function skip_whitespace(str, pos)
        while pos <= #str and str:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
        return pos
    end
    
    local function parse_string(str, pos)
        if str:sub(pos, pos) ~= '"' then
            error("Expected string at position " .. pos)
        end
        pos = pos + 1
        local result = ""
        while pos <= #str do
            local char = str:sub(pos, pos)
            if char == '"' then
                return result, pos + 1
            elseif char == '\\' then
                pos = pos + 1
                if pos > #str then
                    error("Unexpected end of string")
                end
                local escaped = str:sub(pos, pos)
                if escaped == 'n' then
                    result = result .. '\n'
                elseif escaped == 't' then
                    result = result .. '\t'
                elseif escaped == 'r' then
                    result = result .. '\r'
                elseif escaped == 'b' then
                    result = result .. '\b'
                elseif escaped == 'f' then
                    result = result .. '\f'
                elseif escaped == '"' then
                    result = result .. '"'
                elseif escaped == '\\' then
                    result = result .. '\\'
                elseif escaped == '/' then
                    result = result .. '/'
                elseif escaped == 'u' then
                    -- Unicode escape (simplified)
                    local hex = str:sub(pos + 1, pos + 4)
                    if #hex == 4 and hex:match("^%x%x%x%x$") then
                        result = result .. string.char(tonumber(hex, 16))
                        pos = pos + 4
                    else
                        error("Invalid unicode escape")
                    end
                else
                    result = result .. escaped
                end
            else
                result = result .. char
            end
            pos = pos + 1
        end
        error("Unterminated string")
    end
    
    local function parse_number(str, pos)
        local start_pos = pos
        local has_decimal = false
        local has_exp = false
        
        -- Handle negative sign
        if str:sub(pos, pos) == '-' then
            pos = pos + 1
        end
        
        -- Parse integer part
        if str:sub(pos, pos) == '0' then
            pos = pos + 1
        elseif str:sub(pos, pos):match("[1-9]") then
            while pos <= #str and str:sub(pos, pos):match("%d") do
                pos = pos + 1
            end
        else
            error("Invalid number at position " .. start_pos)
        end
        
        -- Parse decimal part
        if pos <= #str and str:sub(pos, pos) == '.' then
            has_decimal = true
            pos = pos + 1
            if not (pos <= #str and str:sub(pos, pos):match("%d")) then
                error("Invalid number at position " .. start_pos)
            end
            while pos <= #str and str:sub(pos, pos):match("%d") do
                pos = pos + 1
            end
        end
        
        -- Parse exponent part
        if pos <= #str and str:sub(pos, pos):match("[eE]") then
            has_exp = true
            pos = pos + 1
            if pos <= #str and str:sub(pos, pos):match("[+-]") then
                pos = pos + 1
            end
            if not (pos <= #str and str:sub(pos, pos):match("%d")) then
                error("Invalid number at position " .. start_pos)
            end
            while pos <= #str and str:sub(pos, pos):match("%d") do
                pos = pos + 1
            end
        end
        
        local num_str = str:sub(start_pos, pos - 1)
        return tonumber(num_str), pos
    end
    
    local function parse_value(str, pos)
        pos = skip_whitespace(str, pos)
        if pos > #str then
            error("Unexpected end of input")
        end
        
        local char = str:sub(pos, pos)
        
        if char == '"' then
            return parse_string(str, pos)
        elseif char:match("[%-0-9]") then
            return parse_number(str, pos)
        elseif str:sub(pos, pos + 3) == "true" then
            return true, pos + 4
        elseif str:sub(pos, pos + 4) == "false" then
            return false, pos + 5
        elseif str:sub(pos, pos + 3) == "null" then
            return explicit_null and "null" or nil, pos + 4
        elseif char == '{' then
            return parse_object(str, pos)
        elseif char == '[' then
            return parse_array(str, pos)
        else
            error("Unexpected character '" .. char .. "' at position " .. pos)
        end
    end
    
    function parse_object(str, pos)
        local obj = {}
        pos = pos + 1 -- skip '{'
        pos = skip_whitespace(str, pos)
        
        if pos <= #str and str:sub(pos, pos) == '}' then
            return obj, pos + 1
        end
        
        while true do
            pos = skip_whitespace(str, pos)
            
            -- Parse key
            local key
            key, pos = parse_string(str, pos)
            pos = skip_whitespace(str, pos)
            
            -- Expect ':'
            if pos > #str or str:sub(pos, pos) ~= ':' then
                error("Expected ':' at position " .. pos)
            end
            pos = pos + 1
            
            -- Parse value
            local value
            value, pos = parse_value(str, pos)
            obj[key] = value
            
            pos = skip_whitespace(str, pos)
            
            if pos > #str then
                error("Unexpected end of input")
            end
            
            local char = str:sub(pos, pos)
            if char == '}' then
                return obj, pos + 1
            elseif char == ',' then
                pos = pos + 1
            else
                error("Expected ',' or '}' at position " .. pos)
            end
        end
    end
    
    function parse_array(str, pos)
        local arr = {}
        pos = pos + 1 -- skip '['
        pos = skip_whitespace(str, pos)
        
        if pos <= #str and str:sub(pos, pos) == ']' then
            return arr, pos + 1
        end
        
        while true do
            local value
            value, pos = parse_value(str, pos)
            table.insert(arr, value)
            
            pos = skip_whitespace(str, pos)
            
            if pos > #str then
                error("Unexpected end of input")
            end
            
            local char = str:sub(pos, pos)
            if char == ']' then
                return arr, pos + 1
            elseif char == ',' then
                pos = pos + 1
                pos = skip_whitespace(str, pos)
            else
                error("Expected ',' or ']' at position " .. pos)
            end
        end
    end
    
    local result, pos = parse_value(json_str, 1)
    pos = skip_whitespace(json_str, pos)
    if pos <= #json_str then
        error("Unexpected characters after JSON at position " .. pos)
    end
    return result
end
