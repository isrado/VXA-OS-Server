#==============================================================================
# ** Scripts
#------------------------------------------------------------------------------
#  Executa os scripts Configs e Quests do cliente.
#------------------------------------------------------------------------------
#  Autor: Valentine
#==============================================================================

class Font
  
	def self.default_name=(name)
	end
	
	def self.default_outline=(name)
	end

	def self.default_shadow=(name)
	end

  def self.default_bold=(bold)
  end

  def self.default_italic=(italic)
  end

  def self.default_color=(color)
	end
	
  def self.default_size=(size)
  end
	
end

scripts = load_data('Scripts.rvdata2')
# Executa os scripts Configs e Quests
eval(Zlib::Inflate.inflate(scripts[1][2]))
eval(Zlib::Inflate.inflate(scripts[2][2]))
