# autoSC
FFXI Windower addon to help with closing skillchains

By default will close with the first WS it finds of the highest level it can.

Usage:
autosc or asc [options]

With no options will toggle running
on/off - To start/stop it 
debug - To fill your chatlog with messages you may want to see
help - A less throurough version of this readme
status - Show current settings and such
tp <number> - Minimum TP to attempt to close a SC
minwin <number> - The earliest to start trying to close a SC that has been detected
maxwin <number> - The longest to wait to use a WS when a SC has been detected
retry <number> - How fast to try again if a WS wasn't able to be used
frequency <number> - Update speed, not much reason to change this
level <number> - Sets the target SC closing level from 1, 2 or 3. If a WS is available that will close at the chosen level it will be prioritized.

There should be more but I got tired and decided it was working well enough to make me happy.