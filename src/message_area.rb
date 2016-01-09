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
    @message_err = false
    @mutex = Mutex.new
  end

  def set_message( mes , err = false)
    @mutex.synchronize{
      @message_string = App.i.now + " " + mes
      @message_err = err
      error_color( @message_err )
      @message.setText(@message_string)
    }
  end

  def set_status( sta )
    if sta.to_s.length == 0
      error_color( @message_err )
      @message.setText( @message_string )
    else
      error_color( false )
      @message.setText( sta )
    end
  end

  def error_color( err )
    if err
      @message.setStyle("-fx-text-fill:#{App.i.theme::COLOR::STRONG_RED};")
    else
      @message.setStyle("")
    end
  end

end

