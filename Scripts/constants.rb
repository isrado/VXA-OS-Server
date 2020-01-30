#==============================================================================
# ** Constants
#------------------------------------------------------------------------------
#  Este módulo lida com as constantes.
#------------------------------------------------------------------------------
#  Autor: Valentine
#==============================================================================

module Constants
	
	# Sexos
	SEX_MALE   = 0
	SEX_FEMALE = 1

	# Pacotes enviados pelo servidor para o cliente e vice-versa
	PACKET_LOGIN               = 1
	PACKET_FAIL_LOGIN          = 2
	PACKET_NEW_ACCOUNT         = 3
	PACKET_NEW_CHAR            = 4
	PACKET_FAIL_NEW_CHAR       = 5
	PACKET_CHAR                = 6
	PACKET_REMOVE_CHAR         = 7
	PACKET_USE_CHAR            = 8
	PACKET_MOTD                = 9
	PACKET_PLAYER_DATA         = 10
	PACKET_REMOVE_PLAYER       = 11
	PACKET_PLAYER_MOVE         = 12
	PACKET_MAP_MSG             = 13
	PACKET_CHAT_MSG            = 14
	PACKET_ALERT_MSG           = 15
	PACKET_PLAYER_ATTACK       = 16
	PACKET_ATTACK_PLAYER       = 17
	PACKET_ATTACK_ENEMY        = 18
  PACKET_USE_ITEM            = 19
	PACKET_USE_SKILL           = 20
	PACKET_ANIMATION           = 21
	PACKET_CHANGE_HOTBAR       = 22
	PACKET_USE_HOTBAR          = 23
	PACKET_TARGET              = 24
	PACKET_ENEMY_RESPAWN       = 25
	PACKET_EVENT_DATA          = 26
	PACKET_EVENT_MOVE          = 27
	PACKET_ADD_DROP            = 28
	PACKET_REMOVE_DROP         = 29
  PACKET_ADD_PROJECTILE      = 30
	PACKET_PLAYER_VITALS       = 31
	PACKET_PLAYER_EXP          = 32
	PACKET_PLAYER_ITEM         = 33
	PACKET_PLAYER_GOLD         = 34
	PACKET_PLAYER_PARAM        = 35
	PACKET_PLAYER_EQUIP        = 36
	PACKET_PLAYER_SKILL        = 37
	PACKET_PLAYER_CLASS        = 38
	PACKET_PLAYER_GRAPHIC      = 39
	PACKET_PLAYER_POINTS       = 40
	PACKET_TRANSFER            = 41
	PACKET_OPEN_FRIENDS        = 42
	PACKET_ADD_FRIEND          = 43
	PACKET_REMOVE_FRIEND       = 44
	PACKET_OPEN_CREATE_GUILD   = 45
	PACKET_NEW_GUILD           = 46
	PACKET_OPEN_GUILD          = 47
	PACKET_UPDATE_GUILD        = 48
	PACKET_GUILD_LEADER        = 49
	PACKET_GUILD_NOTICE        = 50
	PACKET_REMOVE_GUILD_MEMBER = 51
	PACKET_LEAVE_GUILD         = 52
	PACKET_JOIN_PARTY          = 53
	PACKET_LEAVE_PARTY         = 54
	PACKET_DISSOLVE_PARTY      = 55
	PACKET_SHOW_CHOICES        = 56
	PACKET_CHOICE              = 57
  PACKET_OPEN_BANK           = 58
  PACKET_BANK_ITEM           = 59
  PACKET_BANK_GOLD           = 60
  PACKET_CLOSE_WINDOW        = 61
  PACKET_OPEN_SHOP           = 62
	PACKET_BUY_ITEM            = 63
	PACKET_SELL_ITEM           = 64
	PACKET_OPEN_TELEPORT       = 65
	PACKET_CHOICE_TELEPORT     = 66
  PACKET_REQUEST             = 67
  PACKET_ACCEPT_REQUEST      = 68
  PACKET_DECLINE_REQUEST     = 69
  PACKET_TRADE_ITEM          = 70
  PACKET_TRADE_GOLD          = 71
	PACKET_NEW_QUEST           = 72
	PACKET_FINISH_QUEST        = 73
  PACKET_VIP_DAYS            = 74
  PACKET_LOGOUT              = 75
	PACKET_ADMIN_COMMAND       = 76
	PACKET_SWITCH              = 77
	PACKET_VARIABLE            = 78
	PACKET_SELF_SWITCH         = 79
	PACKET_NET_SWITCHES        = 80
	
	# Grupos
	GROUP_STANDARD = 0
	GROUP_MONITOR  = 1
	GROUP_ADMIN    = 2

	# Conversas do bate-papo
	CHAT_MAP     = 0
	CHAT_GLOBAL  = 1
	CHAT_PARTY   = 2
	CHAT_GUILD   = 3
	CHAT_PRIVATE = 4

	# Entrada
	LOGIN_SERVER_FULL   = 0
	LOGIN_IP_BANNED     = 1
	LOGIN_MULTI_IP      = 2
  LOGIN_OLD_VERSION   = 3
	LOGIN_ACC_BANNED    = 4
	LOGIN_INVALD_USER   = 5
  LOGIN_MULTI_ACCOUNT = 6
	LOGIN_INVALID_PASS  = 7
	LOGIN_IP_BLOCKED    = 8

	# Criação de conta
	REGISTER_ACC_EXIST  = 0
	REGISTER_SUCCESSFUL = 1

	# Alertas
	ALERT_INVALID_NAME     = 0
	ALERT_TELEPORTED       = 1
	ALERT_INVALID_COMMAND  = 3
	ALERT_PULLED           = 4
	ALERT_ATTACK_ADMIN     = 5
	ALERT_BUSY             = 6
	ALERT_IN_PARTY         = 7
	ALERT_IN_GUILD         = 8
	ALERT_GUILD_EXIST      = 9
	ALERT_NOT_GUILD_LEADER = 10 
	ALERT_FULL_GUILD       = 11
	ALERT_NOT_PICK_UP_DROP = 12
	ALERT_REQUEST_DECLINED = 13
	ALERT_TRADE_DECLINED   = 14
	ALERT_FULL_INV         = 15
	ALERT_FULL_TRADE       = 16
	ALERT_FULL_BANK        = 17
	ALERT_MUTED            = 18

	# Direções
	DIR_DOWN_LEFT  = 1
	DIR_DOWN       = 2
	DIR_DOWN_RIGHT = 3
	DIR_LEFT       = 4
	DIR_RIGHT      = 6
	DIR_UP_LEFT    = 7
	DIR_UP         = 8
	DIR_UP_RIGHT   = 9

	# Equipamentos
	EQUIP_WEAPON   = 0
	EQUIP_SHIELD   = 1
	EQUIP_HELMET   = 2
	EQUIP_ARMOR    = 3
	EQUIP_ACESSORY = 4
	EQUIP_AMULET   = 5
	EQUIP_COVER    = 6
	EQUIP_GLOVE    = 7
	EQUIP_BOOT     = 8
	
	# Parâmetros
	PARAM_MAXHP = 0
	PARAM_MAXMP = 1
	PARAM_ATK   = 2
	PARAM_DEF   = 3
	PARAM_MAT   = 4
	PARAM_MDF   = 5
	PARAM_AGI   = 6
	PARAM_LUK   = 7

	# Atalhos
	HOTBAR_NONE  = 0
	HOTBAR_ITEM  = 1
	HOTBAR_SKILL = 2

	# Comandos do painel de administração
	COMMAND_KICK     = 0
	COMMAND_TELEPORT = 1
	COMMAND_GO       = 2
	COMMAND_PULL     = 3
	COMMAND_ITEM     = 4
	COMMAND_WEAPON   = 5
	COMMAND_ARMOR    = 6
  COMMAND_GOLD     = 7
	COMMAND_BAN_IP   = 8
	COMMAND_BAN_ACC  = 9
	COMMAND_UNBAN    = 10
	COMMAND_SWITCH   = 11
	COMMAND_MOTD     = 12
	COMMAND_MUTE     = 13
  COMMAND_MSG      = 14
	
	# Projéteis
	PROJECTILE_WEAPON = 0
	PROJECTILE_SKILL  = 1

	# Escopos dos itens
	ITEM_SCOPE_ENEMY              = 1
	ITEM_SCOPE_ALL_ALLIES         = 8
	ITEM_SCOPE_ALLIES_KNOCKED_OUT = 10
	ITEM_SCOPE_USER               = 11

	# Movimentos dos eventos
	MOVE_RANDOM        = 1
	MOVE_TOWARD_PLAYER = 2
	MOVE_CUSTOM        = 3

	# Alvos
	TARGET_NONE   = 0
	TARGET_PLAYER = 1
	TARGET_ENEMY  = 2

	# Solicitações
	REQUEST_NONE         = 0
  REQUEST_TRADE        = 1
	REQUEST_FINISH_TRADE = 2
	REQUEST_PARTY        = 3
	REQUEST_FRIEND       = 4
	REQUEST_GUILD        = 5

	# Missões
	QUEST_IN_PROGRESS = 0
	QUEST_FINISHED    = 1

end
