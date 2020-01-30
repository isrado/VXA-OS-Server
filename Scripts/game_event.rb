#==============================================================================
# ** Game_Event
#------------------------------------------------------------------------------
#  Esta classe lida com o evento.
#------------------------------------------------------------------------------
#  Autor: Valentine
#==============================================================================

class Game_Event

	include Game_Character, Game_Battler, Game_Enemy

	attr_reader   :id
	attr_reader   :hp
	# Permite a alteração de self.mp, nos casos em que seu valor seja acrescido ou
	#diminuído, a partir da leitura do valor original de mp
	attr_reader   :mp
	attr_reader   :target
	attr_reader   :tile_id
	attr_reader   :direction
	attr_accessor :x
	attr_accessor :y
	attr_accessor :map_id
	
	def initialize(id, pages)
		@id = id
		@pages = pages
		@target = Target.new
		@move_succeed = true
		@interpreter = Game_Interpreter.new
		@move_route_forcing = false
		clear_enemy
		clear_target
		clear_states
		clear_buffs
		refresh
	end

	def enemy?
		@enemy_id > 0
	end

	def in_battle?
		@target.id >= 0
	end
	
	def erased?
		enemy? && dead?
	end

	def enemy
		$data_enemies[@enemy_id]
	end

	def clear_enemy
		@action_time = Time.now + Configs::ATTACK_TIME
		@respawn_time = Time.now
		@escape = false
		@hp = 0
		@sight = 10
	end

	def refresh
		new_page = find_global_proper_page
		# Executa o clear_page_settings se não tiver página e a atualização
		#estiver ocorrendo ao instânciar a classe
		setup_page(new_page) if !new_page || new_page != @page
		@stop_count = Time.now + rand(@stop_count_threshold)
	end

	def setup_page(new_page)
		@page = new_page
		if @page
			setup_page_settings
		else
			clear_page_settings
		end
	end

	def clear_page_settings
		@tile_id = 0
		@direction = Constants::DIR_DOWN
		@move_type = 0
		@move_frequency = 3
		@through = true
		@trigger = nil
		@list = nil
		#@interpreter = nil
		@enemy_id = 0
		@stop_count_threshold = 1
		clear_enemy
		clear_target
	end

	def setup_page_settings
		@tile_id = @page.graphic.tile_id
		@direction = @page.graphic.direction
		@move_type = @page.move_type
		@move_speed = @page.move_speed
		@move_frequency = @page.move_frequency
		@through = @page.through
		@priority_type = @page.priority_type
		@trigger = @page.trigger
		@list = @page.list
		#@interpreter = @trigger == 4 ? Game_Interpreter.new : nil
		@enemy_id = enemy_id
		@stop_count_threshold = stop_count_threshold / 40
		if enemy?
			setup_enemy_settings
		# Se o inimigo agora é um evento
		else
			clear_enemy
			clear_target
		end
	end

	def setup_enemy_settings
		@param_base = $data_enemies[@enemy_id].params
		@sight = $data_enemies[@enemy_id].sight
		@escape = $data_enemies[@enemy_id].escape
		@hp = mhp
		@mp = mmp
	end

	def enemy_id
		result = 0
		@list.each do |item|
			next unless item.code == 108
			next unless item.parameters[0].start_with?('Enemy')
			result = item.parameters[0].split('=')[1].to_i
			break
		end
		result
	end

	def collide_with_characters?(x, y)
		super || collide_with_players?(x, y)
	end
	
	def stop_count_threshold
		30 * (5 - @move_frequency)
	end
	
	def find_proper_page(client)
		@pages.reverse.find { |page| conditions_met?(client, page) }
	end

	def conditions_met?(client, page)
		c = page.condition
		if c.switch1_valid
			return false unless client.switches[c.switch1_id] || $server.switches[c.switch1_id - Configs::MAX_PLAYER_SWITCHES] && c.switch1_id >= Configs::MAX_PLAYER_SWITCHES
		end
		if c.switch2_valid
			return false unless client.switches[c.switch2_id] || $server.switches[c.switch2_id - Configs::MAX_PLAYER_SWITCHES] && c.switch2_id >= Configs::MAX_PLAYER_SWITCHES
		end
		if c.variable_valid
			return false if client.variables[c.variable_id] < c.variable_value
		end
		if c.self_switch_valid
			key = [client.map_id, @id, c.self_switch_ch]
			return false unless client.self_switches[key]
		end
		if c.item_valid
			return false unless client.actor.items[c.item_id]
		end
		return page
	end

	def find_global_proper_page
		@pages.reverse.find { |page| global_conditions_met?(page) }
	end

	def global_conditions_met?(page)
		c = page.condition
		if c.switch1_valid
			return false unless $server.switches[c.switch1_id - Configs::MAX_PLAYER_SWITCHES] && c.switch1_id >= Configs::MAX_PLAYER_SWITCHES
		end
		if c.switch2_valid
			return false unless $server.switches[c.switch2_id - Configs::MAX_PLAYER_SWITCHES] && c.switch2_id >= Configs::MAX_PLAYER_SWITCHES
		end
		return true
	end

	def check_event_trigger_touch(x, y)
		return unless @trigger == 2
		$server.clients.each do |client|
			next unless client&.in_game? || client.map_id == @map_id || client.pos?(x, y) || normal_priority?
			start(client)
			break
		end
	end

	def update
		update_self_movement
		update_enemy if enemy?
	end

	def update_self_movement
		return if erased?
		return if @stop_count > Time.now
		@stop_count = Time.now + @stop_count_threshold
		if @move_type == Constants::MOVE_RANDOM && !in_battle?
			move_random
		elsif in_battle? && @escape && @hp < mhp / 3 && near_the_player?(get_target)
			move_away_from_player(get_target)
		elsif @move_type == Constants::MOVE_TOWARD_PLAYER || in_battle?
			move_type_toward_player
		end
	end

	def move_random
		move_straight(rand(4) * 2 + 2, false)
	end

	def move_type_toward_player
		if $server.maps[@map_id].zero_players?
			move_random
			return
		end
		target = get_target
		target = find_target unless near_the_player?(target)
		if target
			@target.id = target.id
			move_toward_player(target)
		else
			clear_target
			move_random
		end
	end

	def near_the_player?(target)
		# Aumenta o alcance para seguir jogadores que atacam com armas de longa distância
		target && valid_target?(target) && in_range?(target, @sight + 5)
	end

	def move_toward_player(target)
		return if in_front?(target)
		sx = distance_x_from(target.x)
		sy = distance_y_from(target.y)
		if sx.abs > sy.abs
			move_straight(sx > 0 ? Constants::DIR_LEFT : Constants::DIR_RIGHT)
			move_straight(sy > 0 ? Constants::DIR_UP : Constants::DIR_DOWN) if !@move_succeed && sy != 0
		else
			move_straight(sy > 0 ? Constants::DIR_UP : Constants::DIR_DOWN)
			move_straight(sx > 0 ? Constants::DIR_LEFT : Constants::DIR_RIGHT) if !@move_succeed && sx != 0
		end
	end

	def move_away_from_player(target)
		sx = distance_x_from(target.x)
		sy = distance_y_from(target.y)
		if sx.abs > sy.abs
			move_straight(sx > 0 ? Constants::DIR_RIGHT : Constants::DIR_LEFT)
			move_straight(sy > 0 ? Constants::DIR_DOWN : Constants::DIR_UP) if !@move_succeed && sy != 0
		else
			move_straight(sy > 0 ? Constants::DIR_DOWN : Constants::DIR_UP)
			move_straight(sx > 0 ? Constants::DIR_RIGHT : Constants::DIR_LEFT) if !@move_succeed && sx != 0
		end
	end

	def send_movement
		$server.send_event_movement(self)
	end

	def find_target
		$server.clients.find { |client| client&.in_game? && client.map_id == @map_id && in_range?(client, @sight) }
	end

	def empty?(list)
		!list || list.size <= 1
	end

	def trigger_in?(triggers)
		triggers.include?(@trigger)
	end

	def start(client)
		page = find_proper_page(client)
		return if !page || empty?(page.list)
		@interpreter.setup(client, page.list, @id)
	end

end
