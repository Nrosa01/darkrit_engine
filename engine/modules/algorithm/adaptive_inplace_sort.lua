-- Constants for optimization
local INSERTION_THRESHOLD = 32  -- Optimized for LuaJIT

--- Performs insertion sort on a subarray
---@param t table The array to sort
---@param compare function The comparison function
---@param left number The starting index of the subarray
---@param right number The ending index of the subarray
local function insertion_sort(t, compare, left, right)
    for i = left + 1, right do
        local current = t[i]
        local j = i - 1
        
        while j >= left and compare(current, t[j]) do
            t[j + 1] = t[j]
            j = j - 1
        end
        t[j + 1] = current
    end
end

--- Reverses a subarray
---@param t table The array to reverse
---@param start number The starting index of the subarray
---@param finish number The ending index of the subarray
local function reverse(t, start, finish)
    while start < finish do
        t[start], t[finish] = t[finish], t[start]
        start = start + 1
        finish = finish - 1
    end
end

--- Rotates a subarray
---@param t table The array to rotate
---@param start number The starting index of the subarray
---@param mid number The middle index of the subarray
---@param finish number The ending index of the subarray
local function rotate(t, start, mid, finish)
    reverse(t, start, mid)
    reverse(t, mid + 1, finish)
    reverse(t, start, finish)
end

--- Merges two sorted subarrays in place
---@param t table The array to merge
---@param compare function The comparison function
---@param start number The starting index of the first subarray
---@param mid number The ending index of the first subarray
---@param finish number The ending index of the second subarray
local function merge(t, compare, start, mid, finish)
    local i = start
    local j = mid + 1
    
    while i <= mid and j <= finish do
        if compare(t[j], t[i]) then
            rotate(t, i, mid, j)
            mid = mid + 1
            j = j + 1
        end
        i = i + 1
    end
end

--- Performs block merge sort on a subarray
---@param t table The array to sort
---@param compare function The comparison function
---@param start number The starting index of the subarray
---@param finish number The ending index of the subarray
local function block_merge_sort(t, compare, start, finish)
    if finish - start < INSERTION_THRESHOLD then
        insertion_sort(t, compare, start, finish)
        return
    end
    
    local mid = math.floor((start + finish) / 2)
    block_merge_sort(t, compare, start, mid)
    block_merge_sort(t, compare, mid + 1, finish)
    merge(t, compare, start, mid, finish)
end

--- Adaptive in-place sort function
---@param t table The array to sort
---@param compare function? The comparison function
local function adaptive_inplace_sort(t, compare)
    local n = #t
    compare = compare or function(a, b) return a < b end
    block_merge_sort(t, compare, 1, n)
end

return adaptive_inplace_sort