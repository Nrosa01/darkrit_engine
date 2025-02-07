---@diagnostic disable-next-line
local ru = Darkrit._internal.require_utils ---@module "require_utils"
local adaptive_inplace_sort = ru.require_module('algorithm.adaptive_inplace_sort') ---@module "adaptive_inplace_sort"
local turbo_adaptative_sort = ru.require_module('algorithm.turbo_adaptative_sort') ---@module "turbo_adaptative_sort"
local insertion_sort = ru.require_module('algorithm.insertion_sort') ---@module "insertion_sort"
local counting_sort = ru.require_module('algorithm.counting_sort') ---@module "counting_sort"

---@class Darkrit.Algorithms
local algorithms =
{
    adaptive_inplace_sort = adaptive_inplace_sort,
    turbo_adaptative_sort = turbo_adaptative_sort,
    insertion_sort = insertion_sort,
    counting_sort = counting_sort
}

return algorithms
