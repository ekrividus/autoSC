# autoSC
FFXI Windower addon to help with closing skillchains

By defualt it will cycle all available WSs and check to see if one is at the target *level* and if it is will fire it. If none at target level are found will fire the highest tier available that has been allowed for closes.

### Usage:
autosc or asc [option 1] [option 2]

With no options will toggle running
* on/off - To start/stop it 
* debug - To fill your chatlog with messages you may want to see
* help - A less throurough version of this readme
* status - Show current settings and such
* tp <number> - Minimum TP to attempt to close a SC
* minwin <number> - The earliest to start trying to close a SC that has been detected
* maxwin <number> - The longest to wait to use a WS when a SC has been detected
* retry <number> - How fast to try again if a WS wasn't able to be used
* frequency <number> - Update speed, not much reason to change this
* level <number> - Sets the target SC closing level from 1, 2 or 3. If a WS is available that will close at the chosen level it will be prioritized.

#### ToDo:
* (Dis)Allow closing given levels
* Add T4 SCs
* Add non-weaponskill SC effects, Konzen-Ittai for instance
* Add magic and ability SC closers, Blu spells, pets, etc.