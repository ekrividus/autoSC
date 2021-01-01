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


default = {}
default.update_frequency = 0.2
default.display = {text={size=12,font='Consolas'},pos={x=0,y=0},bg={visible=true}}
default.min_ws_window = 2.8
default.max_ws_window = 9.3
default.min_tp = 1000
default.close_levels = {[1]=true, [2] = true,[3] = true}
default.target_level = 2
default.attempt_delay = 0.5

settings = config.load(default)

message_ids = T{110,185,187,317,802}
skillchain_ids = T{288,289,290,291,292,293,294,295,296,297,298,299,300,301,385,386,387,388,389,390,391,392,393,394,395,396,397,767,768,769,770}
buff_dur = T{[163]=40,[164]=30,[470]=60}
info = T{}
resonating = T{}
buffs = T{}

colors = {}            -- Color codes by Sammeh
colors.Light =         '\\cs(255,255,255)'
colors.Dark =          '\\cs(0,0,204)'
colors.Ice =           '\\cs(0,255,255)'
colors.Water =         '\\cs(0,0,255)'
colors.Earth =         '\\cs(153,76,0)'
colors.Wind =          '\\cs(102,255,102)'
colors.Fire =          '\\cs(255,0,0)'
colors.Lightning =     '\\cs(255,0,255)'
colors.Gravitation =   '\\cs(102,51,0)'
colors.Fragmentation = '\\cs(250,156,247)'
colors.Fusion =        '\\cs(255,102,102)'
colors.Distortion =    '\\cs(51,153,255)'
colors.Darkness =      colors.Dark
colors.Umbra =         colors.Dark
colors.Compression =   colors.Dark
colors.Radiance =      colors.Light
colors.Transfixion =   colors.Light
colors.Induration =    colors.Ice
colors.Reverberation = colors.Water
colors.Scission =      colors.Earth
colors.Detonation =    colors.Wind
colors.Liquefaction =  colors.Fire
colors.Impaction =     colors.Lightning

