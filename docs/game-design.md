# Vice Bloxy Game Design

Vice Bloxy is a playable city game where one player can control multiple characters. The player starts with one character from a gacha roll. That character has random base stats.

The player directly controls one character at a time, like in GTA. While playing as that character, the player can assign tasks for their other characters to carry out autonomously, like in The Sims.

## Core gameplay loop

```text
Play freely in the city -> Level up the character and earn money -> Get chances for more characters
       ^                                                                            |
       +----------------------------------------------------------------------------+
```

- Jobs and tasks earn money the player can spend on things for their characters.
- As the player progresses, they get opportunities to acquire more characters, including higher-tier characters from better character sets.
- Certain activities earn Renown.
- The city has zones for player-versus-player (PvP) gameplay.

## First playable stage

```text
Player spawns for the first time
    |
    v
Game offers a gacha roll for the first avatar
    |
    v
Player rolls and receives an avatar with random base stats
    |
    v
Player takes control of that avatar in the standard Roblox view
    |
    v
Player takes an existing job, completes its tasks, and earns money
```

Use the game's existing models and assets for this stage.

## Player saves

- Save the player's account-wide money balance and overall player level in their profile.
- Keep the player's character roster, including their first gacha avatar, in the profile or in a separate structure that the profile references.
- Save base stats and level separately for each character.
- When the player returns, load their profile, roster, and each character's saved stats and level.
