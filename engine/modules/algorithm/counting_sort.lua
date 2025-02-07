local function counting_sort(arr, key_fn)
    if #arr == 0 then
        return arr
    end

    -- Determinar tipo de elementos
    local first = arr[1]
    local is_table = type(first) == "table"
    
    -- Validación de parámetros
    if is_table and not key_fn then
        error("Se requiere función key_fn para tablas")
    end

    -- Función de obtención de valor
    local get_value = function(element)
        return is_table and key_fn(element) or element
    end

    -- Encontrar min y max usando un enfoque eficiente para grandes rangos
    local min_val, max_val = get_value(first), get_value(first)
    for _, element in ipairs(arr) do
        local val = get_value(element)
        if val < min_val then min_val = val end
        if val > max_val then max_val = val end
    end

    -- Crear contador sparse para grandes rangos
    local count = {}
    for _, element in ipairs(arr) do
        local key = get_value(element)
        count[key] = (count[key] or 0) + 1
    end

    -- Calcular suma acumulativa optimizada
    local sorted_keys = {}
    for k in pairs(count) do
        table.insert(sorted_keys, k)
    end
    table.sort(sorted_keys)
    
    local acc = 0
    for _, key in ipairs(sorted_keys) do
        acc = acc + count[key]
        count[key] = acc
    end

    -- Ordenación in-place para tablas con grandes rangos
    if is_table then
        -- Asignar posiciones finales
        for i = #arr, 1, -1 do
            local element = arr[i]
            local key = get_value(element)
            
            while true do
                local pos = count[key]
                if pos == i then
                    count[key] = pos - 1
                    break
                end
                
                -- Realizar swap y actualizar conteo
                count[key] = pos - 1
                arr[pos], arr[i] = arr[i], arr[pos]
                
                -- Actualizar clave para el nuevo elemento
                key = get_value(arr[i])
            end
        end
    else
        -- Para números, versión optimizada
        local output = {}
        for i = #arr, 1, -1 do
            local key = arr[i]
            local pos = count[key]
            output[pos] = key
            count[key] = pos - 1
        end
        return output
    end

    return arr
end

return counting_sort