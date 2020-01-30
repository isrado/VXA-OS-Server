#==============================================================================
# ** Battle
#------------------------------------------------------------------------------
#  Este script lida com a batalha em tempo real.
#------------------------------------------------------------------------------
#  Autor: Valentine
#==============================================================================

module Game_Battler

  ITEM_EFFECT_TABLE = {
    11 => :item_effect_recover_hp,
    12 => :item_effect_recover_mp,
    42 => :item_effect_grow,
    43 => :item_effect_learn_skill
  }

  def in_front?(target)
    x = $server.maps[@map_id].round_x_with_direction(@x, @direction)
    y = $server.maps[@map_id].round_y_with_direction(@y, @direction)
    target.pos?(x, y)
  end

  def in_range?(target, range)
    distance_x_from(target.x).abs <= range && distance_y_from(target.y).abs <= range
  end

  def clear_target
    @target.id = -1
    @target.type = Constants::TARGET_NONE
  end

  def get_target
    # Verifica se o ID do alvo é maior ou igual a 0 para impedir que
    #retorne o último elemento da matriz
    @target.type == Constants::TARGET_ENEMY ? $server.maps[@map_id].events[@target.id] : @target.id >= 0 ? $server.clients[@target.id] : nil
  end

  def valid_target?(target)
    result = target.in_game? && target.map_id == @map_id
    clear_target unless result
    result
  end

  def apply_variance(damage, variance)
    amp = [damage.abs * variance / 100, 0].max.to_i
    var = rand(amp + 1) + rand(amp + 1) - amp
    damage >= 0 ? damage + var : damage - var
  end

  def make_damage_value(user, item, critical, animation_id)
    value = item.damage.eval(user, self, user.variables)
    value *= item_element_rate(user, item)
    value *= pdr if item.physical?
    value *= mdr if item.magical?
    value *= rec if item.damage.recover?
    value = value * 3 if critical
    value = apply_variance(value, item.damage.variance)
    value = apply_guard(value)
    # Se no cálculo do dano tinha número decimal, converte o resultado em inteiro
    execute_hp_damage(-value.to_i, critical, animation_id)
  end

  def apply_guard(damage)
    damage / (damage > 0 && guard? ? 2 * grd : 1)
  end

  def execute_hp_damage(damage, critical, animation_id)
    damage = -@hp if damage < 0 && damage.abs > @hp
    damage = mhp - @hp if damage > 0 && @hp + damage > mhp
    send_attack(damage, 0, critical, animation_id)
    @hp += damage
    # Se o HP ficou aquém ou além do limite
    refresh
    die if dead?
  end

  def execute_mp_damage(damage, critical, animation_id)
    damage = -@mp if damage < 0 && damage.abs > @mp
    damage = mmp - @mp if damage > 0 && @mp + damage > mmp
    send_attack(0, damage, critical, animation_id)
    @mp += damage
    # Se o MP ficou aquém ou além do limite
    refresh
  end

  def item_hit(user, item)
    rate = item.success_rate * 0.01
    rate *= user.hit if item.physical?
    return rate
  end

  def item_eva(user, item)
    return eva if item.physical?
    return mev if item.magical?
    return 0
  end

  def item_cri(user, item)
    item.damage.critical ? user.cri * (1 - cev) : 0
  end

  def item_element_rate(user, item)
    if item.damage.element_id < 0
      user.atk_elements.empty? ? 1.0 : elements_max_rate(user.atk_elements)
    else
      element_rate(item.damage.element_id)
    end
  end

  def elements_max_rate(elements)
    elements.inject([0.0]) { |r, i| r << element_rate(i) }.max
  end

  def item_apply(user, item, animation_id)
    missed = (rand >= item_hit(user, item))
    evaded = (!missed && rand < item_eva(user, item))
    unless missed || evaded
      unless item.damage.none?
        critical = (rand < item_cri(user, item))
        make_damage_value(user, item, critical, animation_id)
      end
      item.effects.each { |effect| item_effect_apply(user, item, effect) }
    end
  end

  def item_effect_apply(user, item, effect)
    method_name = ITEM_EFFECT_TABLE[effect.code]
    send(method_name, user, item, effect) if method_name
  end

  def item_effect_recover_hp(user, item, effect)
    value = (mhp * effect.value1 + effect.value2) * rec
    value *= user.pha if item.is_a?(RPG::Item)
    execute_hp_damage(value.to_i, false, item.animation_id)
  end

  def item_effect_recover_mp(user, item, effect)
    value = (mmp * effect.value1 + effect.value2) * rec
    value *= user.pha if item.is_a?(RPG::Item)
    execute_mp_damage(value.to_i, false, item.animation_id)
  end

  def item_effect_grow(user, item, effect)
    add_param(effect.data_id, effect.value1.to_i)
  end

  def item_effect_learn_skill(user, item, effect)
    learn_skill(effect.data_id) if self.is_a?(Game_Client)
  end

  def max_passage(target)
    # Permite que o projétil atinja o alvo se este e o
    #jogador estiverem nas mesmas coordenadas x e y
    return [target.x, target.y] if pos?(target.x, target.y)
    radians = Math.atan2(target.x - @x, target.y - @y)
    speed_x = Math.sin(radians)
    speed_y = Math.cos(radians)
    result = [target.x, target.y]
    range_x = (target.x - @x).abs
    range_y = (target.y - @y).abs
    # Obtém a direção do projétil em vez de usar a do jogador
    #que pode estar de costas para o alvo
    direction = projectile_direction(target)
    x = @x
    y = @y
    while true
      # Soma valores decimais
      x += speed_x
      y += speed_y
      x2 = x.to_i
      y2 = y.to_i
      # Se o projétil ultrapassou o limite, sai do laço sem verificar se as coordenadas
      #x2 e y2 são bloqueadas e, consequentemente, sem modificar o result
      if distance_x_from(x2).abs > range_x || distance_y_from(y2).abs > range_y
        break
      elsif !map_passable?(x2, y2, direction)
        result = [x2, y2]
        break
      end
    end
    result
  end

  def projectile_direction(target)
    sx = distance_x_from(target.x)
    sy = distance_y_from(target.y)
    if sx.abs > sy.abs
      direction = sx > 0 ? 4 : 6
    elsif sy != 0
      direction = sy > 0 ? 8 : 2
    end
    direction
  end

  def blocked_passage?(target, x, y)
    !target.pos?(x, y)
  end

  def map_passable?(x, y, d)
    $server.maps[@map_id].valid?(x, y) && $server.maps[@map_id].passable?(x, y, d)
  end

  def clear_target_players(type, map_id = @map_id)
    return if $server.maps[map_id].zero_players?
    $server.clients.each do |client|
      next unless client&.in_game? && client.map_id == map_id
      next unless client.target.id == @id && client.target.type == type
      client.change_target(-1, Constants::TARGET_NONE)
    end
  end

