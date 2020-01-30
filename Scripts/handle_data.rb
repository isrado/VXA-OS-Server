#==============================================================================
# ** Handle_Data
#------------------------------------------------------------------------------
#  Este script recebe as mensagens do cliente.
#------------------------------------------------------------------------------
#  Autor: Valentine
#==============================================================================

module Handle_Data

	def handle_messages(client, buffer)
		begin
			header = buffer.read_byte
			if client.in_game?
				handle_messages_game(client, header, buffer)
			else
				handle_messages_menu(client, header, buffer)
			end
		rescue => e
			client.close_connection
			@log.add('Error', :red, "Erro: #{e}\n#{e.backtrace.join("\n")}")
		end
	end

	def handle_messages_menu(client, header, buffer)
		case header
		when Constants::PACKET_LOGIN
			handle_login(client, buffer)
		when Constants::PACKET_NEW_ACCOUNT
			handle_new_account(client, buffer)
		when Constants::PACKET_NEW_CHAR
			handle_new_character(client, buffer)
		when Constants::PACKET_REMOVE_CHAR
			handle_remove_character(client, buffer)
		when Constants::PACKET_USE_CHAR
			handle_use_character(client, buffer)
		end
	end

	def handle_messages_game(client, header, buffer)
		case header
		when Constants::PACKET_PLAYER_MOVE
			handle_player_movement(client, buffer)
		when Constants::PACKET_CHAT_MSG
			handle_chat_message(client, buffer)
		when Constants::PACKET_PLAYER_ATTACK
			handle_player_attack(client)
		when Constants::PACKET_USE_ITEM
			handle_use_item(client, buffer)
		when Constants::PACKET_USE_SKILL
			handle_use_skill(client, buffer)
		when Constants::PACKET_CHANGE_HOTBAR
			handle_change_hotbar(client, buffer)
		when Constants::PACKET_USE_HOTBAR
			handle_use_hotbar(client, buffer)
		when Constants::PACKET_TARGET
			handle_target(client, buffer)
		when Constants::PACKET_ADD_DROP
			handle_add_drop(client, buffer)
		when Constants::PACKET_REMOVE_DROP
			handle_remove_drop(client, buffer)
		when Constants::PACKET_PLAYER_PARAM
			handle_player_param(client, buffer)
		when Constants::PACKET_PLAYER_EQUIP
			handle_player_equip(client, buffer)
		when Constants::PACKET_OPEN_FRIENDS
			handle_open_friends(client)
		when Constants::PACKET_REMOVE_FRIEND
			handle_remove_friend(client, buffer)
		when Constants::PACKET_NEW_GUILD
			handle_new_guild(client, buffer)
		when Constants::PACKET_OPEN_GUILD
			handle_open_guild(client)
		when Constants::PACKET_GUILD_LEADER
			handle_change_guild_leader(client, buffer)
		when Constants::PACKET_GUILD_NOTICE
			handle_change_guild_notice(client, buffer)
		when Constants::PACKET_REMOVE_GUILD_MEMBER
			handle_remove_guild_member(client, buffer)
		when Constants::PACKET_LEAVE_GUILD
			handle_leave_guild(client)
		when Constants::PACKET_LEAVE_PARTY
			handle_leave_party(client)
		when Constants::PACKET_CHOICE
			handle_choice(client, buffer)
		when Constants::PACKET_BANK_ITEM
			handle_bank_item(client, buffer)
		when Constants::PACKET_BANK_GOLD
			handle_bank_gold(client, buffer)
		when Constants::PACKET_CLOSE_WINDOW
			handle_close_window(client)
		when Constants::PACKET_BUY_ITEM
			handle_buy_item(client, buffer)
		when Constants::PACKET_SELL_ITEM
			handle_sell_item(client, buffer)
		when Constants::PACKET_CHOICE_TELEPORT
			handle_choice_teleport(client, buffer)
		when Constants::PACKET_REQUEST
			handle_request(client, buffer)
		when Constants::PACKET_ACCEPT_REQUEST
			handle_accept_request(client)
		when Constants::PACKET_DECLINE_REQUEST
			handle_decline_request(client)
		when Constants::PACKET_TRADE_ITEM
			handle_trade_item(client, buffer)
		when Constants::PACKET_TRADE_GOLD
			handle_trade_gold(client, buffer)
		when Constants::PACKET_LOGOUT
			handle_logout(client)
		when Constants::PACKET_ADMIN_COMMAND
			handle_admin_command(client, buffer)
		end
	end
	
	def handle_login(client, buffer)
		user = buffer.read_string
		pass = buffer.read_string
		version = buffer.read_short
		if login_hacking_attempt?(client)
			client.close_connection
			return
		elsif version != Configs::GAME_VERSION
			send_failed_login(client, Constants::LOGIN_OLD_VERSION)
			# Fecha a conexão somente após a mensagem ser enviada
			client.close_connection_after_writing
			return
		elsif ip_blocked?(client.ip)
			send_failed_login(client, Constants::LOGIN_IP_BLOCKED)
			client.close_connection_after_writing
			return
		elsif !Database.account_exist?(user)
			send_failed_login(client, Constants::LOGIN_INVALD_USER)
			add_attempt(client)
			client.close_connection_after_writing
			return
		elsif banned?(user)
			send_failed_login(client, Constants::LOGIN_ACC_BANNED)
			client.close_connection_after_writing
			return
		elsif multi_accounts?(user)
			send_failed_login(client, Constants::LOGIN_MULTI_ACCOUNT)
			client.close_connection_after_writing
			return
		end
		account = Database.load_account(user)
		unless pass == account.pass
			send_failed_login(client, Constants::LOGIN_INVALID_PASS)
			add_attempt(client)
			client.close_connection_after_writing
			return
		end
		client.user = user
		client.pass = account.pass
		client.email = account.email
		client.group = account.group
		client.vip_time = account.vip_time
		client.actors = account.actors
		client.friends = account.friends
		client.handshake = true
		Database.load_bank(client)
		send_login(client)
		puts("#{user} logou com o IP #{client.ip}.")
	end

	def handle_new_account(client, buffer)
		# Evita mais de um cadastro com o mesmo usuário
		user = buffer.read_string.strip
		pass = buffer.read_string
		email = buffer.read_string
		version = buffer.read_short
		if new_account_hacking_attempt?(client, user, pass, email)
			client.close_connection
			return
		elsif version != Configs::GAME_VERSION
			send_failed_login(client, Constants::LOGIN_OLD_VERSION)
			client.close_connection_after_writing
			return
		elsif ip_blocked?(client.ip)
			send_failed_login(client, Constants::LOGIN_IP_BLOCKED)
			client.close_connection_after_writing
			return
		elsif Database.account_exist?(user)
			send_new_account(client, Constants::REGISTER_ACC_EXIST)
			client.close_connection_after_writing
			return
		end
		Database.create_account(user, pass, email)
		send_new_account(client, Constants::REGISTER_SUCCESSFUL)
		client.close_connection_after_writing
		puts("Conta #{user} criada.")
	end

	def handle_new_character(client, buffer)
		actor_id = buffer.read_byte
		name = adjust_name(buffer.read_string.strip)
		character_index = buffer.read_byte
		class_id = buffer.read_short
		sex = buffer.read_byte
		params = []
		8.times { params << buffer.read_byte }
		points = buffer.read_byte
		return unless client.logged?
		return if actor_id >= Configs::MAX_CHARS
		return if client.actors.has_key?(actor_id)
		return if name.size < Configs::MIN_CHARACTERS || name.size > Configs::MAX_CHARACTERS
		return if invalid_name?(name)
		return if illegal_name?(name) && client.standard?
		return if class_id < 1 || class_id > client.max_classes
		return if sex > Constants::SEX_FEMALE
		return if character_index >= $data_classes[class_id].graphics[sex].size
		return if params.inject(:+) + points > Configs::START_POINTS
		if Database.player_exist?(name)
			send_failed_new_character(client)
			return
		end
		Database.create_player(client, actor_id, name, character_index, class_id, sex, params, points)
		Database.save_account(client)
		send_new_character(client, actor_id, client.actors[actor_id])
	end

	def handle_remove_character(client, buffer)
		actor_id = buffer.read_byte
		pass = buffer.read_string
		return unless client.actors.has_key?(actor_id)
		unless pass == client.pass
			send_failed_login(client, Constants::LOGIN_INVALID_PASS)
			return
		end
		Database.remove_player(client.actors[actor_id].name)
		if !client.actors[actor_id].guild.empty?
			if @guilds[client.actors[actor_id].guild].leader == client.actors[actor_id].name
				remove_guild(client.actors[actor_id].guild)
			else
				@guilds[client.actors[actor_id].guild].members.delete(client.actors[actor_id].name)
				save_guild(client.actors[actor_id].guild)
			end
		end
		client.actors.delete(actor_id)
		Database.save_account(client)
		send_remove_character(client, actor_id)
	end

	def handle_use_character(client, buffer)
		actor_id = buffer.read_byte
		return unless client.actors.has_key?(actor_id)
		# Define os dados
		client.load_data(actor_id)
		# Envia os dados para os jogadores que estão no mapa, exceto para o próprio
		#jogador que ainda não está conectado
		send_player_data(client, client.map_id)
		@maps[client.map_id].total_players += 1
		# Conecta ao jogo
		client.join_game(actor_id)
		#global_message("#{client.name} #{Entered}", Configs::ALERT_COLOR)
		send_use_character(client)
		send_global_switches(client)
		send_map_players(client)
		send_map_events(client)
		send_map_drops(client)
		send_motd(client)
	end

	def handle_player_movement(client, buffer)
		d = buffer.read_byte
		# Anti-speed hack
		#return if client.moving?
		return if d < Constants::DIR_DOWN_LEFT || d > Constants::DIR_UP_RIGHT
		client.stop_count = Time.now + 0.170
		#if d == Constants::DIR_DOWN_LEFT
			#client.move_diagonal(4, 2)
		#elsif d == Constants::DIR_DOWN_RIGHT
			#client.move_diagonal(6, 2)
		#elsif d == Constants::DIR_UP_LEFT
			#client.move_diagonal(4, 8)
		#elsif d == Constants::DIR_UP_RIGHT
			#client.move_diagonal(6, 8)
		#else
			client.move_straight(d)
		#end
		if client.move_succeed
			client.check_touch_event
			client.close_windows
		end
	end

	def handle_chat_message(client, buffer)
		message = buffer.read_string
		talk_type = buffer.read_byte
		name = buffer.read_string
		return if message.strip.empty?
		return if talk_type == Constants::CHAT_GLOBAL && client.global_chat_spawning?
		return if client.spawning?
		return if client.muted?
		client.antispam_time = Time.now + 0.5
		if message == '/who'
			whos_online(client)
			return
		end
		message = "#{client.name} [#{client.level}]: #{chat_filter(message)}"
		case talk_type
		when Constants::CHAT_MAP
			map_message(client.map_id, message, client.id, !client.standard? ? 15 + client.group : Constants::CHAT_MAP)
		when Constants::CHAT_GLOBAL
			client.global_antispam_time = Time.now + Configs::GLOBAL_ANTISPAM_TIME
			global_message(message, !client.standard? ? 15 + client.group : Constants::CHAT_GLOBAL)
		when Constants::CHAT_PARTY
			party_message(client, message)
		when Constants::CHAT_GUILD
			guild_message(client, message)
		when Constants::CHAT_PRIVATE
			private_message(client, message, name)
		end
	end

	def handle_player_attack(client)
		return if client.attacking?
		if Configs::RANGE_WEAPONS.has_key?(client.weapon_id)
			client.attack_range
		elsif client.has_weapon?
			client.attack_normal
		end
		client.check_event_trigger_here([0])
		client.check_event_trigger_there([0])#([0, 1, 2])
	end

	def handle_use_item(client, buffer)
		item_id = buffer.read_short
		return if client.using_item?
		# Usa se o item existe, o jogador o tiver e for usável
		client.use_item($data_items[item_id])
	end

	def handle_use_skill(client, buffer)
		skill_id = buffer.read_short
		return if client.using_item?
		client.use_item($data_skills[skill_id])
	end

	def handle_change_hotbar(client, buffer)
		id = buffer.read_byte
		type = buffer.read_byte
		item_id = buffer.read_short
		return if id > Configs::MAX_HOTBAR
		client.change_hotbar(id, type, item_id)
	end

	def handle_use_hotbar(client, buffer)
		id = buffer.read_byte
		return unless client.hotbar[id]
		return if client.using_item?
		item_id = client.hotbar[id].item_id
		item = client.hotbar[id].type == Constants::HOTBAR_ITEM ? $data_items[item_id] : $data_skills[item_id]
		client.use_item(item)
	end

	def handle_target(client, buffer)
		type = buffer.read_byte
		target_id = buffer.read_short
		client.change_target(target_id, type)
	end

	def handle_add_drop(client, buffer)
		item_id = buffer.read_short
		kind = buffer.read_byte
		amount = buffer.read_short
		item = client.item_object(kind, item_id)
		# Impede que o item da troca, que não é removido do inventário, seja dropado
		return if client.in_trade?
		return if @maps[client.map_id].full_drops?
		return if amount < 1 || amount > client.item_number(item)
		return if item.soulbound?
		return if client.spawning?
		client.antispam_time = Time.now + 0.5
		client.lose_item(item, amount)
		@maps[client.map_id].add_drop(item_id, kind, amount, client.x, client.y)
	end

	def handle_remove_drop(client, buffer)
		drop_id = buffer.read_byte
		drop = @maps[client.map_id].drops[drop_id]
		return unless drop
		return unless client.pos?(drop.x, drop.y)
		#return unless client.in_range?(drop, 1)
		unless pick_up_drop?(drop, client)
			alert_message(client, Constants::ALERT_NOT_PICK_UP_DROP)
			return
		end
		item = client.item_object(drop.kind, drop.item_id)
		unless client.full_inventory?(item)
			client.gain_item(item, drop.amount, true, true)
			@maps[client.map_id].remove_drop(drop_id)
		end
	end

	def handle_player_param(client, buffer)
		param_id = buffer.read_byte
		return if client.points == 0
		client.points -= 1
		case param_id
		when Constants::PARAM_MAXHP, Constants::PARAM_MAXMP
			client.add_param(param_id, 10)
		when Constants::PARAM_ATK..Constants::PARAM_LUK
			client.add_param(param_id, 1)
		end
	end

	def handle_player_equip(client, buffer)
		slot_id = buffer.read_byte
		item_id = buffer.read_short
		return if client.spawning?
		client.antispam_time = Time.now + 0.5
		client.change_equip(slot_id, item_id)
	end

	def handle_open_friends(client)
		online_friends = client.friends.select { |name| find_player(name) }
		offline_friends = client.friends - online_friends
		client.friends = online_friends + offline_friends
		client.online_friends_size = online_friends.size
		send_open_friends(client, online_friends)
	end
	
	def handle_remove_friend(client, buffer)
		index = buffer.read_byte
		client.friends.delete_at(index)
		client.online_friends_size -= 1 if index <= client.online_friends_size - 1
		send_remove_friend(client, index)
	end

	def handle_new_guild(client, buffer)
		flag = []
		name = adjust_name(buffer.read_string.strip)
		64.times { flag << buffer.read_byte }
		return unless client.creating_guild?
		return if client.in_guild?
		return if name.size < Configs::MIN_CHARACTERS || name.size > Configs::MAX_CHARACTERS
		return if invalid_name?(name)
		create_guild(client, name, flag)
	end

	def handle_open_guild(client)
		return unless client.in_guild?
		open_guild(client)
	end

	def handle_change_guild_leader(client, buffer)
		name = buffer.read_string
		return unless client.in_guild? && client.guild_leader?
		change_guild_leader(client, name)
	end

	def handle_change_guild_notice(client, buffer)
		# Altera a codificação padrão da mensagem recebida pela Socket do Ruby (ASCII-8BIT) para UTF-8
		notice = buffer.read_string.force_encoding('UTF-8')
		return unless client.in_guild?
		return unless client.guild_leader?
		return if notice.strip.empty? || notice.size > 64
		return if client.spawning?
		client.antispam_time = Time.now + 0.5
		change_guild_notice(client, notice)
	end

	def handle_remove_guild_member(client, buffer)
		name = buffer.read_string
		return unless client.in_guild? && client.guild_leader?
		member = find_guild_member(@guilds[client.guild], name)
		remove_guild_member(client, member) if member && @guilds[client.guild].leader != member
	end
	
	def handle_leave_guild(client)
		return unless client.in_guild?
		if client.guild_leader?
			# Possibilita que a guilda seja deletada e que o texto da variável guild dos membros que
			#logaram posteriormente ao líder seja apagado, mesmo após a string guild do líder ficar vazia
			remove_guild(client.guild.clone)
		else
			client.leave_guild
		end
	end

	def handle_leave_party(client)
		# Sai do grupo se o jogador estiver em um
		client.leave_party
	end

	def handle_choice(client, buffer)
		index = buffer.read_byte
		return unless client.choosing?
		#command = client.choices[0]
		#param = command.parameters[0][index]
		#client.interpreter.setup(client, client.choices) if param
	end
	
	def handle_bank_item(client, buffer)
		item_id = buffer.read_short
		kind = buffer.read_byte
		amount = buffer.read_short
		item = client.item_object(kind, item_id)
		container = client.bank_item_container(kind)
		return unless client.in_bank?
		return unless container
		# Se o item que está sendo adicionado não existe ou a quantidade é maior que a do inventário
		return if amount > 0 && client.item_number(item) < amount
		return if amount < 0 && client.bank_item_number(container[item_id]) < amount.abs
		return if amount > 0 && client.full_bank?(container[item_id], kind)
		return if amount < 0 && client.full_inventory?(item)
		return if item.soulbound?
		client.gain_bank_item(item_id, kind, amount)
		client.lose_item(item, amount)
	end

	def handle_bank_gold(client, buffer)
		amount = buffer.read_int
		return unless client.in_bank?
		return if amount > 0 && client.gold < amount
		return if amount < 0 && client.bank_gold < amount.abs
		client.gain_bank_gold(amount)
		client.lose_gold(amount)
	end

	def handle_close_window(client)
		client.close_bank
		client.close_shop
		client.close_trade
		client.close_create_guild
	end

	def handle_buy_item(client, buffer)
		index = buffer.read_byte
		amount = buffer.read_short.abs
		return unless client.in_shop?
		return unless client.shop_goods[index]
		kind = client.shop_goods[index][0]
		item_id = client.shop_goods[index][1]
		item = client.item_object(kind + 1, item_id)
		price = client.shop_goods[index][2] == 0 ? item.price : client.shop_goods[index][3]
		if client.gold >= price * amount && (!client.full_inventory?(item) || amount < 0)
			client.gain_item(item, amount)
			client.lose_gold(price * amount, true)
		end
	end
	
	def handle_sell_item(client, buffer)
		item_id = buffer.read_short
		kind = buffer.read_byte
		amount = buffer.read_short.abs
		return unless client.in_shop?
		return if client.shop_goods[0][4]
		item = client.item_object(kind, item_id)
		if client.item_number(item) >= amount
			client.lose_item(item, amount)
			client.gain_gold(amount * item.price / 2, true)
		end
	end

	def handle_choice_teleport(client, buffer)
		index = buffer.read_byte
		return unless client.in_teleport?
		return unless Configs::TELEPORTS[client.teleport_id][index]
		return if Configs::TELEPORTS[client.teleport_id][index][3] > client.gold
		map_id, x, y, amount = Configs::TELEPORTS[client.teleport_id][index]
		client.transfer(map_id, x, y, Constants::DIR_DOWN)
		client.lose_gold(amount)
	end

	def handle_request(client, buffer)
		type = buffer.read_byte
		player_id = buffer.read_short
		return if client.spawning?
		client.antispam_time = Time.now + 0.5
		case type
		when Constants::REQUEST_TRADE
			return if requested_unavailable?(client, @clients[player_id])
			return if client.in_trade? || client.in_shop? || client.in_bank?
			if @clients[player_id].in_trade? || @clients[player_id].in_shop? || @clients[player_id].in_bank?
				alert_message(client, Constants::ALERT_BUSY)
				return
			end
		when Constants::REQUEST_FINISH_TRADE
			return unless client.in_trade?
			player_id = client.trade_player_id
		when Constants::REQUEST_PARTY
			return if requested_unavailable?(client, @clients[player_id])
			return if client.in_party? && @parties[client.party_id].size >= Configs::MAX_PARTY_MEMBERS
			if @clients[player_id].in_party?
				alert_message(client, Constants::ALERT_IN_PARTY)
				return
			end
		when Constants::REQUEST_FRIEND
			return if requested_unavailable?(client, @clients[player_id])
			return if client.friends.size >= Configs::MAX_FRIENDS
			return if client.friends.include?(@clients[player_id].name)
		when Constants::REQUEST_GUILD
			return if requested_unavailable?(client, @clients[player_id])
			return if !client.in_guild? || @clients[player_id].in_guild?
			if !client.guild_leader?
				alert_message(client, Constants::ALERT_NOT_GUILD_LEADER)
				return
			elsif @guilds[client.guild].members.size >= Configs::MAX_GUILD_MEMBERS
				alert_message(client, Constants::ALERT_FULL_GUILD)
				return
			end
		end
		@clients[player_id].request.id = client.id
		@clients[player_id].request.type = type
		send_request(@clients[player_id], type, client)
	end

	def handle_accept_request(client)
		case client.request.type
		when Constants::REQUEST_TRADE
			client.open_trade
		when Constants::REQUEST_FINISH_TRADE
			client.finish_trade
		when Constants::REQUEST_PARTY
			client.accept_party
		when Constants::REQUEST_FRIEND
			client.accept_friend
		when Constants::REQUEST_GUILD
			client.accept_guild
		end
		client.clear_request
	end

	def handle_decline_request(client)
		case client.request.type
		when Constants::REQUEST_TRADE, Constants::REQUEST_PARTY, Constants::REQUEST_FRIEND, Constants::REQUEST_GUILD
			alert_message(@clients[client.request.id], Constants::ALERT_REQUEST_DECLINED) if @clients[client.request.id]&.in_game?
		when Constants::REQUEST_FINISH_TRADE
			alert_message(@clients[client.request.id], Constants::ALERT_TRADE_DECLINED) if client.in_trade?
		end
		client.clear_request
	end

	def handle_trade_item(client, buffer)
		item_id = buffer.read_short
		kind = buffer.read_byte
		amount = buffer.read_short
		item = client.item_object(kind, item_id)
		container = client.trade_item_container(kind)
		return unless client.in_trade?
		return unless container
		# Se o item que está sendo adicionado não existe ou a quantidade é maior que a do inventário
		return if amount > 0 && client.item_number(item) < client.trade_item_number(container[item_id]) + amount
		return if amount < 0 && client.trade_item_number(container[item_id]) < amount
		return if amount > 0 && client.full_trade?(container[item_id])
		return if item.soulbound?
		# O item é removido da troca sem precisar verificar se o inventário está cheio, pois a
		#quantidade de itens do inventário não é verdadeiramente alterada na troca
		client.gain_trade_item(item_id, kind, amount)
		client.close_trade_request
	end

	def handle_trade_gold(client, buffer)
		amount = buffer.read_int
		return unless client.in_trade?
		return if amount > 0 && client.gold < client.trade_gold + amount
		return if amount < 0 && client.trade_gold < amount
		client.gain_trade_gold(amount)
		client.close_trade_request
	end

	def handle_logout(client)
		send_logout(client)
		client.leave_game
	end

	def handle_admin_command(client, buffer)
		command = buffer.read_byte
		# Altera a codificação padrão da mensagem recebida pela Socket do Ruby (ASCII-8BIT) para UTF-8
		str1 = buffer.read_string.force_encoding('UTF-8')
		str2 = buffer.read_int
		str3 = buffer.read_int
		str4 = buffer.read_short
		if client.admin?
			admin_commands(client, command, str1, str2, str3, str4)
		elsif client.monitor?
			monitor_commands(client, command, str1, str2, str3, str4)
		end
	end

end
