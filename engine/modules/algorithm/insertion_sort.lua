--- Insertion sort algorithm
---@param t any
---@param comp fun(any, any) Comparison function
local function insertion_sort(t, comp)
    comp = comp or function(a, b) return a < b end
    for i = 2, #t do
        local key = t[i]
        local j = i - 1

        while j >= 1 and not comp(t[j], key) do
            t[j + 1] = t[j]
            j = j - 1
        end
        t[j + 1] = key
    end
end


return insertion_sort