end

#==============================================================================
# ** Game_Client
#==============================================================================
class Game_Client < EventMachine::Connection

  EFFECT_COMMON_EVENT = 44

  def attack_normal
    @weapon_attack_time = Time.now + Configs::ATTACK_TIME
    $server.maps[@map_id].events.each_value do |event|
      # Se é um evento, inimigo morto, ou inimigo vivo fora do alcance
      next if event.dead? || !in_front?(event)
      hit_enemy(event, $data_weapons[weapon_id].animation_id, $data_skills[attack_skill_id])
      return
    end
    return unless $server.maps[@map_id].pvp
    return unless $server.maps[@map_id].total_players > 1
    $server.clients.each do |client|
      next if !client&.in_game? || client.map_id != @map_id || !in_front?(client) || client.admin? || protection_level?(client) || in_same_party?(client)
	  #LM² - No PvP Zone
      return if $server.maps[@map_id].region_id(client.x, client.y) == NO_PVP_ZONE
      return if $server.maps[@map_id].region_id(@x, @y) == NO_PVP_ZONE
      hit_player(client, $data_weapons[weapon_id].animation_id, $data_skills[attack_skill_id])
      break
    end
  end
  
  def in_same_party?(client)
    return in_party? && client.in_party? && @party_id == client.party_id
  end

  def attack_range
    @weapon_attack_time = Time.now + Configs::ATTACK_TIME
    range, item_id, mp_cost = Configs::RANGE_WEAPONS[weapon_id].drop(1)
    return if item_id > 0 && !has_item?($data_items[item_id])
    return if mp_cost && mp < mp_cost
    target = get_target
    return unless target && in_range?(target, range)
	 #LM² - No PvP Zone
    return if @target.type == Constants::TARGET_PLAYER && $server.maps[@map_id].region_id(target.x, target.y) == NO_PVP_ZONE
    return if @target.type == Constants::TARGET_PLAYER && $server.maps[@map_id].region_id(@x, @y) == NO_PVP_ZONE  
    lose_item($data_items[item_id], 1) if item_id > 0
    self.mp -= mp_cost if mp_cost
    x, y = max_passage(target)
    $server.send_add_projectile(self, x, y, target, Constants::PROJECTILE_WEAPON, weapon_id)
    return if blocked_passage?(target, x, y)
    if @target.type == Constants::TARGET_PLAYER && valid_target?(target) && $server.maps[@map_id].pvp && !target.admin? && !protection_level?(target) && !in_same_party?(target)
      hit_player(target, $data_weapons[weapon_id].animation_id, $data_skills[attack_skill_id])
    elsif @target.type == Constants::TARGET_ENEMY && !target.dead?
      hit_enemy(target, $data_weapons[weapon_id].animation_id, $data_skills[attack_skill_id])
    end
  end

  def use_item(item)
    @item_attack_time = Time.now + Configs::COOLDOWN_SKILL_TIME
    # Se não tem o item ou ele não é usável
    return unless usable?(item)
    return if item.level > @level
    self.mp -= item.mp_cost if item.is_a?(RPG::Skill)
    consume_item(item) if item.is_a?(RPG::Item)
    item.effects.each { |effect| item_global_effect_apply(effect) }
    case item.scope
    when Constants::ITEM_SCOPE_ALL_ALLIES
      item_party_recovery(item)
    when Constants::ITEM_SCOPE_ENEMY..Constants::ITEM_SCOPE_ALLIES_KNOCKED_OUT
      if item.area?
        item_attack_area(item)
      else
        item_attack_normal(item)
      end
    when Constants::ITEM_SCOPE_USER
      item_recover(item)
    end
  end

  def consume_item(item)
    lose_item(item, 1) if item.consumable
  end

  def item_global_effect_apply(effect)
    @interpreter.setup(self, $data_common_events[effect.data_id].list) if effect.code == EFFECT_COMMON_EVENT
  end

  def item_attack_normal(item)
    target = get_target
    # Se não tem alvo, o alvo é um evento, inimigo morto, ou inimigo vivo fora do alcance, ou o item é para aliado
    if !target || target.dead? || !in_range?(target, item.range) || @target.type == Constants::TARGET_ENEMY && item.for_friend?
      # Usa o item que afeta apenas aliados no próprio jogador
      item_apply(self, item, item.animation_id) if item.for_friend?
      return
    end
    x, y = max_passage(target)
    $server.send_add_projectile(self, x, y, target, Constants::PROJECTILE_SKILL, item.id) if item.is_a?(RPG::Skill) && Configs::RANGE_SKILLS.has_key?(item.id)
    return if blocked_passage?(target, x, y)
    if @target.type == Constants::TARGET_PLAYER && valid_target?(target) && !in_same_party?(target)
      hit_player(target, item.animation_id, item) if item.for_friend? || $server.maps[@map_id].pvp && !target.admin? && !protection_level?(target)
    elsif @target.type == Constants::TARGET_ENEMY
      hit_enemy(target, item.animation_id, item)
    end
  end

  def item_attack_area(item)
    $server.maps[@map_id].events.each_value do |event|
      next if event.dead? || !in_range?(event, item.area)
      hit_enemy(event, 0, item)
    end
    if $server.maps[@map_id].pvp && $server.maps[@map_id].total_players > 1
      $server.clients.each do |client|
        next if !client&.in_game? || client.map_id != @map_id || !in_range?(client, item.area) || client.admin? || protection_level?(client)
        hit_player(client, 0, item)
      end
    end
    $server.send_animation(self, item.animation_id, Constants::TARGET_PLAYER)
  end

  def item_recover(item)
    item_apply(self, item, item.animation_id)
  end

  def protection_level?(target)
    @level < Configs::MIN_LEVEL_PVP || target.level < Configs::MIN_LEVEL_PVP
  end

  def hit_player(client, animation_id, skill)
    change_target(client.id, Constants::TARGET_PLAYER)
    client.item_apply(self, skill, animation_id)
  end

  def hit_enemy(event, animation_id, skill)
    change_target(event.id, Constants::TARGET_ENEMY)
    event.target.id = @id
    event.item_apply(self, skill, animation_id)
  end

  def send_attack(hp_damage, mp_damage, critical, animation_id)
    $server.send_attack_player(@map_id, hp_damage, mp_damage, critical, @id, animation_id)
  end

  def die
    lose_gold(@gold * LOSE_GOLD_RATE / 100)
    lose_exp(@exp * lose_exp_rate / 100)
    recover_all
    clear_buffs
    transfer(@revive_map_id, @revive_x, @revive_y, Constants::DIR_DOWN)
    #$server.global_message("#{@name} #{Died}", Configs::ERROR_COLOR)
    #$server.player_message(self, Died, Configs::ERROR_COLOR)
  end

