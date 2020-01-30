#==============================================================================
# ** Game_Client
#------------------------------------------------------------------------------
#  Esta classe lida com o jogador.
#------------------------------------------------------------------------------
#  Autor: Valentine
#==============================================================================

class Game_Client < EventMachine::Connection

	include Game_Account, Game_Character, Game_Battler, Game_Party, Game_Trade, Game_Bank

  ABILITY_GOLD_DOUBLE      = 4
  ABILITY_DROP_ITEM_DOUBLE = 5

	attr_reader   :name
	attr_reader   :character_name
	attr_reader   :character_index
	attr_reader   :face_name
	attr_reader   :face_index
	attr_reader   :class_id
	attr_reader   :sex
	attr_reader   :level
	attr_reader   :exp
	attr_reader   :hp
	attr_reader   :mp
	attr_reader   :param_base
	attr_reader   :equips
	attr_reader   :points
	attr_reader   :revive_map_id
	attr_reader   :revive_x
	attr_reader   :revive_y
	attr_reader   :map_id
	attr_reader   :x
	attr_reader   :y
	attr_reader   :gold
	attr_reader   :skills
	attr_reader   :hotbar
	attr_reader   :switches
	attr_reader   :self_switches
	attr_reader   :shop_goods
	attr_reader   :target
	attr_reader   :request
	attr_reader   :quests
	attr_reader   :party_id
	attr_reader   :teleport_id
	attr_reader   :move_succeed
	attr_writer   :muted_time
	attr_writer   :stop_count
	attr_writer   :antispam_time
	attr_writer   :global_antispam_time
	attr_accessor :guild

	def initialize
		@through = false
		@target = Target.new
		@request = Target.new
		@interpreter = Game_Interpreter.new
		@move_route_forcing = false
		# Define name para evitar problemas na busca de
		#jogador por nome
		@name = ''
		init_account
		init_trade
		init_bank
	end

	def in_shop?
		@shop_goods
	end

	def in_trade?
		@trade_player_id >= 0
	end

	def in_teleport?
		@teleport_id >= 0
	end

	def in_guild?
		!@guild.empty?
	end

	def in_party?
		@party_id >= 0
	end

	def in_bank?
		@in_bank
	end

	def guild_leader?
		$server.guilds[@guild].leader == @name
	end

	def choosing?
		@choices
	end

	def creating_guild?
		@creating_guild
	end

	def has_weapon?
		weapon_id > 0
	end

	def spawning?
		@antispam_time > Time.now
	end

	def global_chat_spawning?
		@global_antispam_time > Time.now
	end

	def moving?
		@stop_count > Time.now
	end

	def attacking?
		@weapon_attack_time > Time.now
	end

	def using_item?
		@item_attack_time > Time.now
	end

	def muted?
		@muted_time > Time.now
	end

	def quest_in_progress?(quest_id)
		# Reduz o índice que foi configurado com um inteiro a mais
		#nos comandos de evento
		@quests[quest_id - 1]&.in_progress?
	end

	def quest_finished?(quest_id)
		@quests[quest_id - 1]&.finished?
	end

	def weapon_id
		@equips[Constants::EQUIP_WEAPON]
	end

	def shield_id
		@equips[Constants::EQUIP_SHIELD]
	end

	def vip_exp_bonus
		vip? ? VIP_EXP_BONUS : 1
	end

	def vip_gold_bonus
		vip? ? VIP_GOLD_BONUS : 1
	end

	def vip_drop_bonus
		vip? ? VIP_DROP_BONUS : 1
	end

	def vip_recover_bonus
		vip? ? VIP_RECOVER_BONUS : 1
	end

	def lose_exp_rate
		vip? ? LOSE_VIP_EXP_RATE : LOSE_DEFAULT_EXP_RATE
	end

  def feature_objects
    states + [$data_actors[@class_id]] + [$data_classes[@class_id]] + equips_objects.compact
  end

	def clear_request
		@request.id = -1
		@request.type = Constants::REQUEST_NONE
	end

	def collide_with_characters?(x, y)
		super || collide_with_players?(x, y) && $server.maps[@map_id].pvp
	end

	def transfer(map_id, x, y, direction)
		# Reseta o contador para evitar que o passo extra dado pelo jogador ao encostar
		#no teletransporte não seja considerado speed hack
		@stop_count = Time.now
		close_windows
		if @map_id == map_id
			change_position(x, y, direction)
			$server.send_player_movement(self)
		else
			change_map(map_id, x, y, direction)
		end
	end

	def change_map(map_id, x, y, direction)
		old_map_id = @map_id
		change_position(x, y, direction)
		$server.send_player_data(self, map_id)
		@map_id = map_id
		$server.send_remove_player(@id, old_map_id)
		$server.send_transfer_player(self)
		$server.send_map_players(self)
		$server.send_map_events(self)
		$server.send_map_drops(self)
		$server.maps[old_map_id].total_players -= 1
		$server.maps[@map_id].total_players += 1
		clear_target_players(Constants::TARGET_PLAYER, old_map_id)
		clear_target
		clear_request
	end

	def change_position(x, y, direction)
		@x = x
		@y = y
		@direction = direction
	end

	def check_point(map_id, x, y)
		@revive_map_id = map_id
		@revive_x = x
		@revive_y = y
	end

	def hp=(hp)
		@hp = [[hp, mhp].min, 0].max
		dead? ? die : $server.send_player_vitals(self)
	end

	def mp=(mp)
		super
		$server.send_player_vitals(self)
	end

	def recover_all
		clear_states
		change_vitals(mhp, mmp)
	end

	def change_vitals(hp, mp)
		@hp = [[hp, mhp].min, 0].max
		@mp = [[mp, mmp].min, 0].max
		$server.send_player_vitals(self)
	end

	def close_windows
		close_shop
		close_choices
		close_trade
		close_bank
		close_teleport
		close_create_guild
	end

	def exp_for_level(level)
		$data_classes[@class_id].exp_for_level(level)
	end

	def current_level_exp
		exp_for_level(@level)
	end

	def next_level_exp
		exp_for_level(@level + 1)
	end

	def max_level?
		@level >= Configs::MAX_LEVEL
	end

	def equips_objects
		[$data_weapons[weapon_id]] + @equips[1, 8].collect { |item_id| equip_object(1, item_id) }
  end

	def item_container(item_class)
		return @items if item_class == RPG::Item
		return @weapons if item_class == RPG::Weapon
		return @armors if item_class == RPG::Armor
		return nil
	end

	def item_object(kind, item_id)
		return $data_items[item_id] if kind == 1
		return $data_weapons[item_id] if kind == 2
		return $data_armors[item_id] if kind == 3
		return nil
	end

	def kind_item(item)
		return 1 if item.class == RPG::Item
		return 2 if item.class == RPG::Weapon
		return 3 if item.class == RPG::Armor
	end

	def equip_object(slot_id, item_id)
		slot_id == Constants::EQUIP_WEAPON ? $data_weapons[item_id] : $data_armors[item_id]
	end

	def item_number(item)
		container = item_container(item.class)
		# Se é um item, arma ou armadura que está no inventário
		container ? container[item.id] || 0 : 0
	end

	def full_inventory?(item)
		size = @items.size + @weapons.size + @armors.size
		if size == Configs::MAX_PLAYER_ITEMS && !has_item?(item)
			# Se o jogador estiver tentando pegando drop ou item por comando de evento
			$server.alert_message(self, Constants::ALERT_FULL_INV)
			return true
		end
		return false
	end

	def change_equip(slot_id, item_id)
		return unless trade_item_with_party(equip_object(slot_id, item_id), equip_object(slot_id, @equips[slot_id]), slot_id)
		@equips[slot_id] = item_id
		$server.send_player_equip(self, slot_id)
		# Se o equipamento que aumentava HP e/ou MP máximo foi removido
		refresh
	end

	def trade_item_with_party(new_item, old_item, slot_id)
		return false if !new_item && full_inventory?(old_item)
		return false if new_item && !equippable?(new_item, slot_id)
		gain_item(old_item, 1)
		lose_item(new_item, 1)
		lose_trade_item(new_item, 1) if new_item && in_trade?
		return true
	end

	def equippable?(item, slot_id)
		return false unless has_item?(item)
		return false unless item.etype_id == slot_id
		return false if item.level > @level
		return false if item.vip? && !vip?
		return false if has_seal_equip?(item)
		return false if features_set(FEATURE_EQUIP_SEAL).include?(item.etype_id)
		return features_set(FEATURE_EQUIP_WTYPE).include?(item.wtype_id) if item.is_a?(RPG::Weapon)
		return features_set(FEATURE_EQUIP_ATYPE).include?(item.atype_id) if item.is_a?(RPG::Armor)
		return false
	end

  def has_seal_equip?(item)
		item.features.any? { |feature| feature.code == FEATURE_EQUIP_SEAL && equips_objects.compact.any? { |equip| equip.etype_id == feature.data_id } }
  end
	
	def skill_wtype_ok?(skill)
		wtype_id1 = skill.required_wtype_id1
		#wtype_id2 = skill.required_wtype_id2
		return true if wtype_id1 == 0 #&& wtype_id2 == 0
		return true if wtype_id1 > 0 && wtype_equipped?(wtype_id1)
		#return true if wtype_id2 > 0 && wtype_equipped?(wtype_id2)
		return false
	end

	def wtype_equipped?(wtype_id)
		$data_weapons[weapon_id].wtype_id == wtype_id#weapons.any? { |weapon| weapon.wtype_id == wtype_id }
	end

	def add_param(param_id, value)
		super
		$server.send_player_param(self, param_id, value)
	end

	def param_plus(param_id)
		value = 0
		@equips.each_with_index { |item_id, slot_id| value += equip_object(slot_id, item_id).params[param_id] if item_id > 0 }
		value
	end

	def reset_parameters
		@param_base.each_index do |param_id|
			value = $data_classes[@class_id].params[param_id, 1]
			# Subtrai o parâmetro atual
			$server.send_player_param(self, param_id, value - @param_base[param_id])
			@param_base[param_id] = value
		end
		self.points = Configs::START_POINTS + @level * LEVEL_UP_POINTS - LEVEL_UP_POINTS
		# Se diminuiu o HP ou MP máximo
		refresh
	end
	
	def change_target(target_id, type)
		return if @target.id == target_id && @target.type = type
		@target.id = target_id
		@target.type = type
		$server.send_target(self)
	end

	def change_hotbar(id, type, item_id)
		@hotbar[id].type = type
		@hotbar[id].item_id = item_id
		$server.send_change_hotbar(self, id)
	end

	def change_exp(exp)
		return if @level == Configs::MAX_LEVEL && exp > @exp
		$server.send_player_exp(self, exp - @exp)
		@exp = [[exp, exp_for_level(Configs::MAX_LEVEL)].min, 0].max
		level_up while !max_level? && @exp >= next_level_exp
		level_down while @exp < current_level_exp
	end

	def level_up
		@level += 1
		#$server.global_message("#{@name} #{LevelUp}", Configs::ALERT_COLOR)
		$server.player_message(self, LevelUp, Configs::ALERT_COLOR)
		$data_classes[@class_id].learnings.each { |learning| learn_skill(learning.skill_id) if learning.level == @level }
		self.points += LEVEL_UP_POINTS
		recover_all
	end

	def level_down
		@level -= 1
		self.points -= LEVEL_UP_POINTS
	end

	def points=(points)
		@points = points
		$server.send_player_points(self, points)
	end

	def skill_learn?(skill_id)
		@skills.include?(skill_id)
	end

	def change_class(class_id)
		@class_id = class_id
		$server.send_player_class(self, class_id)
	end

	def change_sex
		@sex = @sex == Constants::SEX_MALE ? Constants::SEX_FEMALE : Constants::SEX_MALE
	end

	def set_graphic(character_name, character_index, face_name, face_index)
		@character_name = character_name
		@character_index = character_index
		@face_name = face_name
		@face_index = face_index
		$server.send_player_graphic(self)
	end
	
	def gain_exp(exp)
		change_exp(@exp + exp)
	end

	def lose_exp(exp)
		gain_exp(-exp)
		$server.player_message(self, sprintf(LoseExp, exp.to_s.reverse.scan(/...|..|./).join('.').reverse), Configs::ERROR_COLOR)
	end

	def change_level(level)
		level = [[level, Configs::MAX_LEVEL].min, 1].max
		change_exp(exp_for_level(level))
	end

	def gain_gold(amount, shop_sound = false, popup = false)
		return if amount == 0
		@gold = [[@gold + amount, 0].max, Configs::MAX_GOLD].min
		$server.send_player_gold(self, amount, shop_sound, popup)
	end

	def lose_gold(amount, shop_sound = false)
		gain_gold(-amount, shop_sound)
	end

	def has_item?(item, include_equip = false)
		return true if item_number(item) > 0
		include_equip ? @equips.include?(item.id) : false
	end

	def gain_item(item, amount, drop_sound = false, popup = false)
		container = item_container(item.class)
		return unless container
		container[item.id] = [[item_number(item) + amount].max, Configs::MAX_ITEMS].min
		container.delete(item.id) if container[item.id] == 0
		$server.send_player_item(self, item.id, kind_item(item), amount, drop_sound, popup)
		add_itens_count(item)
	end

	def lose_item(item, amount)
		gain_item(item, -amount)
	end

	def learn_skill(skill_id)
		return if skill_learn?(skill_id)
		@skills << skill_id
		@skills.sort!
		$server.send_player_skill(self, skill_id)
		$server.player_message(self, "#{LearnedSkill} #{$data_skills[skill_id].name}.", Configs::SUCCESS_COLOR)
	end

  def drop_item_rate
    party_ability(ABILITY_DROP_ITEM_DOUBLE) ? 2 : 1
  end

  def gold_rate
    party_ability(ABILITY_GOLD_DOUBLE) ? 2 : 1
  end

	def change_switch(switch_id, value)
		@switches[switch_id] = value
		$server.send_player_switch(self, switch_id)
		#check_completed_quests
	end

	def change_variable(variable_id, value)
		@variables[variable_id] = value
		$server.send_player_variable(self, variable_id)
	end

	def change_self_switches(key, value)
		@self_switches[key] = value
		$server.send_player_self_switch(self, key)
	end

	def open_shop(shop_goods, event_id, index)
		@shop_goods = shop_goods
		$server.send_open_shop(self, event_id, index)
	end

	def close_shop
		return unless in_shop?
		@shop_goods = nil
		$server.send_close_window(self)
	end

	def open_teleport(teleport_id)
		@teleport_id = teleport_id
		$server.send_open_teleport(self, teleport_id)
	end

	def close_teleport
		return unless in_teleport?
		@teleport_id = -1
		$server.send_close_window(self)
	end
	
	def show_choices(list, event_id, index)
		@choices = list
		$server.send_show_choices(self, event_id, index)
	end

	def close_choices
		return unless choosing?
		@choices = nil
	end

	def open_create_guild
		return if creating_guild?
		if in_guild?
			$server.alert_message(self, Constants::ALERT_IN_GUILD)
			return
		end
		@creating_guild = true
		$server.send_open_create_guild(self)
	end

	def close_create_guild
		return unless creating_guild?
		@creating_guild = false
		$server.send_close_window(self)
	end

	def accept_guild
		return if in_guild?
		return unless $server.clients[@request.id]&.in_game?
		return unless $server.guilds.has_key?($server.clients[@request.id].guild)
		# Impede que a guilda do líder seja alterada se,
		#posteriormente, o novo membro sair dela
		@guild = $server.clients[@request.id].guild.clone
		$server.guild_message(self, "#{@name} #{JoinGuild} #{$server.clients[@request.id].guild}.", Configs::SUCCESS_COLOR)
		# Impede que o nome do membro da lista de membros seja
		#alterado quando @name dele ficar vazia no leave_game
		$server.guilds[@guild].members << @name.clone
		$server.save_guild(@guild)
		$server.send_update_guild(self)
	end

	def leave_guild
		$server.guild_message(self, "#{@name} #{LeaveGuild} #{@guild}.", Configs::ERROR_COLOR)
		$server.guilds[@guild].members.delete(@name)
		$server.save_guild(@guild)
		@guild.clear
		$server.send_update_guild(self)
	end

	def start_quest(quest_id)
		return if @quests.has_key?(quest_id)
		@quests[quest_id] = Game_Quest.new(quest_id, Constants::QUEST_IN_PROGRESS, 0)
		$server.send_new_quest(self, quest_id)
    # Verifica se já completou as únicas condições de itens e/ou switche exigidas
    #check_completed_quests
	end

	def check_completed_quests
		@quests.each do |quest_id, quest|
			next if quest.finished?
			next if quest.switch_id > 0 && !@switches[quest.switch_id]
			item = item_object(quest.item_kind, quest.item_id)
			next if item && item_number(item) < quest.item_amount
			next if quest.kills < quest.max_kills
			finish_quest(quest_id)
		end
	end

	def add_kills_count(enemy_id)
		@quests.each_value do |quest|
			next unless quest.in_progress?
			next unless quest.enemy_id == enemy_id
			next if quest.kills == quest.max_kills
			quest.kills += 1
			$server.player_message(self, "#{Killed} #{quest.kills}/#{quest.max_kills} #{$data_enemies[enemy_id].name}.", Configs::SUCCESS_COLOR)
			break
		end
		#check_completed_quests
	end

	def add_itens_count(item)
		@quests.each_value do |quest|
			next unless quest.in_progress?
			next unless quest.item_id == item.id
			next if item_number(item) > quest.item_amount
			$server.player_message(self, "#{Have} #{item_number(item)}/#{quest.item_amount} #{item.name}.", Configs::SUCCESS_COLOR)
			break
		end
		#check_completed_quests
	end

	def finish_quest(quest_id)
		@quests[quest_id].state = Constants::QUEST_FINISHED
		item = item_object(@quests[quest_id].item_kind, @quests[quest_id].item_id)
		lose_item(item, @quests[quest_id].item_amount)
		# Se o jogador colocou o item na troca para não perdê-lo
		lose_trade_item(item, @quests[quest_id].item_amount) if in_trade?
		item = item_object(@quests[quest_id].reward.item_kind, @quests[quest_id].reward.item_id)
		gain_gold(@quests[quest_id].reward.gold, false, true)
		gain_item(item, @quests[quest_id].reward.item_amount, false, true) unless full_inventory?(item)
		gain_exp(@quests[quest_id].reward.exp)
		@quests.delete(quest_id) if @quests[quest_id].repeat?
		$server.send_finish_quest(self, quest_id)
	end

	def send_movement
		$server.send_player_movement(self)
	end

	def start_map_event(x, y, triggers, normal)
		$server.maps[@map_id].events_xy(x, y).each do |event|
			event.start(self) if event.trigger_in?(triggers) && event.normal_priority? == normal
		end
	end

	def check_event_trigger_here(triggers)
		start_map_event(@x, @y, triggers, false)
	end

	def check_event_trigger_there(triggers)
		x2 = $server.maps[@map_id].round_x_with_direction(@x, @direction)
		y2 = $server.maps[@map_id].round_y_with_direction(@y, @direction)
		start_map_event(x2, y2, triggers, true)
		#return if $server.maps[@map_id].any_event_starting?
		#return unless $server.maps[@map_id].counter?(x2, y2)
		#x3 = $server.maps[@map_id].round_x_with_direction(x2, @direction)
		#y3 = $server.maps[@map_id].round_y_with_direction(y2, @direction)
		#start_map_event(x3, y3, triggers, true)
	end

	def check_event_trigger_touch(x, y)
		start_map_event(x, y, [1, 2], true)
	end

	def check_touch_event
		check_event_trigger_here([1, 2])
	end

	def movable?
		!@move_route_forcing
	end

	def update_game
		recover_vital
		update_common_events
	end

	def recover_vital
		return if @recover_time > Time.now
		@recover_time = Time.now + RECOVER_TIME
		if @hp < mhp || @mp < mmp
			n = (agi / 100).next
			change_vitals((@hp + RECOVER_HP * vip_recover_bonus * n).to_i, (@mp + RECOVER_MP * vip_recover_bonus * n).to_i)
		end
	end

	def update_common_events
		$parallel_common_events.each do |common_event|
			@interpreter.setup(self, common_event.list) if common_event.switch_id == 0 || @switches[common_event.switch_id]
		end
	end

end
