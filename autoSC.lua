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
_addon.version = '1.1.3'
_addon.name = 'autoSC'
_addon.author = 'Ekrividus'
_addon.commands = {'autoskillchain', 'autoSC', 'asc'}
_addon.lastUpdate = '4/2/2022'
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

texts = require('texts')

local bags = {[0]='inventory',[8]='wardrobe',[10]='wardrobe2',[11]='wardrobe3',[12]='wardrobe4'}
local message_ids = T{110,185,187,317,802}
local skillchain_ids = T{288,289,290,291,292,293,294,295,296,297,298,299,300,301,385,386,387,388,389,390,391,392,393,394,395,396,397,767,768,769,770}
local buff_dur = T{[163]=40,[164]=30,[470]=60}
local info = T{}
local resonating = T{}
local buffs = T{}

local ranged_weaponskills = T{
    -- Archery
    "Flaming Arrow","Piercing Arrow","Dulling Arrow","Sidewinder","Blast Arrow","Arching Arrow",
    "Empyreal Arrow","Refulgent Arrow","Apex Arrow","Namas Arrow","Jishnu's Radiance",
    -- Marksmanship 
    "Hot Shot","Split Shot","Sniper Shot","Slug Shot","Blast Shot","Heavy Shot","Detonator",
    "Numbing Shot","Last Stand","Coronach","Wildfire","Trueflight","Leaden Salute",
}

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
local ability_delay = 1.7
local after_cast_delay = 2
local failed_cast_delay = 2.4

local sc_opened = false
local sc_effect_duration = 0
local ws_window = 0
local last_attempt = 0

local defaults = T{}
defaults.update_frequency = 0.5
defaults.min_ws_window = 2.75
defaults.max_ws_window = 8
defaults.min_tp = 1000
defaults.close_levels = {[1]=true,[2]=true,[3]=true,[4]=true}
defaults.target_sc_level = 2
defaults.attempt_delay = 0.5
-- Newly added settings, may be missing from settings files
defaults.open_sc = false
defaults.wait_to_open = true
defaults.sc_openers = T{}
defaults.ws_filters = T{}

defaults.use_ranged = false
defaults.prefer_ranged = false

defaults.display = {
	bg = {
		visible=true,
		alpha=64,
	},
	font = "Consolas",
	font_size = 10,
	padding = 2,
	pos = {x=100,y=240},
	stroke = {
		width = 1,
	},
	text = {
		size=10,
		font='Consolas'
	},
}


local settings = T{}
settings = config.load("data/"..player.name..".xml", defaults)
settings.sc_openers = settings.sc_openers or T{}
settings.ws_filters = settings.ws_filters or T{}

--[[ UI Display Setup ]]
local display = texts.new('${addon_title}', settings.display, settings)
function init_display() 
	display.addon_title = active and ("--- Auto Skillchains "):text_color(0,255,0) or ("--- Auto Skillchains "):text_color(255,0,0)

	display:appendline('Weapon: ${weapon|None}')
	display.weapon = title_case(get_weapon_name())

	display:appendline('Open new SC? ${open_sc|No} \n   Using: ${opener|None}')
	display.open_sc = settings.open_sc and tostring("Yes"):text_color(0,255,64) or tostring("No"):text_color(255,0,0)
	if (settings.sc_openers and settings.sc_openers[player.main_job:lower()] and settings.sc_openers[player.main_job:lower()][get_weapon_name()]) then 
		display.opener = settings.sc_openers and settings.sc_openers[player.main_job:lower()][get_weapon_name()]
	else
		display.opener = "None"
	end

	display:appendline('Wait for SC effect? ${wait_to_open|No}')
	display.wait_to_open = settings.wait_to_open and tostring("Yes"):text_color(0,255,64) or tostring("No"):text_color(255,0,0)

	display:appendline('Use ranged? ${use_ranged|No} \n   Prefer ranged? ${prefer_ranged|No}')
	display.use_ranged = settings.use_ranged and tostring("Yes"):text_color(0,255,64) or tostring("No"):text_color(255,0,0)
	display.prefer_ranged = settings.prefer_ranged and tostring("Yes"):text_color(0,255,64) or tostring("No"):text_color(255,0,0)

	display:appendline('Close SC Level:\n    1: ${C1|No } 2: ${C2|No } 3: ${C3|No } 4: ${C4|No }')
	display.C1 = settings.close_levels[1] and tostring("Yes"):text_color(0,255,64) or tostring("No "):text_color(255,0,0)
	display.C2 = settings.close_levels[2] and tostring("Yes"):text_color(0,255,64) or tostring("No "):text_color(255,0,0)
	display.C3 = settings.close_levels[3] and tostring("Yes"):text_color(0,255,64) or tostring("No "):text_color(255,0,0)
	display.C4 = settings.close_levels[4] and tostring("Yes"):text_color(0,255,64) or tostring("No "):text_color(255,0,0)

	display:appendline('Target SC Level: ${target_sc_level|None}')
	display.target_sc_level = tostring(settings.target_sc_level)
	
	display:appendline('WS Window:\n   Begin: ${min_win|?}  End: ${max_win|?}')
	display.min_win = tostring(settings.min_ws_window):text_color(0,255,0)
	display.max_win = tostring(settings.max_ws_window):text_color(255,0,0)

	display:appendline('Filtered WSs:\n   ${ws_filters|None}')
	display.ws_filters = (settings.ws_filters[get_weapon_name()] ~= nil) and settings.ws_filters[get_weapon_name()]:concat("\n   ") or "None"

	display:show()
