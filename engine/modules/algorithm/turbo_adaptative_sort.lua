local INSERTION_THRESHOLD = 64 -- I would leave these two parameters like this
-- local MERGE_THRESHOLD = 512

--- Optimized insertion sort for small segments
---@param t any[] Table to sort
---@param compare fun(a: any, b: any): boolean Comparison function
---@param left integer Initial index of the segment
---@param right integer Final index of the segment
local function insertion_sort_opt(t, compare, left, right)
    for i = left + 1, right do
        local current = t[i]
        local j = i - 1

        while j >= left do
            if not compare(current, t[j]) then break end
            t[j + 1] = t[j]
            j = j - 1
        end
        t[j + 1] = current
    end
end

--- In-place merge with efficient rotations
---@param t any[] Table to sort
---@param compare fun(a: any, b: any): boolean Comparison function
---@param start integer Initial index
---@param mid integer Midpoint of the segment
---@param finish integer Final index
local function merge_in_place(t, compare, start, mid, finish)
    local i = start
    local j = mid + 1

    while i <= mid and j <= finish do
        if compare(t[j], t[i]) then
            local temp = t[j]
            for k = j, i + 1, -1 do
                t[k] = t[k - 1]
            end
            t[i] = temp
            mid = mid + 1
            j = j + 1
        end
        i = i + 1
    end
end

--- Hybrid merge sort with adaptive strategies
---@param t any[] Array to sort
---@param compare fun(a: any, b: any): boolean Comparator
---@param start integer Start index
---@param finish integer End index
local function adaptive_merge_sort(t, compare, start, finish)
    local size = finish - start + 1

    if size <= INSERTION_THRESHOLD then
        insertion_sort_opt(t, compare, start, finish)
        return
    end

    local mid = start + math.floor((finish - start) / 2)

    
    adaptive_merge_sort(t, compare, start, mid)
    adaptive_merge_sort(t, compare, mid + 1, finish)

    merge_in_place(t, compare, start, mid, finish)
end

local function turbo_adaptive_sort(t, compare)
    compare = compare or function(a, b) return a < b end
    
    local n = #t
    if n <= 1 then return end

    adaptive_merge_sort(t, compare, 1, n)
end

return turbo_adaptive_sort
