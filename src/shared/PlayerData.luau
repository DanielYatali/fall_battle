local Shared = {}

Shared.DEFAULT_PLAYER_DATA = {
    gems = 10,
}

export type PlayerData = typeof(Shared.DEFAULT_PLAYER_DATA)

return Shared
