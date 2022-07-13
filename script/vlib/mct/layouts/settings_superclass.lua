--- TODO unused superclass for all settings-type layouts
local Super = get_mct()._MCT_PAGE

---@class MCT.Page.SettingsSuperclass : MCT.Page
local defaults = {
    ---@type MCT.Section[]
    assigned_sections = {},

    num_columns = 3,
}

---@class MCT.Page.SettingsSuperclass : MCT.Page
local SettingsSuperclass = Super:extend("SettingsSuperclass", defaults)
get_mct():add_new_page_type("SettingsSuperclass", SettingsSuperclass)

function SettingsSuperclass:new(key, mod, num_columns)
    local o = self:__new()

    ---@cast o MCT.Page.SettingsSuperclass
    o:init(key, mod, num_columns)

    return o
end

function SettingsSuperclass:init(key, mod, num_columns)
    Super.init(self, key, mod)

    if not is_number(num_columns) then num_columns = 3 end
    num_columns = math.clamp(math.floor(num_columns), 1, 3)
    self.num_columns = num_columns
end

--- Attach a settings section to this page. They will be displayed in order that they are added.
---@param section MCT.Section
function SettingsSuperclass:assign_section_to_page(section)
    self.assigned_sections[#self.assigned_sections+1] = section
end

--[[ TODO instate the ui calls in relevant objects
    Grab the assigned sections (if none are assigned, grab all?)
    Loop through them, call section:populate(column)
    In section:populate, call option:populate(), etc etc etc
]]

---@param box UIC
function SettingsSuperclass:populate(box)
    local sections = self.assigned_sections

    --- TODO properly order them!
    if #sections == 0 then
        local sorted = self.mod_obj:sort_sections()
        for _,key in ipairs(sorted) do
            sections[#sections+1] = self.mod_obj:get_section_by_key(key)
        end
    end

    VLib.Log("Populating a Settings page for mod %s, num sections is %d", self.mod_obj:get_key(), #sections)

    local mod = self.mod_obj

    -- set the positions for all options in the mod
    mod:set_positions_for_options()

    local panel = get_mct().ui.mod_settings_panel

    local settings_canvas = core:get_or_create_component("settings_canvas", 'ui/campaign ui/script_dummy', box)
    settings_canvas:Resize(panel:Width() * 0.95, panel:Height())
    settings_canvas:SetDockingPoint(1)

    settings_canvas:SetCanResizeWidth(false)

    for i = 1, self.num_columns do
        local column = core:get_or_create_component("settings_column_"..i, "ui/mct/layouts/column", settings_canvas)
        column:Resize(settings_canvas:Width() / self.num_columns, settings_canvas:Height())

        --- 2 if num_columns = 1
        --- 1 and 3 if num_columns = 2
        --- 1 | 2 | 3 if num_columns = 3

        local docking_point = 2
        if self.num_columns == 3 then
            docking_point = i
        elseif self.num_columns == 2 then
            docking_point = i == 1 and 1 or 3
        elseif self.num_columns == 1 then
            docking_point = 2
        end

        VLib.Log("Docking point for column %d is %d", i, docking_point)

        column:SetDockingPoint(
        docking_point
        )
    end

    core:remove_listener("MCT_SectionHeaderPressed")

    --- TODO cleanly split the sections between the columns
    --- TODO modder ability to set sections to columns (?)
    
    --- number of sections per column
    local per_column = math.ceil(#sections / self.num_columns)

    for i, section_obj in ipairs(sections) do
        local section_key = section_obj:get_key()

        local column_num = 1

        if self.num_columns == 3 then
            column_num = i <= per_column and 1 or
            i > per_column and i <= per_column *2 and 2 or
            i >= per_column *2 and 3
        elseif self.num_columns == 2 then
            column_num = i > per_column and 2 or 1
        elseif self.num_columns == 1 then
            column_num = 1
        end

        VLib.Log("Assigning section %s to column %d", section_key, column_num)

        local column = find_uicomponent(settings_canvas, "settings_column_"..column_num)

        if not section_obj or section_obj._options == nil or next(section_obj._options) == nil then
            -- skip
        else
            -- make sure the dummy rows table is clear before doing anything
            section_obj._dummy_rows = {}

            -- first, create the section header
            local section_header = core:get_or_create_component("mct_section_"..section_key, "ui/vandy_lib/row_header", column)
            --local open = true

            section_obj._header = section_header

            --- TODO set this in a Section method, mct_section:set_is_collapsible() or whatever
            core:add_listener(
                "MCT_SectionHeaderPressed",
                "ComponentLClickUp",
                function(context)
                    return context.string == "mct_section_"..section_key
                end,
                function(context)
                    local visible = section_obj:is_visible()
                    section_obj:set_visibility(not visible)
                end,
                true
            )

            -- TODO set text & width and shit
            section_header:SetCanResizeWidth(true)
            -- section_header:SetCanResizeHeight(false)
            section_header:Resize(column:Width() * 0.95, section_header:Height())
            section_header:SetDockingPoint(2)
            -- section_header:SetCanResizeWidth(false)

            -- section_header:SetDockOffset(mod_settings_box:Width() * 0.005, 0)
            
            -- local child_count = find_uicomponent(section_header, "child_count")
            -- _SetVisible(child_count, false)

            local text = section_obj:get_localised_text()
            local tt_text = section_obj:get_tooltip_text()

            local dy_title = find_uicomponent(section_header, "dy_title")
            dy_title:SetStateText(text)

            if tt_text ~= "" then
                _SetTooltipText(section_header, tt_text, true)
            end

            -- lastly, create all the rows and options within
            --local num_remaining_options = 0
            -- local valid = true

            -- this is the table with the positions to the options
            -- ie. options_table["1,1"] = "option 1 key"
            -- local options_table, num_remaining_options = section_obj:get_ordered_options()

            for i,option_key in ipairs(section_obj._true_ordered_options) do
                local option_obj = mod:get_option_by_key(option_key)
                get_mct().ui:new_option_row_at_pos(option_obj, column)
            end

            section_obj:uic_visibility_change(true)
        end

        -- column:Layout()
    end

    --- TODO wish there were a better way to do this
    core:get_tm():real_callback(function()
        local max_h = settings_canvas:Height()
        for i = 1, self.num_columns do
            local column = find_uicomponent(settings_canvas, "settings_column_" .. i)
            if column:Height() > max_h then max_h = column:Height() end
        end
        -- local _,max_h = settings_canvas:Bounds()
        settings_canvas:Resize(panel:Width() * 0.95, max_h)
    end, 10)

    -- settings_canvas:Resize(panel:Width() * 0.95, panel:Height() * 2)
end