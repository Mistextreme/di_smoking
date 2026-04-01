Config = {}

Config.Notify = "qb"   -- "qb" or "ox"
Config.Inventory = "qb" -- "qb" or "ox"
Config.Interaction = "qb"   -- "qb" or "ox" or "drawtext"
Config.Progressbar = "qb" -- "qb" or "ox"

Config.StressEvent = "hud:client:UpdateStress" -- Trigger client stress update (modify if using custom HUD event)


-- SMOKING SHOP CONFIGURATION
Config.SmokingShop = {
    enabled = true,
    
    locations = {
        { coords =
               {
                vector4(376.34, -833.27, 28.29, 182.17), 
                vector4(-1174.26, -1573.11, 3.37, 120.01)
                }, 

            label = "The Smoking' Spot", 
            blip = {
                sprite = 469,  
                color = 5,    
                scale = 0.8,
                display = 4,
            },
            radius = 2.0,
            
            ped = {
                enabled = true,
                model = "s_m_m_cntrybar_01",  -- PED model
                scenario = "WORLD_HUMAN_AA_SMOKE",  -- Animation (optional)
            }
        },
    },

    pricing = {
        
        ["lighter"]         = 100,
        ["silver_ember"]    = 200,
        ["royal_drift"]     = 250,
        ["black_velvet"]    = 300,
    },
    
    -- Exchange smoking coupons for boxes
    redemption = {
        ["ember_coupon"] = { item = "silver_ember", amount = 1 },
        ["royal_coupon"] = { item = "royal_drift", amount = 1 },
        ["velvet_coupon"] = { item = "black_velvet", amount = 1 },
    },
    
}

Config.OpenTime = 2500 -- time in ms to open a box, modify according to your needs and animation length

Config.ProgressTexts = {
    opening = "Opening {label}..."
}

Config.PropAttach = {
    bone = 57005,
    pos = { x = 0.12, y = 0.03, z = 0.0 },
    rot = { x = 40.0, y = 5.0, z = 180.0 }
}

Config.Boxes = {
     -- animationOptions = animation that will play when the item is consumed
        -- time  = total progress time to consume 
        -- stressRemove = value of stress to remove when the item is consumed
        -- requiredItem = item required to use giveItem = "silver_cigs",
        -- prop = Cigaratte prop
        -- attach = configuration of the cigaratte prop attachment

    ["silver_ember"] = {
        label = "Silver Ember Cigarette",
        cigAmount = 10,  -- amount of cigarattes to be received after opening a box
        giveItem = "silver_cigs",  -- inventory item of cigarattes
        openAnimation = {
                type = "scenario",
                name = "PROP_HUMAN_PARKING_METER"
            },
        boxProp = "prop_cigar_pack_01", -- prop for the particular cigaratte box
        -- item received as a bonus on opening a box with chance and amount
        bonus = {
            { item = "ember_coupon", chance = 50, amount = 1 },
        },
        
        customAttach = false, -- custom prop attachment for the box i.e Config.PropAttach.
        consume = true, -- enable/disable smoking or making the item usable from here
        
        consumeSettings = {
            animationOptions = {
                dict = "amb@world_human_smoking@male@male_a@base",
                anim = "base"
            },
            time = 6000,
            stressRemove = {
                min = 10,
                max = 15
            },
            requiredItem = "lighter",   -- PLAYER MUST HAVE THIS ITEM
            prop = "ng_proc_cigarette01a",
            attach = {
                bone = 28422,
                pos = { x = 0.0, y = 0.0, z = 0.0 },
                rot = { x = 0.0, y = 0.0, z = 0.0 }
            }
        }
    },

    ["royal_drift"] = {
        label = "Royal Drift Cigarette",
        cigAmount = 12,
        giveItem = "royal_cigs",
        openAnimation = {
                type = "scenario",
                name = "PROP_HUMAN_PARKING_METER"
            },
        boxProp = "prop_cigar_pack_02",
        customAttach = false,
        bonus = {
            { item = "royal_coupon", chance = 50, amount = 1 }
        },
        consume = true,
        consumeSettings = {
            animationOptions = {
                dict = "amb@world_human_aa_smoke@male@idle_a",
                anim = "idle_a"
            },
            time = 6000,
            stressRemove = {
                min = 15,
                max = 20
            },
            requiredItem = "lighter",   -- player must have this item

            prop = "ng_proc_cigarette01a",
            attach = {
                bone = 28422,
                pos = { x = 0.02, y = 0.0, z = 0.0 },
                rot = { x = 0.0, y = 0.0, z = 20.0 }
            }
        }
    },

    ["black_velvet"] = {
        label = "Black Velvet Cigarette",
        cigAmount = 15,
        giveItem = "black_cigs",
        openAnimation = {
            type = "scenario",
            name = "PROP_HUMAN_PARKING_METER"
        },
        boxProp = "prop_cigar_pack_01",
        customAttach = {
            bone = 57005,
            pos = { x = 0.15, y = 0.02, z = -0.01 },
            rot = { x = 60.0, y = 0.0, z = 200.0 }
        },
        bonus = {
            { item = "velvet_coupon", chance = 50, amount = 1 },
        },
        consume = true,
        consumeSettings = {
            animationOptions = {
                dict = "amb@world_human_smoking@male@male_a@base",
                anim = "base"
            },
            time = 6000,
            stressRemove = {
                min = 20,
                max = 25
            },
            requiredItem = "lighter",   -- PLAYER MUST HAVE THIS ITEM
            prop = "ng_proc_cigarette01a",
            attach = {
                bone = 28422,
                pos = { x = 0.03, y = -0.01, z = 0.0 },
                rot = { x = 10.0, y = 0.0, z = 10.0 }
            }
        }
    }
}

