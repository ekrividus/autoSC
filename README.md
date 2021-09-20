# autoSC
FFXI Windower addon to help with opening and closing skillchains

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
* level <number> - Sets the target SC closing level from 1, 2, 3 or 4. If a WS is available that will close at the chosen level it will be prioritized.
* close <number> - Toggles whether to close a given tier 1, 2, 3 or 4. If a tier is disabled it will may not close anything.
* open - Toggle whether or not the set WS should be used to open fresh SCs when no SC effect is already present.
* honor/wait - Will *honor* the currently open SC effect *wait*ing for it to wear before opening a new SC.
* ws <ws name> - Will set the WS to use for opening a SC and the _open_ option is toggled on.
  * WSs are saved per job and per weapon, so you can use RMEA or quested WSs with appropriate weapons for openers if desired.
* Ranged - Toggle allowing the use of ranged WSes
* PreferRanged - Toggles prioritizing ranged WSes over melee

#### ToDo:
* (Dis)Allow closing given levels
  * Done, appears to be working as intended
* Add T4 SCs
  * Can now close T4 and recognizes T4 but doesn't always honor double T3 ...
  * Double T3 are being recognized as closed, mostly
* Break off Ranged WSs so they can be enabled/disabled seperately
 * Done
* Add melee/ranged WS preferences, based on user choice > actual combat range
 * Done
* Maybe add autoRA and gearswap interaction
* Add Job Ability SC effects, Konzen-Ittai for instance
* Add magic and ability SC closers, Blu spells, pets, etc.
* Add ability to open SCs if no SC effect is already present and TP > 1000 
  * Done, appears to be working as intended
  * Added option to wait for existing SC effect to end, even if unable to close it this way you don't open a new SC when someone else could have closed