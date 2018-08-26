local stage = {}

stage.messages = {
   ["321"] = "accessing uninitialized variable {name!}",
   ["341"] = "mutating uninitialized variable {name!}"
}

local function detect_uninit_access_in_line(chstate, line)
   for _, item in ipairs(line.items) do
      for _, action_key in ipairs({"accesses", "mutations"}) do
         local code = action_key == "accesses" and "321" or "341"
         local item_var_map = item[action_key]

         if item_var_map then
            for var, accessing_nodes in pairs(item_var_map) do
               -- If there are no values at all reaching this access, not even the empty one,
               -- this item (or a closure containing it) is not reachable from variable definition.
               -- It will be reported as unreachable code, no need to report uninitalized accesses in it.
               if item.used_values[var] then
                  -- If this variable is has only one, empty value then it's already reported as never set,
                  -- no need to report each access.
                  if not (#var.values == 1 and var.values[1].empty) then
                     local all_possible_values_empty = true

                     for _, possible_value in ipairs(item.used_values[var]) do
                        if not possible_value.empty then
                           all_possible_values_empty = false
                           break
                        end
                     end

                     if all_possible_values_empty then
                        for _, accessing_node in ipairs(accessing_nodes) do
                           local name = accessing_node[1]

                           chstate:warn_token(code, name, accessing_node.location, {
                              name = name
                           })
                        end
                     end
                  end
               end
            end
         end
      end
   end
end

-- Warns about accesses and mutations that don't resolve to any values except initial empty one.
function stage.run(chstate)
   for _, line in ipairs(chstate.lines) do
      detect_uninit_access_in_line(chstate, line)
   end
end

return stage