#==============================================================================
# ** Game_Character
#------------------------------------------------------------------------------
#  Esta é a superclasse de Game_Client e Game_Event.
#------------------------------------------------------------------------------
#  Autor: Valentine
#==============================================================================

module Game_Character

	FEATURE_ELEMENT_RATE  = 11
	FEATURE_PARAM         = 21
	FEATURE_XPARAM        = 22
	FEATURE_SPARAM        = 23
	FEATURE_ATK_ELEMENT   = 31
	FEATURE_STYPE_SEAL    = 42
	FEATURE_SKILL_SEAL    = 44
	FEATURE_EQUIP_WTYPE   = 51
	FEATURE_EQUIP_ATYPE   = 52
	FEATURE_EQUIP_SEAL    = 54
	FEATURE_SPECIAL_FLAG  = 62
	FEATURE_PARTY_ABILITY = 64

	FLAG_ID_GUARD = 1

	# Evita um erro no make_damage_value quando o inimigo ataca e permite
	#a leitura das variáveis do jogador
	attr_reader   :variables
	attr_accessor :direction

	def mhp; param(0);  end
	def mmp; param(1);  end
	def atk; param(2);  end
	def def; param(3);  end
	def mat; param(4);  end
	def mdf; param(5);  end
	def agi; param(6);  end
	def luk; param(7);  end
	def hit; xparam(0); end
	def eva; xparam(1); end
	def cri; xparam(2); end
	def cev; xparam(3); end
	def mev; xparam(4); end
	def grd; sparam(1); end
	def rec; sparam(2); end
	def pha; sparam(3); end
  def pdr; sparam(6); end
  def mdr; sparam(7); end

  def clear_states
		@states = []
	end

  def clear_buffs
    @buffs = Array.new(8, 0)
  end

  def state?(state_id)
    @states.include?(state_id)
  end

  def states
    @states.collect { |id| $data_states[id] }
  end

  def all_features
    feature_objects.inject([]) { |r, obj| r + obj.features }
  end

  def features(code)
    all_features.select { |ft| ft.code == code }
	end
	
  def features_with_id(code, id)
    all_features.select { |ft| ft.code == code && ft.data_id == id }
  end

  def features_pi(code, id)
    features_with_id(code, id).inject(1.0) { |r, ft| r *= ft.value }
	end
	
  def features_sum(code, id)
    features_with_id(code, id).inject(0.0) { |r, ft| r += ft.value }
  end

  def features_set(code)
    features(code).inject([]) { |r, ft| r |= [ft.data_id] }
	end

	def add_param(param_id, value)
		@param_base[param_id] += value
	end

	def param_plus(param_id)
		0
	end

	def param_min(param_id)
		param_id == Constants::PARAM_MAXMP ? 0 : 1
	end

  def param_rate(param_id)
    features_pi(FEATURE_PARAM, param_id)
	end
	
  def param_buff_rate(param_id)
    @buffs[param_id] * 0.25 + 1.0
  end

	def param(param_id)
		value = @param_base[param_id] + param_plus(param_id)
		value *= param_rate(param_id) * param_buff_rate(param_id)
		[[value, Configs::MAX_PARAMS].min, param_min(param_id)].max.to_i
	end

  def xparam(xparam_id)
    features_sum(FEATURE_XPARAM, xparam_id)
  end

  def sparam(sparam_id)
    features_pi(FEATURE_SPARAM, sparam_id)
	end
	
  def element_rate(element_id)
    features_pi(FEATURE_ELEMENT_RATE, element_id)
	end
	
  def atk_elements
    features_set(FEATURE_ATK_ELEMENT)
  end

  def skill_type_sealed?(stype_id)
    features_set(FEATURE_STYPE_SEAL).include?(stype_id)
  end

  def skill_sealed?(skill_id)
    features_set(FEATURE_SKILL_SEAL).include?(skill_id)
  end

  def special_flag(flag_id)
    features(FEATURE_SPECIAL_FLAG).any? { |ft| ft.data_id == flag_id }
	end

  def party_ability(ability_id)
    features(FEATURE_PARTY_ABILITY).any? { |ft| ft.data_id == ability_id }
  end
	
  def guard?
    special_flag(FLAG_ID_GUARD) && movable?
  end

	def hp=(hp)
		@hp = [[hp, mhp].min, 0].max
		# Se o inimigo morreu
		die if dead?
	end

	def mp=(mp)
		@mp = [[mp, mmp].min, 0].max
	end

	def hp_rate
		@hp.to_f / mhp
	end

	def mp_rate
		mmp > 0 ? @mp.to_f / mmp : 0
	end

	def movable?
		# Se o evento não pode agir
		restriction < 4
	end

	def refresh
		@hp = [[@hp, mhp].min, 0].max
		@mp = [[@mp, mmp].min, 0].max
	end

	def dead?
		@hp <= 0
	end

	def pos?(x, y)
		@x == x && @y == y
	end

	def pos_nt?(x, y)
		pos?(x, y) && !@through
	end

	def normal_priority?
		@priority_type == 1
	end

	def reverse_dir(d)
		10 - d
	end

	def passable?(x, y, d)
		x2 = $server.maps[@map_id].round_x_with_direction(x, d)
		y2 = $server.maps[@map_id].round_y_with_direction(y, d)
		return false unless $server.maps[@map_id].valid?(x2, y2)
		return true if @through
		return false unless $server.maps[@map_id].passable?(x2, y2, reverse_dir(d))
		return false if collide_with_characters?(x2, y2)
		return true
	end

  def diagonal_passable?(x, y, horz, vert)
    x2 = $server.maps[@map_id].round_x_with_direction(x, horz)
    y2 = $server.maps[@map_id].round_y_with_direction(y, vert)
    (passable?(x, y, vert) && passable?(x, y2, horz)) ||
    (passable?(x, y, horz) && passable?(x2, y, vert))
  end
	
	def collide_with_characters?(x, y)
		collide_with_events?(x, y)
	end

	def collide_with_events?(x, y)
		$server.maps[@map_id].events_xy_nt(x, y).any? { |event| event.normal_priority? && !event.erased? }
	end

	def collide_with_players?(x, y)
		$server.clients.any? { |client| client&.in_game? && client.map_id == @map_id && client.pos_nt?(x, y) }
	end

	def moveto(x, y)
		@x = x
		@y = y
		send_movement
	end

	def tile?
		@tile_id > 0 && @priority_type == 0
	end

	def check_event_trigger_touch_front
		x2 = $server.maps[@map_id].round_x_with_direction(@x, @direction)
		y2 = $server.maps[@map_id].round_y_with_direction(@y, @direction)
		check_event_trigger_touch(x2, y2)
	end

	def move_straight(d, turn_ok = true)
		@move_succeed = passable?(@x, @y, d)
		if @move_succeed
			@direction = d
			@x = $server.maps[@map_id].round_x_with_direction(@x, d)
			@y = $server.maps[@map_id].round_y_with_direction(@y, d)
			send_movement
		elsif turn_ok
			@direction = d
			send_movement
			check_event_trigger_touch_front
		end
	end

  def move_diagonal(horz, vert)
    @move_succeed = diagonal_passable?(x, y, horz, vert)
    if @move_succeed
      @x = $server.maps[@map_id].round_x_with_direction(@x, horz)
      @y = $server.maps[@map_id].round_y_with_direction(@y, vert)
    end
    @direction = horz if @direction == reverse_dir(horz)
		@direction = vert if @direction == reverse_dir(vert)
		send_movement
  end
	
	def restriction
		states.collect { |state| state.restriction }.push(0).max
	end

	def skill_learn?(skill_id)
		true
	end

	def skill_wtype_ok?(skill)
		true
	end

	def usable_item_conditions_met?(item)
		movable? && item.occasion < 3
	end

	def skill_conditions_met?(skill)
		skill_learn?(skill.id) && usable_item_conditions_met?(skill) && mp >= skill.mp_cost &&
		skill_wtype_ok?(skill) && !skill_sealed?(skill.id) && !skill_type_sealed?(skill.stype_id)
	end

	def item_conditions_met?(item)
		usable_item_conditions_met?(item) && has_item?(item)
	end

	def usable?(item)
		return skill_conditions_met?(item) if item.is_a?(RPG::Skill)
		return item_conditions_met?(item) if item.is_a?(RPG::Item)
		return false
	end

	def attack_skill_id
		1
	end

	def guard_skill_id
		2
	end

  def distance_x_from(x)
    @x - x
  end

  def distance_y_from(y)
    @y - y
	end

	def swap(character)
		new_x = character.x
		new_y = character.y
		character.moveto(@x, @y)
		moveto(new_x, new_y)
	end

end