end

function update_display() 
	display.addon_title = active and ("--- Auto Skillchains "):text_color(0,255,0) or ("--- Auto Skillchains "):text_color(255,0,0)

	display.weapon = title_case(get_weapon_name())

	display.open_sc = settings.open_sc and tostring("Yes"):text_color(0,255,64) or tostring("No"):text_color(255,0,0)
	if (settings.sc_openers and settings.sc_openers[player.main_job:lower()] and settings.sc_openers[player.main_job:lower()][get_weapon_name()]) then 
		display.opener = settings.sc_openers and settings.sc_openers[player.main_job:lower()][get_weapon_name()]
	else
		display.opener = "None"
	end

	display.wait_to_open = settings.wait_to_open and tostring("Yes"):text_color(0,255,64) or tostring("No"):text_color(255,0,0)

	display.use_ranged = settings.use_ranged and tostring("Yes"):text_color(0,255,64) or tostring("No"):text_color(255,0,0)
	display.prefer_ranged = settings.prefer_ranged and tostring("Yes"):text_color(0,255,64) or tostring("No"):text_color(255,0,0)

	display.C1 = settings.close_levels[1] and tostring("Yes"):text_color(0,255,64) or tostring("No "):text_color(255,0,0)
	display.C2 = settings.close_levels[2] and tostring("Yes"):text_color(0,255,64) or tostring("No "):text_color(255,0,0)
	display.C3 = settings.close_levels[3] and tostring("Yes"):text_color(0,255,64) or tostring("No "):text_color(255,0,0)
	display.C4 = settings.close_levels[4] and tostring("Yes"):text_color(0,255,64) or tostring("No "):text_color(255,0,0)

	display.target_sc_level = tostring(settings.target_sc_level)
	
	display.min_win = tostring(settings.min_ws_window):text_color(0,255,0)
	display.max_win = tostring(settings.max_ws_window):text_color(255,0,0)

	display.ws_filters = settings.ws_filters[get_weapon_name()] and settings.ws_filters[get_weapon_name()]:concat("\n   ") or "None"
end
--[[ End UI Display Setup ]]

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
		windower.add_to_chat(207, _addon.name..": "..text)
	end
end

function debug_message(text, to_log) 
	if (debug == false or text == nil) then
		return
	end

	if (to_log) then
		log("(debug): "..text)
	else
		windower.add_to_chat(207, _addon.name.." (debug): "..text)
	end
end

function show_help()
	message(
		[[Usage:\n
		autoSC on|off - turn auto skillchaining on or off\n'
		]])
	show_status()
end

