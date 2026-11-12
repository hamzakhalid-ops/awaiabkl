# HOLLOW SHIFT

A co-op horror game for Roblox for **up to 5 players**. Your crew works the night shift in an abandoned facility. Haul valuables to make quota, get the generators running again, and reach the service elevator before the night ends. Three monsters hunt you, and each one follows different rules.

Each round builds a new facility, so you don't need to make any maps or models in Studio. Everything is created by code.

## How a round works

1. **Lobby:** wait for players. The shift starts 30s after the first player joins, or 5s once the crew is full (5/5).
2. **The facility:** a new 7×7 maze of rooms. Many rooms are dark, and some lights flicker.
3. **Objectives:**
   - **Quota:** pick up loot (`E`) and carry it to the loading chute in the starting room. Heavy items slow you down.
   - **Generators:** repair 3 generators. You must stand still while repairing, and random skill checks appear (`Space`). A failed check makes a loud bang. Each finished generator turns the lights back on in nearby rooms.
   - **Escape:** when both objectives are done, the elevator opens. Once someone steps inside, it leaves after 15s, or after 3s if everyone still alive is inside. Anyone left outside is lost.
4. **Losing:** the 10-minute timer runs out, or the whole crew is downed. In the last 2 minutes the monsters get faster.

### Survival systems
| System | How it works |
|---|---|
| **Health / Downed** | Monster hits lower your HP. At 0 you are **downed**: you can only crawl, and you bleed out in 45s. A teammate holds `E` on you for 4s to revive you. |
| **Sanity** | Drops in the dark and near monsters. Recovers in lit rooms and the starting room. Teammates within 15 studs halve the drain. Low sanity brings screen distortion and hallucinations, and monsters spot you from farther away. |
| **Stamina** | Sprinting uses it up. |
| **Flashlight battery** | `F` toggles the flashlight, which drains the battery. Batteries are scattered around the map. |
| **Camera flash** | `R` takes a photo. Your first photo of each monster type adds a $ bonus to quota. The flash **stuns the Hollow** for 3s, but it costs battery and makes noise. |

### The monsters
| Monster | Rules | How to survive |
|---|---|---|
| **The Hollow** | Wanders and chases anyone it sees. A flashlight makes you easier to spot, crouching makes you harder to spot. | Break line of sight, crouch, or stun it with the camera flash. |
| **The Still** | Shows up at 2:00. It only moves while **nobody is looking at it**, and moves very fast when it does. One touch puts you down. | Keep watching it. Walk backwards. Have someone cover your back. |
| **The Hum** | Shows up at 4:00. It is blind and hunts by **sound**: sprinting, footsteps, dropped loot, failed skill checks, camera flashes. | Crouch-walk past it. Make a noise somewhere else to lure it away. |

A second Hollow joins when 4 or more players are in the crew.

## Controls
| Key | Action |
|---|---|
| `E` | Pick up / deposit / repair / revive / take battery |
| `Q` | Drop item |
| `Shift` | Sprint |
| `C` or `Ctrl` | Toggle crouch |
| `F` | Flashlight |
| `R` | Camera flash |
| `Space` | Skill check |
| Click / `[` `]` | Switch spectate target when dead or escaped |

Mobile players get on-screen buttons, and gamepads are supported.

## Inspired by indie Steam horror
Each game below inspired one mechanic. No names, characters, or art are taken from them.

| Game | What it inspired |
|---|---|
| Lethal Company | Making quota by hauling loot through a dangerous facility |
| R.E.P.O. | Carrying valuables back with your crew, and heavy items slowing you down |
| Phasmophobia | First-person co-op horror, darkness, and a sanity meter |
| Content Warning | Photos of monsters as a reward |
| Dead by Daylight | Generator repairs with skill checks, getting downed, and teammate revives |
| Amnesia: The Dark Descent | Sanity loss in the dark, and hallucinations |
| Five Nights at Freddy's | Limited battery and power |
| SCP – Containment Breach | A monster that only moves when nobody is looking (the Still) |
| Outlast | Using a camera as your tool to survive |
| Labyrinthine | Co-op escape through a randomly generated maze |

## Setup

The project uses [Rojo](https://rojo.space) to sync the scripts into Studio.

1. Install Rojo (with Aftman/Rokit, or download it from the Rojo releases page) and the Rojo Studio plugin.
2. In this folder, run:
   ```bash
   rojo serve
   ```
3. Open a new **Baseplate** place in Roblox Studio, then click **Connect** in the Rojo plugin. The baseplate and default spawn are removed automatically.
4. Press **Play** to test solo, or use **Test → Clients and Servers** with 2–5 players to test co-op.

You can also build a place file instead:
```bash
rojo build -o HollowShift.rbxlx
```

### Before publishing
- **Game Settings → Places → Server Size: 5** (scripts can't change this setting).
- In `src/shared/Config.luau`, set `MIN_PLAYERS = 2` or higher so public servers don't start a shift with one player.
- Turn on **Game Settings → Security → Enable Studio Access to API Services** if you want stats (Escapes / Nights / Earned) saved in Studio.
- Turn on **Voice Chat**. Roblox voice is proximity-based, which suits this game well.

### Adding sound (recommended)
Audio IDs aren't included, because Roblox audio availability changes over time. Find horror sounds in the Creator Store and paste their IDs into `Config.SOUNDS`:
```lua
Heartbeat = "rbxassetid://<id>",
Jumpscare = "rbxassetid://<id>",
Whisper = "rbxassetid://<id>",
StillCreak = "rbxassetid://<id>",
Ambience = "rbxassetid://<id>",
```

## Project layout
```
src/
  shared/
    Config.luau         all tuning: timers, quota, monster stats, loot table, sounds
    Remotes.luau        RemoteEvents (created by the server, awaited by clients)
  server/
    init.server.luau    round manager: lobby → shift → results
    Lobby.luau          lobby room + dark lighting
    MapGenerator.luau   procedural maze facility, lights, elevator, chute
    LootService.luau    loot, batteries, carrying, depositing
    GeneratorService.luau  repairs, skill checks, restoring power
    MonsterService.luau Hollow / Still / Hum AI (pathfinding)
    PlayerService.luau  HP, sanity, stamina, battery, downed/revive, death, escape
    Noise.luau          sound events the Hum listens to
    Stats.luau          leaderstats + DataStore
  client/
    init.client.luau    controls, server events, HUD loop
    HUD.luau            all UI (built in code)
    SkillCheck.luau     skill check minigame
    Effects.luau        flashlight, sanity post-FX, heartbeat, shake, hallucinations, spectate
```

To tune difficulty, change the numbers in `Config.luau`. For example: `ROUND_TIME`, `QUOTA_PER_PLAYER`, `MONSTERS.Still.speed`, and `DARK_ROOM_CHANCE`.
