local Maria = {
    coords      = vector4(-1393.81, -1064.09, 3.17, 266.09),
    model       = "a_f_y_vinewood_04",
    animDict    = "anim@amb@waving@male",
    animName    = "ground_wave",
    animFlag    = 1,
    message     = "Talk with Maria",
    key         = 38,
    showIcon    = 10.0,
    canInteract = 3.0,
    hintIcon    = "pin",
    hintColor   = "#feae00",
    blips = {
        sprite  = 119,
        color   = 50,
        text    = "Talk with Maria",
        scale   = 0.8,
        display = 2,
        alpha   = 255,
    },

    dialogue = {
        name     = "Maria",
        tag      = "Maria",
        startMsg = "Hello, are you ready to start your lumberjack shift?",

        elements = {
            {
                label  = "Yes, I'm ready to start",
                action = function(changeDialog, close)
                    changeDialog(
                        "Head across the street to clock in, then grab a vehicle on my right. " ..
                        "Next, go chop wood in the forest and come back here to process it. " ..
                        "Check the F6 menu to display GPS waypoints.",
                        {
                            {
                                label  = "Got it, thanks!",
                                action = function(_, close) close() end
                            }
                        }
                    )
                end
            },
            {
                label  = "What exactly do I have to do?",
                action = function(changeDialog, close)
                    changeDialog(
                        "Your job is to chop wood in the forest, come back here to process it, " ..
                        "then sell it at a sale point shown on your GPS.",
                        {
                            {
                                label  = "Ok, thanks for the info",
                                action = function(_, close) close() end
                            }
                        }
                    )
                end
            },
            {
                label  = "Where is the forest?",
                action = function(changeDialog, close)
                    SetNewWaypoint(-584.01, 5491.59)
                    changeDialog(
                        "The forest where you can chop wood is now marked on your GPS.",
                        {
                            {
                                label  = "Perfect, I'm on my way",
                                action = function(_, close) close() end
                            }
                        }
                    )
                end
            },
            {
                label  = "I'm not a lumberjack yet",
                action = function(changeDialog, close)
                    changeDialog(
                        "If you're not a lumberjack yet, head to the Job Center to get this job. " ..
                        "It will make you resign from your current job, so think carefully before switching!",
                        {
                            {
                                label  = "Show me the Job Center",
                                action = function(_, close)
                                    SetNewWaypoint(-265.0001, -963.6)
                                    close()
                                end
                            },
                            {
                                label  = "I'd rather keep my current job",
                                action = function(_, close) close() end
                            }
                        }
                    )
                end
            },
            {
                label  = "I'll come back later",
                action = function(_, close) close() end
            },
        }
    },
}

exports["avenida_interact"]:pedRegister(Maria)
