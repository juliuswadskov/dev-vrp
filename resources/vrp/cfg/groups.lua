
local cfg = {}

-- define each group with a set of permissions
-- _config property:
--- title (optional): group display name
--- gtype (optional): used to have only one group with the same gtype per player (example: a job gtype to only have one job)
--- onspawn (optional): function(player) (called when the player spawn with the group)
--- onjoin (optional): function(player) (called when the player join the group)
--- onleave (optional): function(player) (called when the player leave the group)
--- (you have direct access to vRP and vRPclient, the tunnel to client, in the config callbacks)

cfg.groups = {
  ["superadmin"] = {
    _config = {
      onspawn = function(player) 
        -- når du spawner med ranket
      end,
      onleave = function(player)
        -- når man får ranket taget fra sig
      end,
      onjoin = function(player)
        -- når man joiner ranket
      end
    },
    "*"
  },

  -- the group user is auto added to all logged players
  ["user"] = {
    "player.phone",
    "player.calladmin",
    "police.askid",
    "police.store_weapons",
    "police.seizable" -- can be seized
  },
}

-- Ranks som user_id 1 skal have
cfg.userOne = {
  "superadmin"
}

-- group selectors
-- _config
--- x,y,z, blipid, blipcolor, permissions (optional)
cfg.selectors = {
  ["Job Selector"] = {
    _config = {x = 1854.21, y = 3685.51, z = 34.2671, blipid = 351, blipcolor = 47},
    "police",
    "taxi",
    "repair",
    "citizen",
    "superadmin"
  }
}

return cfg

