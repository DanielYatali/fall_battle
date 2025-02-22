local Shared = {}

Shared.DEFAULT_PLAYER_DATA = {
    gems = 10,
    wins = 0,
}

export type PlayerData = typeof(Shared.DEFAULT_PLAYER_DATA)

return Shared