sc_info = T{
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

chainbound = T{}
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
local player = nil

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

function message(text, to_log) 
	if (text == nil or #text < 1) then
		return
	end

	if (to_log) then
		log(text)
	else
		windower.add_to_chat(17, _addon.name..": "..text)
	end
end

function debug_message(text, to_log) 
	if (debug == false or text == nil or #text < 1) then
		return
	end

	if (to_log) then
		log("(debug): "..text)
	else
		windower.add_to_chat(17, _addon.name.."(debug): "..text)
	end
end

function show_help()
	message('Usage:\nautoSC on|off - turn auto magic bursting on or off\nautoSC show on|off - display messages about skillchains|magic bursts')
	show_status()
end

function show_status()
	message('Auto Skillchains: \t\t'..(active and 'On' or 'Off'))
	message('Close tier: \t'..settings.cast_type..' Tier: \t'..(settings.cast_tier))
	message('Min MP: \t\t'..settings.mp)
	message('Cast Delay: '..settings.cast_delay..' seconds')
	message('Double Burst: '..(settings.double_burst and ('On'..' delay '..settings.double_burst_delay..' seconds') or 'Off'))
	message('Check Elements - Day: '..(settings.check_day and 'On' or 'Off')..' Weather: '..(settings.check_weather and 'On' or 'Off'))
	message('Show Skillchain: \t\t'..(settings.show_skillchain and 'On' or 'Off'))
	message('Show Skillchain Elements: \t'..(settings.show_elements and 'On' or 'Off'))
	message('Show Day|Weather Elements: \t'..(settings.show_bonus_elements and 'On' or 'Off'))
	message('Show Spell: \t'..(settings.show_spell and 'On' or 'Off'))
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
				if (id and id > 0 and skills.weapon_skills[id]) then
					for _, closers in pairs (sc_info[v].closers) do
						for _, closer in pairs (closers) do
							if (T(skills.weapon_skills[id].skillchain):contains(closer)) then
								ws_options:append({name=skills.weapon_skills[id].en,lvl=closers[1]})
							end
						end
					end
				end
			end
		end
	else
		for _, id in pairs (weapon_skills) do
			if (id and id > 0 and skills.weapon_skills[id]) then
				for _, closers in pairs (sc_info[last_skillchain.english].closers) do
					for _, closer in pairs (closers) do
						if (T(skills.weapon_skills[id].skillchain):contains(closer)) then
							ws_options:append({name=skills.weapon_skills[id].en,lvl=closers[closer][1]})
						end
					end
				end
			end
		end
	end

	debug_message("WSes found: "..#ws_options)
	if (#ws_options == 0) then
		return nil
	elseif (#ws_options == 1) then
		return ws_options[1].name
	else -- TODO: This needs to return the most appropriate for current settings, for now just return w/e
		for _, ws in pairs(ws_options) do
			if (ws.lvl == settings.target_level) then
				return ws.name
			elseif (settings.close_levels[ws.lvl]) then
				return ws.name
			end
		end
		return ws_options[1].name
	end
	return nil
end -- get_weaponskill()

function use_weaponskill(ws_name) 
	if (active) then
		windower.send_command('input /ws "'..ws_name..'" <t>')
	end
end

--[[ Windower Events ]]--
windower.register_event('prerender', function(...)
	local time = os.clock()
	local delta_time = time - last_frame_time
	last_frame_time = time

	ws_window = ws_window + delta_time
	if (last_check_time + settings.update_frequency > time) then
		return
	end
	last_check_time = time

	if (sc_opened and ws_window/10 >= settings.max_ws_window) then
		debug_message("Skillchain window expired: "..ws_window)
		skillchain_closed()
		return
	end
	if (is_busy > 0) then
		is_busy = (is_busy - delta_time) < 0 and 0 or (is_busy - delta_time)
	end

	if (sc_opened and weaponskill_ready() and ws_window > settings.min_ws_window and ws_window < settings.max_ws_window) then
		if (ws_window > sc_effect_duration) then
			debug_message("WS window expired, sc effect wore.")
			skillchain_closed()
			return
		end
		if (last_attempt + settings.attempt_delay > time) then 
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
        local step = (reson and reson.step or 1) + 1

		sc_effect_duration = 11-step
		debug_message("1?"..skillchain.." L"..level.." Step: "..step)
		if (level == 4) then
			skillchain_closed()
			return
		end
		skillchain_opened(skillchains:with('english', skillchain))
		return
	elseif ability and (message_ids:contains(message_id) or message_id == 2 and buffs[actor] and chain_buff(buffs[actor])) then
		sc_effect_duration = 11
		debug_message("2? "..target.id.." Used: "..skills[resource][action_id].en.." Eff: "..T(skills[resource][action_id].skillchain):concat(", "))
		local s = T{english="Base",lvl=0,elements=T{},chains=T(skills[resource][action_id].skillchain)}
		skillchain_opened(s)
--        apply_properties(target.id, resource, action_id, aeonic_prop(ability, actor), ability.delay or 3, 1)
    elseif message_id == 529 then
		debug_message("3? Message 529")
--        apply_properties(target.id, resource, action_id, chainbound[param], 2, 1, false, param)
    elseif message_id == 100 and buff_dur[param] then
		debug_message("4? Message 100")
--        buffs[actor] = buffs[actor] or {}
--        buffs[actor][param] = buff_dur[param] + os.time()
    end
end

ActionPacket.open_listener(action_handler)

-- Stop checking if logout happens
windower.register_event('logout', 'zone change', 'job change', function(...)
	windower.send_command('autoSC off')
	player = nil
	return
end)

-- Process incoming commands
windower.register_event('addon command', function(...)
	local cmd = 'help'
	if (#arg > 0) then
		cmd = arg[1]
	end

	if (cmd == 'test') then
		local test_skillchain = {}
		local test_spell = nil

		test_skillchain.english = 'Test Chain'
		test_skillchain.elements = {'Earth','Light','Fire', 'Ice'}
		test_spell = get_spell(test_skillchain, nil, false, true)
		message('Test Spell: '..test_spell ~= nil and test_spell or 'Not Found')
		return
	elseif (cmd == 'help') then
		show_help()
		return
	elseif (cmd == 'status' or cmd == 'show') then
		show_status()
		return
	elseif (cmd == 'on') then
		windower.add_to_chat(17, 'autoSC activating')
		player = windower.ffxi.get_player()
		active = true
		last_check_time = os.clock()
        return
    elseif (cmd == 'off') then
        windower.add_to_chat(17, 'autoSC deactivating')
        active = false
		return
	elseif (cmd == 'cast' or cmd == 'c') then
		if (#arg < 2) then
			windower.add_to_chat(17, "Usage: autoSC cast spell|helix|jutsu\nTells autoSC what magic type to try to cast if the default is not what you want.")
		end
		if (T(cast_types):contains(arg[2]:lower())) then
			settings.cast_type = arg[2]:lower()
		end
		settings:save()
		return
	elseif (cmd == 'tier' or cmd == 't') then
		if (#arg < 2) then
			windower.add_to_chat(17, "Usage: tier 1~6\nTells autoSC what tier spell to use for Ninjutsu 1~3 will become ichi|ni|san.")
			return
		end
		local t = tonumber(arg[2])
		if (settings.cast_type == 'jutsu') then
			if (settings.cast_tier > 0 and settings.cast_tier < 4) then
				settings.cast_tier = t
			end
		else
			if (t > 0 and t < 7) then
				settings.cast_tier = t
			end		
		end
		settings:save()
		message("Cast Tier set to: "..t.." ["..(settings.cast_type == 'jutsu' and jutsu_tiers[settings.cast_tier].suffix or magic_tiers[settings.cast_tier].suffix).."]")
		return
	elseif (cmd == 'mp') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			windower.add_to_chat(17, "Usage: autoSC mp #")
			return
		end
		settings.mp = n
		settings:save()
		return
	elseif (cmd == 'delay' or cmd == 'd') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			windower.add_to_chat(17, "Usage: autoSC delay #")
			return
		end
		settings.cast_delay = n
		settings:save()
		return
	elseif (cmd == 'frequency' or cmd == 'f') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			windower.add_to_chat(17, "Usage: autoSC (f)requency #")
			return
		end
		settings.frequency = n
		settings:save()
		return
	elseif (cmd == 'doubleburst' or cmd == 'double' or cmd == 'dbl') then
		settings.double_burst = not settings.double_burst
		settings:save()
		return
	elseif (cmd == 'doubleburstdelay' or cmd == 'doubledelay' or cmd == 'dbldelay' or cmd == 'dbld') then
		local n = tonumber(arg[2])
		if (n == nil or n < -10 or n > 10) then
			windower.add_to_chat(17, "Usage: autoSC doubleburstdelay [-10..10]")
			return
		end
		settings.double_burst_delay = n
		settings:save()
		return
	elseif (cmd == 'weather') then
		settings.check_weather = not settings.check_weather
		message('Will'..(settings.check_weather and ' ' or ' not ')..'use current weather bonuses')
	elseif (cmd == 'day') then
		settings.check_day = not settings.check_day
		message('Will'..(settings.check_day and ' ' or ' not ')..'use current day bonuses')
	elseif (cmd == 'toggle' or cmd == 'tog') then
		local what = 'all'
		local toggle = 'toggle'

		if (#arg > 1) then
			what = arg[2]:lower()
		end

		if (#arg > 2) then
			toggle = arg[3]:lower()
		end

		-- Show/Hide skillchain name/elements and spell(s) to be cast
		if (what == 'skillchain' or what == 'sc' or what == 'all') then
			if (toggle == '' or toggle == 'toggle') then
				settings.show_skillchain = not settings.show_skillchain
			else
				settings.show_skillchain = (toggle == 'on')
			end
			windower.add_to_chat(17, 'autoSC: Skillchain info will be '..(settings.show_skillchain == true and 'shown' or 'hidden'))
        end
		
		if (what == 'elements' or what == 'element' or what == 'all') then
			if (toggle == 'toggle') then
				settings.show_elements = not settings.show_elements
			else
				settings.show_elements = (toggle == 'on')
			end
			windower.add_to_chat(17, 'autoSC: Skillchain element info will be '..(settings.show_elements == true and 'shown' or 'hidden'))
        end

		if (what == 'weather' or what == 'bonus' or what == 'all') then
			if (toggle == 'toggle') then
				settings.show_bonus_elements = not settings.show_bonus_elements
			else
				settings.show_bonus_elements = (toggle == 'on')
			end
			windower.add_to_chat(17, 'autoSC: Day/Weather element info will be '..(settings.show_bonus_elements == true and 'shown' or 'hidden'))
        end

		if (what == 'spell' or what == 'sp' or what == 'all') then
			if (toggle == 'toggle') then
				settings.show_spell = not settings.show_spell
			else
				settings.show_spell = (toggle == 'on')
			end
			windower.add_to_chat(17, 'autoSC: Spell info will be '..(settings.show_spell == true and 'shown' or 'hidden'))
		end

		settings:save()
		return
	elseif (cmd == 'stepdown' or cmd == 'sd') then
		local txt = ''
		if (settings.step_down == 0) then
			settings.step_down = 1
			txt = 'on target change'
		elseif (settings.step_down == 1) then
			settings.step_down = 2
			txt = 'always'
		else
			settings.step_down = 0
			txt = 'never'
		end
		settings:save()
		message("Double burst Step Down set to "..txt)
		return
	elseif (cmd == 'gearswap' or cmd == 'gs') then
		if (settings.gearswap) then
			settings.gearswap = false
		else
			settings.gearswap = true
		end
		message("Will "..(settings.gearswap and '' or ' not ').."use 'gs c bursting' and 'gs c notbursting'")
		settings:save()
		return
	elseif (cmd == 'debug') then
		debug = not debug
		message("Will"..(debug and ' ' or ' not ').."show debug information")
		return
	elseif (cmd == 'target' or 'tgt') then
		if (settings.change_target == nil) then
			settings.change_target = false
		end
		settings.change_target = not settings.change_target
		message("Auto target swapping "..(settings.change_target and 'enabled' or 'disabled')..".")
		settings:save()
		return
    end
end) -- Addon Command