end

#==============================================================================
# ** Game_Enemy
#==============================================================================
module Game_Enemy

  CONDITIONS_MET_TABLE = {
    2 => :conditions_met_hp?,
    3 => :conditions_met_mp?,
    4 => :conditions_met_state?,
    5 => :conditions_met_party_level?,
    6 => :conditions_met_switch?,
  }

  def update_enemy
    if in_battle?
      make_actions
    elsif dead? && Time.now > @respawn_time
      respawn
    end
  end

  def respawn
    @hp = mhp
    $server.send_enemy_respawn(self)
    change_position unless $server.maps[@map_id].respawn_regions.empty?
  end

  def die
    @respawn_time = Time.now + $data_enemies[@enemy_id].respawn_time
    clear_target_players(Constants::TARGET_ENEMY)
    clear_states
    clear_buffs
    treasure
    disable
    # Limpa o alvo após este ganhar experiência e ouro
    clear_target
  end

  def treasure
    if $server.clients[@target.id].in_party?
      # Não converte em inteiro aqui, pois o resultado provisório ainda será multiplicado pelo bônus VIP
      $server.clients[@target.id].party_share($data_enemies[@enemy_id].exp * EXP_BONUS, rand($data_enemies[@enemy_id].gold).to_i * GOLD_BONUS, @enemy_id)
    else
      # Converte eventual resultado decimal do bônus de experiência em inteiro
      $server.clients[@target.id].gain_exp(($data_enemies[@enemy_id].exp * EXP_BONUS * $server.clients[@target.id].vip_exp_bonus).to_i)
      # Amount será um número inteiro, ainda que o ouro seja 0 e em razão
      #disso o rand retorne um valor decimal
      $server.clients[@target.id].gain_gold((rand($data_enemies[@enemy_id].gold).to_i * GOLD_BONUS * $server.clients[@target.id].gold_rate * $server.clients[@target.id].vip_gold_bonus).to_i, false, true)
      $server.clients[@target.id].add_kills_count(@enemy_id)
    end
    drop_items
  end

  def drop_items
    $data_enemies[@enemy_id].drop_items.each do |drop|
      next if drop.kind == 0 || rand * drop.denominator > (DROP_BONUS + $server.clients[@target.id].drop_item_rate + $server.clients[@target.id].vip_drop_bonus - 2)
      break if $server.maps[@map_id].full_drops?
      $server.maps[@map_id].add_drop(drop.data_id, drop.kind, 1, @x, @y, $server.clients[@target.id].name, $server.clients[@target.id].party_id)
    end 
  end

  def disable
    $server.clients[@target.id].change_variable($data_enemies[@enemy_id].disable_variable_id, $server.clients[@target.id].variables[$data_enemies[@enemy_id].disable_variable_id] + 1) if $data_enemies[@enemy_id].disable_variable_id > 0
    if $data_enemies[@enemy_id].disable_switch_id >= Configs::MAX_PLAYER_SWITCHES
      $server.change_global_switch($data_enemies[@enemy_id].disable_switch_id, !$server.switches[$data_enemies[@enemy_id].disable_switch_id - Configs::MAX_PLAYER_SWITCHES])
      # Possibilita que o inimigo reapareça ao ser ativado novamente
      $server.send_enemy_respawn(self)
    elsif $data_enemies[@enemy_id].disable_switch_id > 0
      $server.clients[@target.id].change_switch($data_enemies[@enemy_id].disable_switch_id, !$server.clients[@target.id].switches[$data_enemies[@enemy_id].disable_switch_id])
    end
  end

  def change_position
    while true
      region_id = rand($server.maps[@map_id].respawn_regions.size)
      x = $server.maps[@map_id].respawn_regions[region_id].x
      y = $server.maps[@map_id].respawn_regions[region_id].y
      if passable?(x, y, 0)
        moveto(x, y)
        break
      end
    end
  end

  def feature_objects
    states + [$data_enemies[@enemy_id]]
  end
  
  def make_actions
    return if @action_time > Time.now
    action_list = $data_enemies[@enemy_id].actions.select { |a| action_valid?(a) }
    unless action_list.empty?
      action = action_list[rand(action_list.size)]
      @action_time = Time.now + Configs::ATTACK_TIME
      action.skill_id == attack_skill_id ? attack_normal : use_item(action.skill_id)
    end
  end

  def action_valid?(action)
    action_conditions_met?(action) && usable?($data_skills[action.skill_id])
  end

  def action_conditions_met?(action)
    method_name = CONDITIONS_MET_TABLE[action.condition_type]
    method_name ? send(method_name, action.condition_param1, action.condition_param2) : true
  end

  def conditions_met_hp?(param1, param2)
    hp_rate >= param1 && hp_rate <= param2
  end

  def conditions_met_mp?(param1, param2)
    mp_rate >= param1 && mp_rate <= param2
  end

  def conditions_met_state?(param1, param2)
    state?(param1)
  end

  def conditions_met_level?(param1, param2)
    $server.clients[@target.id].level >= param1
  end

  def conditions_met_switch?(param1, param2)
    $server.clients[@target.id].switches[param1]
  end

  def attack_normal
    $server.clients.each do |client|
      next if !client&.in_game? || client.map_id != @map_id || !in_front?(client)
      client.item_apply(self, $data_skills[attack_skill_id], $data_skills[attack_skill_id].animation_id)
      break
    end
  end

  def use_item(item_id)
    item = $data_skills[item_id]
    case item.scope
    when Constants::ITEM_SCOPE_ENEMY..Constants::ITEM_SCOPE_ALLIES_KNOCKED_OUT
      if item.area?
        item_attack_area(item)
      else
        item_attack_normal(item)
      end
    when Constants::ITEM_SCOPE_USER
      item_recover(item)
    end
  end

  def item_attack_normal(item)
    target = get_target
    # Se não tem alvo, o alvo é um evento, inimigo morto, ou inimigo vivo fora do alcance
    return if !target || !valid_target?(target) || !in_range?(target, item.range)
    x, y = max_passage(target)
    unless blocked_passage?(target, x, y)
      $server.send_add_projectile(self, x, y, target, Constants::PROJECTILE_SKILL, item.id) if Configs::RANGE_SKILLS.has_key?(item.id)
      target.item_apply(self, item, item.animation_id)
      self.mp -= item.mp_cost
    end
  end

  def item_attack_area(item)
    used = false
    $server.clients.each do |client|
      if client&.in_game? && client.map_id == @map_id && in_range?(client, item.area)
        client.item_apply(self, item, 0)
        used = true
      end
    end
    if used
      self.mp -= item.mp_cost
      $server.send_animation(self, item.animation_id, Constants::TARGET_ENEMY)
    end
  end

  def item_recover(item)
    self.mp -= item.mp_cost
    item_apply(self, item, item.animation_id)
  end

  def send_attack(hp_damage, mp_damage, critical, animation_id)
    $server.send_attack_enemy(@map_id, hp_damage, mp_damage, critical, @id, animation_id)
  end

end
