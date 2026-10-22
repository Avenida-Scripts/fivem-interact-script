local ATM_PROPS = { -870868698, "prop_atm_01", "prop_atm_02", "prop_atm_03", -960287005, -1126237515, "prop_fleeca_atm", -1364697528  }

for _, prop in ipairs(ATM_PROPS) do
    exports["avenida_interact"]:entityRegisterByHash(prop, {
        canInteract = 1.2,
        hintIcon    = "bank",
        offsetZ     = 1.0,
        hintColor   = "#feae00",
        choices = {
            {
                bind       = "E",
                message    = "Use the ATM",         
                onInteract = function()
                    -- Hook your own banking resource here.
                    -- TriggerEvent('mybank:openATM')
                end,
            },
            {
                bind       = "G",
                message    = "Rob the ATM",
                hintColor  = "red",
                -- condition  = function()
                -- end,
                onInteract = function(entity)
                end,
            },
        },
    })
end