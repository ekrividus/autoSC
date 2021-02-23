--[[
Copyright © 2020, Ekrividus
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of autoSC nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Ekrividus BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

--[[
autoSC will attempt to close an open skillchain
will use the highest tier closing it can, does not care about a specific WS
]]
_addon.version = '0.1.0'
_addon.name = 'autoSC'
_addon.author = 'Ekrividus'
_addon.commands = {'autoskillchain', 'autoSC', 'asc'}
_addon.lastUpdate = '12/21/2020'
_addon.windower = '4'

require 'tables'
require 'strings'
require 'logger'
require 'luau'
require 'pack'
require 'actions'

res = require('resources')
config = require('config')
chat = require('chat')
packets = require('packets')

skills = require('skills')

local bags = {[0]='inventory',[8]='wardrobe',[10]='wardrobe2',[11]='wardrobe3',[12]='wardrobe4'}
local message_ids = T{110,185,187,317,802}
local skillchain_ids = T{288,289,290,291,292,293,294,295,296,297,298,299,300,301,385,386,387,388,389,390,391,392,393,394,395,396,397,767,768,769,770}
local buff_dur = T{[163]=40,[164]=30,[470]=60}
local info = T{}
local resonating = T{}
local buffs = T{}

local sc_info = T{
    Radiance = {elements={'Fire','Wind','Lightning','Light'}, closers={}, lvl=4},
    Umbra = {elements={'Earth','Ice','Water','Dark'}, closers={}, lvl=4},
    Light = {elements={'Fire','Wind','Lightning','Light'}, closers={Light={4,'Light','Radiance'}}, lvl=3},
    Darkness = {elements={'Earth','Ice','Water','Dark'}, closers={Darkness={4,'Darkness','Umbra'}}, lvl=3},
    Gravitation = {elements={'Earth','Dark'}, closers={Distortion={3,'Darkness'}, Fragmentation={2,'Fragmentation'}}, lvl=2},
    Fragmentation = {elements={'Wind','Lightning'}, closers={Fusion={3,'Light'}, Distortion={2,'Distortion'}}, lvl=2},
    Distortion = {elements={'Ice','Water'}, closers={Gravitation={3,'Darkness'}, Fusion={2,'Fusion'}}, lvl=2},
    Fusion = {elements={'Fire','Light'}, closers={Fragmentation={3,'Light'}, Gravitation={2,'Gravitation'}}, lvl=2},
    Compression = {elements={'Darkness'}, closers={Transfixion={1,'Transfixion'}, Detonation={1,'Detonation'}}, lvl=1},
    Liquefaction = {elements={'Fire'}, closers={Impaction={2,'Fusion'}, Scission={1,'Scission'}}, lvl=1},
    Induration = {elements={'Ice'}, closers={Reverberation={2,'Fragmentation'}, Compression={1,'Compression'}, Impaction={1,'Impaction'}}, lvl=1},
    Reverberation = {elements={'Water'}, closers={Induration={1,'Induration'}, Impaction={1,'Impaction'}}, lvl=1},
    Transfixion = {elements={'Light'}, closers={Scission={2,'Distortion'}, Reverberation={1,'Reverberation'}, Compression={1,'Compression'}}, lvl=1},
    Scission = {elements={'Earth'}, closers={Liquefaction={1,'Liquefaction'}, Reverberation={1,'Reverberation'}, Detonation={1,'Detonation'}}, lvl=1},
    Detonation = {elements={'Wind'}, closers={Compression={2,'Gravitation'}, Scission={1,'Scission'}}, lvl=1},
    Impaction = {elements={'Lightning'}, closers={Liquefaction={1,'Liquefaction'}, Detonation={1,'Detonation'}}, lvl=1},
}

local chainbound = T{}
chainbound[1] = T{'Compression','Liquefaction','Induration','Reverberation','Scission'}
chainbound[2] = T{'Gravitation','Fragmentation','Distortion'} + chainbound[1]
chainbound[3] = T{'Light','Darkness'} + chainbound[2]

local aeonic_weapon = T{
    [20515] = 'Godhands',
    [20594] = 'Aeneas',
    [20695] = 'Sequence',
    [20843] = 'Chango',
    [20890] = 'Anguta',
    [20935] = 'Trishula',
    [20977] = 'Heishi Shorinken',
    [21025] = 'Dojikiri Yasutsuna',
    [21082] = 'Tishtrya',
    [21147] = 'Khatvanga',
    [21485] = 'Fomalhaut',
    [21694] = 'Lionheart',
    [21753] = 'Tri-edge',
    [22117] = 'Fail-Not',
    [22131] = 'Fail-Not',
    [22143] = 'Fomalhaut'
}

local skillchains = T{
	[288] = {id=288,english='Light',elements={'Light','Thunder','Wind','Fire'}},
	[289] = {id=289,english='Darkness',elements={'Dark','Ice','Water','Earth'}},
	[290] = {id=290,english='Gravitation',elements={'Dark','Earth'}},
	[291] = {id=291,english='Fragmentation',elements={'Thunder','Wind'}},
	[292] = {id=292,english='Distortion',elements={'Ice','Water'}},
	[293] = {id=293,english='Fusion',elements={'Light','Fire'}},
	[294] = {id=294,english='Compression',elements={'Dark'}},
	[295] = {id=295,english='Liquefaction',elements={'Fire'}},
	[296] = {id=296,english='Induration',elements={'Ice'}},
	[297] = {id=297,english='Reverberation',elements={'Water'}},
	[298] = {id=298,english='Transfixion', elements={'Light'}},
	[299] = {id=299,english='Scission',elements={'Earth'}},
	[300] = {id=300,english='Detonation',elements={'Wind'}},
	[301] = {id=301,english='Impaction',elements={'Thunder'}}
}

local active = false
local debug = false
local player = windower.ffxi.get_player()

local finish_act = L{2,3,5}
local start_act = L{7,8,9,12}
local is_busy = 0
local is_casting = false

local last_check_time = os.clock()
local last_frame_time = 0
local ability_delay = 1.3
local after_cast_delay = 1.5
local failed_cast_delay = 2

local sc_opened = false
local sc_effect_duration = 0
local ws_window = 0
local last_attempt = 0

local defaults = T{}
defaults.update_frequency = 0.1
defaults.display = {text={size=12,font='Consolas'},pos={x=0,y=0},bg={visible=true}}
defaults.min_ws_window = 2.75
defaults.max_ws_window = 8
defaults.min_tp = 1000
defaults.close_levels = {[1]=true,[2]=true,[3]=true,[4]=true}
defaults.target_level = 2
defaults.attempt_delay = 0.5
defaults.open_sc = false

local settings = T{}
settings = config.load("data/"..player.name..".xml", defaults)
if (settings.open_sc == nil) then
	settings.open_sc = false
end

local function tchelper(first, rest)
    return first:upper()..rest:lower()
end

function title_case(str)
    if (str == nil) then
        return str
    end
    str = str:gsub("(%a)([%w_']*)", tchelper)
    return str
end

function message(text, to_log) 
	to_log = to_log or false
	if (text == nil) then
		return
	end

	if (to_log) then
		log(text)
	else
		windower.add_to_chat(17, _addon.name..": "..text)
	end
end

function debug_message(text, to_log) 
	if (debug == false or text == nil) then
		return
	end

	if (to_log) then
		log("(debug): "..text)
	else
		windower.add_to_chat(17, _addon.name.." (debug): "..text)
	end
end

function show_help()
	message(
		[[Usage:\n
		autoSC on|off - turn auto skillchaining on or off\n'
		]])
	show_status()
end

function show_status()
	message('Auto Skillchains: \t\t'..(active and 'On' or 'Off'))
	for k, v in pairs(settings) do
		if (type(v) == 'table') then
			local str = tostring(k)..": "
			for x, y in pairs(v) do
				if (type(y) == 'table') then
				else
					str = str.."["..tostring(x).."? "..tostring(y).."] "
				end
			end
			message(str)
		else
			message(k.." - "..tostring(v))
		end
	end
end

function buff_active(id)
    if T(windower.ffxi.get_player().buffs):contains(BuffID) == true then
        return true
    end
    return false
end

function disabled()
    if (buff_active(0)) then -- KO
        return true
    elseif (buff_active(2)) then -- Sleep
        return true
    elseif (buff_active(6)) then -- Silence
        return true
    elseif (buff_active(7)) then -- Petrification
        return true
    elseif (buff_active(10)) then -- Stun
        return true
    elseif (buff_active(14)) then -- Charm
        return true
    elseif (buff_active(28)) then -- Terrorize
        return true
    elseif (buff_active(29)) then -- Mute
        return true
    elseif (buff_active(193)) then -- Lullaby
        return true
    elseif (buff_active(262)) then -- Omerta
        return true
    end
    return false
end

function skillchain_opened(sc)
	debug_message("Skillchain opened ("..sc.english..")")
	last_skillchain = sc
	ws_window = 0
	last_attempt = 0
	sc_opened = true
end

function skillchain_closed()
	debug_message("Skillchain closed")
	ws_window = 0
	sc_opened = false
	last_skillchain = T{}
	last_skillchain.english = 'None'
	last_skillchain.elements = T{}
	last_skillchain.chains = T{}
	ws_window = 0
	sc_opened = false
end

function weaponskill_ready()
	player = windower.ffxi.get_player()
	if (not disabled() and not is_casting and is_busy <= 0 and (player.vitals.tp >= (settings.min_tp > 1000 and settings.min_tp or 1000))) then
		return true
	end
	return false
end

function get_weaponskill()
	debug_message("Finding WSes")
	local weapon_skills = T(windower.ffxi.get_abilities().weapon_skills)
	local ws_options = T{}
	if (last_skillchain == nil or (#last_skillchain.elements < 1 and #last_skillchain.chains < 1)) then return "" end

	if (last_skillchain.chains and #last_skillchain.chains >= 1) then
		for _, v in pairs (last_skillchain.chains) do
			for _, id in pairs (weapon_skills) do
				if (id and skills.weapon_skills[id]) then
					for sc_closer, sc_result in pairs (sc_info[v].closers) do
						if (T(skills.weapon_skills[id].skillchain):contains(sc_closer)) then
							ws_options:append({name=skills.weapon_skills[id].en,lvl=sc_result[1]})
						end
					end
				end
			end
		end
	else
		for _, id in pairs (weapon_skills) do
			if (id and id > 0 and skills.weapon_skills[id]) then
				for sc_closer, sc_result in pairs (sc_info[last_skillchain.english].closers) do
					if (T(skills.weapon_skills[id].skillchain):contains(sc_closer)) then
						ws_options:append({name=skills.weapon_skills[id].en,lvl=sc_result[1]})
					end
				end
			end
		end
	end

	if (debug) then
		local l = ""
		for k, v in pairs(ws_options) do
			l = l..","..v.name
		end 
		debug_message("WSes found: "..#ws_options.." "..l)
	end

	if (#ws_options == 0) then
		return nil
	elseif (#ws_options == 1) then
		return ws_options[1].name
	else 
		-- TODO: This needs to return the most appropriate for current settings, for now just return w/e
		local ws_to_use = nil
		for _, ws in pairs(ws_options) do
			if (ws.lvl == settings.target_level) then
				return ws.name
			end
		end
		for _, ws in pairs(ws_options) do
			if (settings.close_levels[ws.lvl]) then
				if (ws_to_use == nil or ws.lvl > ws_to_use.lvl) then
					ws_to_use = ws
				end
			end
		end
		if (ws_to_use ~= nil) then
			return ws_to_use.name
		end
		return ws_options[1].name
	end
	return nil
end -- get_weaponskill()

function use_weaponskill(ws_name) 
	if (active) then
		--if (windower.ffxi.get_mob_by_target('t').vitals.hpp < settings.max_hp) then return end
		windower.send_command('input /ws "'..ws_name..'" <t>')
	end
end

function open_skillchain()
	player = windower.ffxi.get_player()
	local mob = windower.ffxi.get_mob_by_target("t")
	if (mob == nil or not active or player.status ~= 1 or player.vitals.tp < 1000) then return end
	
	local items,weapon,bag = nil
	items = windower.ffxi.get_items()
	weapon,bag = items.equipment.main, items.equipment.main_bag

	if (weapon == nil or bag == nil or items == nil) then
		message("Missing weapon data: "..tostring(weapon).." - "..tostring(items).." - "..tostring(bag))
		return
	end

	local weapon_name = 'Empty'
	if weapon ~= 0 then  --0 => nothing equipped
		weapon_name = res.items[items[bags[bag]][weapon].id].en
	end

	if (settings[player.main_job:lower()] ~= nil and settings[player.main_job:lower()][weapon_name:lower()] ~= nil) then
		local ws_range = res.weapon_skills:with('name', settings[player.main_job:lower()][weapon_name:lower()]).range*2
		ws_range = ws_range + mob.model_size/2 + windower.ffxi.get_mob_by_id(player.id).model_size/2
		local dist = mob.distance:sqrt()
		if (dist > ws_range) then return end -- Don't throw away TP on out of range mobs
		use_weaponskill(settings[player.main_job:lower()][weapon_name:lower()])
	end
end

--[[ Windower Events ]]--
windower.register_event('prerender', function(...)
	local time = os.clock()
	local delta_time = time - last_frame_time
	last_frame_time = time
	ws_window = ws_window + delta_time

	if (is_busy > 0) then
		is_busy = (is_busy - delta_time) < 0 and 0 or (is_busy - delta_time)
	end

	if (last_check_time + settings.update_frequency > time) then
		return
	end
	last_check_time = time

	if (settings.open_sc and not sc_opened) then
		if (last_attempt + settings.attempt_delay > time) then 
			return
		end
		open_skillchain()
		last_attempt = time
		return
	end

	if (sc_opened and ws_window >= settings.max_ws_window) then
		debug_message("Skillchain window expired: "..ws_window)
		skillchain_closed()
		return
	end

	if (sc_opened and weaponskill_ready() and ws_window > settings.min_ws_window and ws_window < settings.max_ws_window) then
		if (ws_window > sc_effect_duration) then
			debug_message("WS window expired, sc effect wore.")
			skillchain_closed()
			return
		elseif (windower.ffxi.get_mob_by_target("t") == nil) then
			skillchain_closed()
			return
		elseif (last_attempt + settings.attempt_delay > time) then 
			return
		end
		last_attempt = time
		local ws = get_weaponskill()
		if (ws and ws ~= "") then
			debug_message("Closer found: "..ws)
			use_weaponskill(ws)
			return
		else -- There isn't a valid WS to close this chain, we can stop checking by closing wht window
			debug_message("No closer found")
			skillchain_closed()
			return
		end
	end
end)

-- Check for skillchain effects applied, this can get wonky if/when a group is skillchaining on multiple mobs at once
windower.register_event('incoming chunk', function(id, packet, data, modified, is_injected, is_blocked)
	if (id == 0x28) then
		local actions_packet = windower.packets.parse_action(packet)
		local mob_array = windower.ffxi.get_mob_array()
		local valid = false
		local party = windower.ffxi.get_party()
		local party_ids = T{}

		local category, param = data:unpack( 'b4b16', 11, 3)
		local recast, targ_id = data:unpack('b32b32', 15, 7)
		local effect, message = data:unpack('b17b10', 27, 6)
		
		player = windower.ffxi.get_player()

		if (data:unpack('I', 6) == player.id) then 
			if start_act:contains(category) then
				if param == 24931 then                  -- Begin Casting/WS/Item/Range
					is_busy = 0
					is_casting = true
				elseif param == 28787 then              -- Failed Casting/WS/Item/Range
					is_casting = false
					is_busy = failed_cast_delay
				end
			elseif category == 6 then                   -- Use Job Ability
				is_busy = ability_delay
			elseif category == 4 then                   -- Finish Casting
				is_busy = after_cast_delay
				is_casting = false
			elseif finish_act:contains(category) then   -- Finish Range/WS/Item Use
				is_busy = 0
				is_casting = false
			end
		end
	end
end)

categories = S{
    'weaponskill_finish',
    'spell_finish',
    'job_ability',
    'mob_tp_finish',
    'avatar_tp_finish',
    'job_ability_unblinkable',
}

function action_handler(act)
    local actionpacket = ActionPacket.new(act)
    local category = actionpacket:get_category_string()

    if not categories:contains(category) or act.param == 0 then
        return
    end

    local actor = actionpacket:get_id()
    local target = actionpacket:get_targets()()
    local action = target:get_actions()()
    local message_id = action:get_message_id()
    local add_effect = action:get_add_effect()
    --local basic_info = action:get_basic_info()
    local param, resource, action_id, interruption, conclusion = action:get_spell()
    local ability = skills[resource] and skills[resource][action_id]

    if add_effect and conclusion and skillchain_ids:contains(add_effect.message_id) then
        local skillchain = add_effect.animation:ucfirst()
        local level = sc_info[skillchain].lvl
        local reson = resonating[target.id]
        local delay = ability and ability.delay or 3
        local step = (reson and reson.step or 0)

		sc_effect_duration = (11-step*3) > 3 and (11-step*3) or 3
		debug_message("Skillchain effect applied: "..skillchain.." L"..level.." Step: "..step)
		if (level >= 4 or (level == 3 and skillchain == last_skillchain.english)) then -- Level 4 and double light/darkness can't be continued
			skillchain_closed()
			return
		end
		local m = windower.ffxi.get_mob_by_target("t")
		if (m and m.id == target.id) then
			skillchain_opened(skillchains:with('english', skillchain))
		end
	elseif ability and (message_ids:contains(message_id) or message_id == 2 and buffs[actor] and chain_buff(buffs[actor])) then
		sc_effect_duration = 11
		debug_message("Base SC effect applied to "..target.id.." Used: "..skills[resource][action_id].en.." Eff: "..T(skills[resource][action_id].skillchain):concat(", "))
		local m = windower.ffxi.get_mob_by_target("t")
		if (m and m.id == target.id) then
			local s = T{english="Base",lvl=0,elements=T{},chains=T(skills[resource][action_id].skillchain)}
			skillchain_opened(s)
		end
    end
end

ActionPacket.open_listener(action_handler)

-- Stop checking if logout happens
windower.register_event('logout', 'zone change', 'job change', function(...)
	if (active) then
		windower.send_command('autoSC off')
	end
	player = nil
	return
end)

-- Process incoming commands
windower.register_event('addon command', function(...)
	local cmd = 'help'
	if (#arg > 0) then
		cmd = arg[1]
	end

	if (cmd == nil or #arg < 1) then
		active = not active
		message((active and "Starting" or "Stopping"))
	elseif (cmd == 'help') then
		show_help()
		return
	elseif (cmd == 'status' or cmd == 'show') then
		show_status()
		return
	elseif (cmd == 'on') then
		message("Starting")
		player = windower.ffxi.get_player()
		active = true
		last_check_time = os.clock()
        return
    elseif (cmd == 'off') then
		message("Stopping")
        active = false
		return
	elseif (cmd == 'open') then
		settings.open_sc = not settings.open_sc
		message("Will "..(settings.open_sc and "" or "not ").."open new SCs")
		settings:save(player.name)
	elseif (cmd == 'ws') then
		if (#arg < 2) then
			message("Usage: autoSC WS weaponskill name")
			return
		end
		local items,weapon,bag = nil
		items = windower.ffxi.get_items()
		weapon,bag = items.equipment.main, items.equipment.main_bag
	
		if (weapon == nil or bag == nil or items == nil) then
			message("Missing weapon data: "..tostring(weapon).." - "..tostring(items).." - "..tostring(bag))
			return
		end

		local weapon_name = 'Empty'
	    if weapon ~= 0 then  --0 => nothing equipped
			weapon_name = res.items[items[bags[bag]][weapon].id].en
		end
	
		settings[player.main_job] =	settings[player.main_job] or {}
		settings[player.main_job][weapon_name] = T(arg):slice(2, #arg):concat(" ")
		message("SC Opener for "..tostring(player.main_job).." using "..weapon_name.." set to "..tostring(settings[player.main_job][weapon_name]))
		settings:save(player.name)
	elseif (cmd == 'tp') then
		if (#arg < 2) then
			message("Usage: autoSC TP #### where #### is a number between 1000~3000")
			return
		end
		local n = tonumber(arg[2])
		if (n ~= nil and n >= 1000 and n <= 3000) then
			settings.min_tp = tonumber(arg[2])
		else
			message("TP must be a number between 1000 and 3000")
			return
		end
		settings:save(player.name)
		return
	elseif (cmd == 'minwin') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			message("Usage: autoSC minwin #")
			return
		end
		settings.min_ws_window = n
		settings:save(player.name)
		return
	elseif (cmd == 'maxwin') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			message("Usage: autoSC maxwin #")
			return
		end
		settings.max_ws_window = n
		settings:save(player.name)
		return
	elseif (cmd == 'retry') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			message("Usage: autoSC retry # Where # is the number of seconds between attempts to use a WS")
			return
		end
		settings.attempt_delay = n
		settings:save(player.name)
		return
	elseif (cmd == 'frequency' or cmd == 'f') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			message("Usage: autoSC (f)requency #")
			return
		end
		settings.update_frequency = n
		settings:save(player.name)
		return
	elseif (cmd == 'level' or cmd == 'l') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			message("Usage: autoSC (l)evel # Where # is a number between 1 and 4")
			return
		end
		settings.target_level = n
		settings:save(player.name)
		return
	elseif (cmd == 'close' or cmd == 'c') then
		local n = tonumber(arg[s])
		if (n == nil or n < 1 or n > 4) then
			message("Usage: autoSC (c)lose # Where # is the SC level to close 1..4")
			return
		end
		settings.close_levels[n] = not settings.close_levels[n]
		settings:save(player.name)
		return
	elseif (cmd == 'debug') then
		debug = not debug
		message("Will"..(debug and ' ' or ' not ').."show debug information")
		return
    end
end) -- Addon Command
