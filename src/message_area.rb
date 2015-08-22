require 'java'
require 'jrubyfx'

require 'pref/preferences'
require 'app'

require 'thread'

class MessageArea < Java::JavafxSceneLayout::HBox
  include JRubyFX::DSLControl
  
  def initialize
    super()
    setId(App::ID_MESSAGE_AREA)
    @message = Label.new("")
    @message_string = ""
    getChildren().add( @message)
    
    @mutex = Mutex.new
  end

  def set_message( mes )
    @mutex.synchronize{
      @message_string = mes
      @message.setText(mes)
    }
  end

  def set_status( sta )
    if sta.to_s.length == 0
      @message.setText( @message_string )
    else
      @message.setText( sta )
    end
  end

end