function show_status(which)
	which = which or 'none'
	which = which:lower()
	message('Auto Skillchains: \t\t'..(active and 'On' or 'Off'))
	if (which == 'display') then
		message('Display Settings: No display options yet.')
	-- elseif (which == 'openers') then
	elseif (which == 'filters') then
	else
		for k, v in pairs(settings) do
			if (k == 'sc_openers') then
				local weapon = get_weapon_name():lower()
				local job = player.main_job:lower()
				local opener = tostring(settings.sc_openers[job] and (settings.sc_openers[job][weapon] or 'None for '..job) or 'None for '..weapon:split("_"):concat(" "))
				message('Opener for '..player.main_job..' using '..title_case(weapon:split("_"):concat(" "))..': '..opener)
			elseif (k == 'ws_filters') then
				local weapon = get_weapon_name():lower()
				if (settings.ws_filters and settings.ws_filters[weapon]) then
					message('Filters for '..weapon..': '..settings.ws_filters[weapon]:concat(', '))
				else
					message('Filters for '..weapon..': None')
				end
			elseif (k == 'display') then
				-- There's no display made (yet?)
			elseif (type(v) == 'table') then
				local str = title_case(tostring(k):split('_'):concat(' '))..": "
				for x, y in pairs(v) do
					if (type(y) == 'table') then
					else
						str = str.."[L"..tostring(x).." "..(y and "Yes" or "No").."] "
					end
				end
				message(str)
			else
				message(title_case(k:split('_'):concat(' ')).." - "..tostring(v))
			end
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
	debug_message("Finding WSs")
	local weapon_skills = T(windower.ffxi.get_abilities().weapon_skills)
	local ws_melee_options =T{}
	local ws_ranged_options = T{}
	if (last_skillchain == nil or (#last_skillchain.elements < 1 and #last_skillchain.chains < 1)) then return "" end

	if (last_skillchain.chains and #last_skillchain.chains >= 1) then
		for _, v in pairs (last_skillchain.chains) do
			for _, id in pairs (weapon_skills) do
				if (id and skills.weapon_skills[id]) then
					if (settings.ws_filters and settings.ws_filters[get_weapon_name()] and settings.ws_filters[get_weapon_name()]:contains(skills.weapon_skills[id].en)) then
						debug_message(skills.weapon_skills[id].en.." is filtered out, skipping it.", true)
					else 
						for sc_closer, sc_result in pairs (sc_info[v].closers) do
							if (T(skills.weapon_skills[id].skillchain):contains(sc_closer)) then
								if (ranged_weaponskills:contains(skills.weapon_skills[id].en)) then
									ws_ranged_options:append({name=skills.weapon_skills[id].en,lvl=sc_result[1]})
								else
									ws_melee_options:append({name=skills.weapon_skills[id].en,lvl=sc_result[1]})
								end
							end
						end
					end
				end
			end
		end
	else
		for _, id in pairs (weapon_skills) do
			if (id and id > 0 and skills.weapon_skills[id]) then
				if (settings.ws_filters and settings.ws_filters[get_weapon_name()] and settings.ws_filters[get_weapon_name()]:contains(skills.weapon_skills[id].en)) then
					debug_message(skills.weapon_skills[id].en.." is filtered out, skipping it.", true)
				else 
					for sc_closer, sc_result in pairs (sc_info[last_skillchain.english].closers) do
						if (T(skills.weapon_skills[id].skillchain):contains(sc_closer)) then
							if (ranged_weaponskills:contains(skills.weapon_skills[id].en)) then
								ws_ranged_options:append({name=skills.weapon_skills[id].en,lvl=sc_result[1]})
							else
								ws_melee_options:append({name=skills.weapon_skills[id].en,lvl=sc_result[1]})
							end
						end
					end
				end
			end
		end
	end

	if (debug) then
		local l = ""
		for k, v in pairs(ws_melee_options) do
			l = l..(k>1 and ", " or "")..v.name..(ranged_weaponskills:contains(v.name) and "-R" or "-M")
		end 
		for k, v in pairs(ws_ranged_options) do
			l = l..(k>1 and ", " or "")..v.name..(ranged_weaponskills:contains(v.name) and "-R" or "-M")
		end 
		debug_message("WSes found: "..(#ws_melee_options + #ws_ranged_options).." "..l)
	end

	if (#ws_melee_options == 0 and #ws_ranged_options == 0) then
		return nil
	elseif (#ws_melee_options == 1 and (#ws_ranged_options == 0 or settings.use_ranged == false)) then
		return ws_melee_options[1]
	elseif (#ws_melee_options == 0 and (#ws_ranged_options == 1 and settings.use_ranged)) then
		return ws_ranged_options[1]
	else 
		local ws_melee, ws_ranged = nil, nil
		local mob = windower.ffxi.get_mob_by_target("t")
		local dist = mob.distance:sqrt() - mob.model_size/2

		-- Check for preferred closing level WSs
		for _, ws in pairs(ws_melee_options) do
			if (ws.lvl == settings.target_sc_level) then
				ws_melee = ws
			end
		end
		for _, ws in pairs(ws_ranged_options) do
			if (ws.lvl == settings.target_sc_level) then
				ws_ranged = ws
			end
		end
		debug_message("Target Melee options: "..tostring(#ws_melee_options).." Melee WS: "..tostring(ws_melee))
		debug_message("Target Ranged options: "..tostring(#ws_ranged_options).." Ranged WS: "..tostring(ws_ranged))
		if (ws_ranged and settings.use_ranged and settings.prefer_ranged) then
			return ws_ranged
		elseif (ws_melee and dist <= 4) then -- Don't waste ammo if we're in melee range and ranged WSs aren't preferred
			return ws_melee
		elseif (ws_ranged and settings.use_ranged) then -- Melee WSs aren't an option, if ranged allowed go for it
			return ws_ranged
		end
		-- No WSs can close at our target level, check other allowed closing levels
		for _, ws in pairs(ws_melee_options) do
			if (settings.close_levels[ws.lvl] == true) then
				if (ws_melee == nil or ws.lvl > ws_melee.lvl) then
					ws_melee = ws
				end
			end
		end
		for _, ws in pairs(ws_ranged_options) do
			if (settings.close_levels[ws.lvl] == true) then
				if (ws_ranged == nil or ws.lvl > ws_ranged.lvl) then
					ws_ranged = ws
				end
			end
		end
		debug_message("Other Melee options: "..tostring(#ws_melee_options).." Melee WS: "..tostring(ws_melee))
		debug_message("Other Ranged options: "..tostring(#ws_ranged_options).." Ranged WS: "..tostring(ws_ranged))
		debug_message("Distance: "..tostring(dist).." is "..(dist>4 and "not " or "").." in melee range")
		debug_message("WS: "..tostring(ws_melee)..": "..tostring(ws_melee and ws_melee.lvl or ""))
		if (ws_ranged and settings.close_levels[ws_ranged.lvl] and settings.use_ranged and settings.prefer_ranged) then
			return ws_ranged
		elseif (ws_melee and settings.close_levels[ws_melee.lvl] and dist <= 4) then -- Don't waste ammo if we're in melee range and ranged WSs aren't preferred
			return ws_melee
		elseif (ws_ranged and settings.close_levels[ws_ranged.lvl] and settings.use_ranged) then -- Melee WSs aren't an option, if ranged allowed go for it
			return ws_ranged
		end
	end
	return nil
end -- get_weaponskill()

function use_weaponskill(ws_name) 
	if (active) then
		--if (windower.ffxi.get_mob_by_target('t').vitals.hpp < settings.max_hp) then return end
		debug_message("Self WS? ".." targets = "..T(res.weapon_skills:with('name', ws_name).targets)[1])
		if (res.weapon_skills:with('name', ws_name).targets and T(res.weapon_skills:with('name', ws_name).targets)[1] == "Self") then
			windower.send_command('input /ws "'..ws_name..'" <me>')
		else
			windower.send_command('input /ws "'..ws_name..'" <t>')
		end
	end
end

function get_weapon_name()
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

	if weapon_name:endswith("+1") or weapon_name:endswith("+2") or weapon_name:endswith("+3") then
		weapon_name = weapon_name:slice(1, -4)
	end
	return weapon_name:lower():split("'"):concat(""):split(" "):concat("_")
end

function open_skillchain()
	player = windower.ffxi.get_player()
	local mob = windower.ffxi.get_mob_by_target("t")
	if (mob == nil or not active or player.status ~= 1 or player.vitals.tp < 1000) then return end
	
	weapon_name = get_weapon_name()

	local job = player.main_job:lower()
	if (settings.sc_openers[job] ~= nil and settings.sc_openers[job][weapon_name] ~= nil) then
		local ws_name = settings.sc_openers[job][weapon_name]
		local ws_range = res.weapon_skills:with('name', ws_name).range*2
		local dist = mob.distance:sqrt()

		-- If this is a self-targeted WS distance doesn't matter
		if (T(res.weapon_skills:with('name', ws_name).targets)[1] == 'Self') then
			dist = 1
		end

		debug_message("Opening SC with "..title_case(ws_name).." Job: "..job:upper().." Weapon: "..title_case(weapon_name))
		ws_range = ws_range + mob.model_size/2 + windower.ffxi.get_mob_by_id(player.id).model_size/2
		if (dist > ws_range) then return end -- Don't throw away TP on out of range mobs

		use_weaponskill(ws_name)
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

	if (sc_opened and ws_window >= settings.max_ws_window) then
		debug_message("Skillchain window expired: "..ws_window)
		skillchain_closed()
		return
	end

	local mob = windower.ffxi.get_mob_by_target("t")
	if (sc_opened and weaponskill_ready() and ws_window > settings.min_ws_window and ws_window < settings.max_ws_window) then
		if (ws_window > sc_effect_duration) then
			debug_message("WS window expired, sc effect wore.")
			skillchain_closed()
			return
		elseif (mob == nil or mob.hpp <= 0) then
			skillchain_closed()
			return
		elseif (last_attempt + settings.attempt_delay > time) then 
			return
		end
		last_attempt = time
		local ws = get_weaponskill()
		if (ws) then
			debug_message("Closer found: "..ws.name)
			use_weaponskill(ws.name)
			return
		else -- There isn't a valid WS to close this chain, we can stop checking by closing wht window
			debug_message("No closer found")
			return
		end
	end

	-- If we can't close a SC then try to open one, if there a SC effect or we opt to ignore SC effects
	if (settings.open_sc and not (sc_opened and settings.wait_to_open)) then
		if (last_attempt + settings.attempt_delay > time) then 
			return
		end
		last_attempt = time
		open_skillchain()
		return
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

		sc_effect_duration = (13-step*3) > 3 and (13-step*3) or 4
		debug_message("Skillchain effect applied: "..skillchain.." L"..level.." Step: "..step)
		if (level >= 4 or (level == 3 and last_skillchain and skillchain == last_skillchain.english)) then -- Level 4 and double light/darkness can't be continued
			skillchain_closed()
			return
		end
		local m = windower.ffxi.get_mob_by_target("t")
		if (m and m.id == target.id) then
			skillchain_opened(skillchains:with('english', skillchain))
		end
	elseif ability and (message_ids:contains(message_id) or message_id == 2 and buffs[actor] and chain_buff(buffs[actor])) then
		sc_effect_duration = 12
		debug_message("Base SC effect applied to "..target.id.." Used: "..skills[resource][action_id].en.." Eff: "..T(skills[resource][action_id].skillchain):concat(", "))
		local m = windower.ffxi.get_mob_by_target("t")
		if (m and m.id == target.id) then
			local s = T{english="Base",lvl=0,elements=T{},chains=T(skills[resource][action_id].skillchain)}
			skillchain_opened(s)
		end
    end
end

ActionPacket.open_listener(action_handler)

-- Reload settings on login
windower.register_event('login', function(...)
	if (active) then
		windower.send_command('autoSC off')
	end
	player = nil
	windower.send_command("wait 5; autosc reload")
	return
end)

windower.register_event('logout', 'zone change', 'job change', function(...)
	if (active) then
		windower.send_command('autoSC off')
	end
	player = nil
	return
end)

windower.register_event('load', 'reload', function(...)
	init_display()
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
	elseif (cmd == 'status') then
		show_status()
		return
	elseif (cmd == 'on') then
		message("Starting")
		player = windower.ffxi.get_player()
		active = true
		last_check_time = os.clock()
    elseif (cmd == 'off') then
		message("Stopping")
        active = false
	elseif (cmd == 'hide') then
		display:hide()
		return
	elseif (cmd == 'show') then
		display:show()
	elseif (cmd == 'open') then
		settings.open_sc = not settings.open_sc
		message("Will "..(settings.open_sc and "" or "not ").."open new SCs")
		settings:save('all')
	elseif (cmd == 'honor' or cmd == 'wait') then
		settings.wait_to_open = not settings.wait_to_open
		message("Will "..(settings.wait_to_open and "" or "not ").." wait for existing SC effect to wear off before opening new SC.")
		settings:save('all')
	elseif (cmd == 'ws') then
		if (#arg < 2) then
			message("Usage: autoSC WS weaponskill name")
			return
		end

		local job = player.main_job:lower()
		settings.sc_openers[job] = settings.sc_openers[job] or {}

		ws_name = title_case(T(arg):slice(2, #arg):concat(" "))
		
		if (ws_name == "Chant Du Cygne") then
			ws_name = "Chant du Cygne"
		end
		if (res.weapon_skills:with('name', ws_name) == nil) then
			message("No weaponskill with name: "..ws_name.." found. SC opener not added.")
			return
		end

		local weapon_name = get_weapon_name()
		settings.sc_openers[job][weapon_name] = ws_name
		message("SC Opener for "..tostring(job:upper()).." using "..title_case(weapon_name):split("_"):concat(" ").." set to "..tostring(settings.sc_openers[job][weapon_name]))
		settings:save('all')
	elseif (cmd == 'filter' or cmd == 'filt') then
		if (#arg < 2) then
			message("Usage: autoSC filter <weaponskill>\nAdds/Removes named weaponskill from filter list.")
			return
		end

		local weapon = get_weapon_name()
		settings.ws_filters[weapon] = settings.ws_filters[weapon] or {}

		local ws_name = title_case(T(arg):slice(2, #arg):concat(" "))
		
		if (ws_name == "Chant Du Cygne") then
			ws_name = "Chant du Cygne"
		end
		if (res.weapon_skills:with('name', ws_name) == nil) then
			message("No weaponskill with name: "..ws_name.." found. WS filter not added/removed.")
			return
		end

		if (settings.ws_filters and settings.ws_filters[weapon] and T(settings.ws_filters[weapon]):contains(ws_name)) then
			message("WS "..ws_name.." removed from filtered WSs for "..title_case(weapon):split("_"):concat(" ")..".")
			settings.ws_filters[weapon]:delete(ws_name)
		else
			message("WS "..ws_name.." added to filtered WSs for "..title_case(weapon):split("_"):concat(" ")..".")
			T(settings.ws_filters[weapon]):append(ws_name) 
		end

		settings:save('all')
		update_display()
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
		settings:save('all')
	elseif (cmd == 'minwin') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			message("Usage: autoSC minwin #")
			return
		end
		settings.min_ws_window = n
		settings:save('all')
	elseif (cmd == 'maxwin') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			message("Usage: autoSC maxwin #")
			return
		end
		settings.max_ws_window = n
		settings:save('all')
	elseif (cmd == 'retry') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			message("Usage: autoSC retry # Where # is the number of seconds between attempts to use a WS")
			return
		end
		settings.attempt_delay = n
		settings:save('all')
	elseif (cmd == 'frequency' or cmd == 'f') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			message("Usage: autoSC (f)requency #")
			return
		end
		settings.update_frequency = n
		settings:save('all')
	elseif (cmd == 'level' or cmd == 'l') then
		local n = tonumber(arg[2])
		if (n == nil or n < 0) then
			message("Usage: autoSC (l)evel # Where # is a number between 1 and 4")
			return
		end
		settings.target_sc_level = n
		settings:save('all')
	elseif (cmd == 'close' or cmd == 'c') then
		local n = tonumber(arg[2])
		if (n == nil or n < 1 or n > 4) then
			message("Usage: autoSC (c)lose # Where # is the SC level to close 1..4")
			return
		end
		settings.close_levels[n] = not settings.close_levels[n]
		settings:save('all')
		message("Will "..(settings.close_levels[n] and "now " or "not ").."close skillchains of level "..n)
	elseif (cmd == 'ranged' or cmd == 'r') then
		settings.use_ranged = not settings.use_ranged
		message("Ranged WS "..(settings.use_ranged and "On" or "Off"))
		settings:save('all')
	elseif (cmd == 'preferranged' or cmd == 'pr') then
		settings.prefer_ranged = not settings.prefer_ranged
		message("Prefer Ranged WS "..(settings.prefer_ranged and "On" or "Off"))
		settings:save('all')
	elseif (cmd == 'reload') then
		player = windower.ffxi.get_player()
		settings = config.load("data/"..player.name..".xml", defaults)
	elseif (cmd == 'debug') then
		debug = not debug
		message("Will"..(debug and ' ' or ' not ').."show debug information")
		return
    end
	update_display()
end) -- Addon Command
