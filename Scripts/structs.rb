#==============================================================================
# ** Structs
#------------------------------------------------------------------------------
#  Este script lida com as estruturas.
#------------------------------------------------------------------------------
#  Autor: Valentine
#==============================================================================

Hotbar = Struct.new(
	:type,
	:item_id
)

Target = Struct.new(
	:type,
	:id
)

Region = Struct.new(
	:x,
	:y
)

IP_Blocked = Struct.new(
	:attempts,
	:time
)

Drop = Struct.new(
	:item_id,
	:kind,
	:amount,
	:name,
	:party_id,
	:x,
	:y,
	:despawn_time,
	:pick_up_time
)

Reward = Struct.new(
	:item_id,
	:item_kind,
	:item_amount,
	:exp,
	:gold
)

Guild = Struct.new(
	:leader,
	:flag,
	:members,
	:notice
)

Account = Struct.new(
	:pass,
	:email,
	:group,
	:vip_time,
	:actors,
	:friends
)

Actor = Struct.new(
	:name,
	:character_name,
	:character_index,
	:face_name,
	:face_index,
	:class_id,
	:sex,
	:level,
	:exp,
	:hp,
	:mp,
	:param_base,
	:equips,
	:points,
	:guild,
	:revive_map_id,
	:revive_x,
	:revive_y,
	:map_id,
	:x,
	:y,
	:direction,
	:gold,
	:items,
	:weapons,
	:armors,
	:skills,
	:quests,
	:hotbar,
	:switches,
	:variables,
	:self_switches
)
