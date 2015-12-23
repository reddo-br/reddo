# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

require 'app'

class ProgressDialog < Java::JavafxStage::Stage
  
  def initialize(title , message , width:300 , height:200 , &proc)
    super()

    @proc = proc
    @thread = nil

    if App.i.pref['use_dark_theme']
      sceneProperty.addListener{|ev|
        if s = ev.getValue()
          s.getStylesheets().add( App.res_url("/res/dark.css") )
        end
      }
    end
    
    initModality(Modality::WINDOW_MODAL)
    initOwner( App.i.stage)

    setTitle(title)

    setWidth( width )
    setHeight( height )

    root = BorderPane.new
    root.setPadding( Insets.new( 6.0, 6.0, 6.0, 6.0 ))

    message_area = VBox.new( 5.0)
    message_area.setAlignment( Pos::TOP_CENTER )
    
    @label_message = Label.new( message )
    @label_message.setWrapText( true )
    message_area.add( @label_message )

    @result_message = Label.new( "" )
    @result_message.setWrapText( true )
    message_area.add( @result_message )
    
    root.setCenter( message_area )

    indicator_button_area = BorderPane.new
    
    @indicator = ProgressIndicator.new
    @indicator.setPrefHeight( 20 )
    @indicator.setPrefHeight( 20 )
    @indicator.setVisible( false )
    @indicator.setProgress(-1)
    indicator_button_area.setLeft( @indicator )
    
    buttons = HBox.new
    
    @start_button = Button.new("開始")
    @start_button.setOnAction{|ev|
      if @process_done
        close
      else
        @start_button.setDisable(true)
        @result_message.setText("処理中…")
        @indicator.setVisible(true)
        @thread = Thread.new{
          begin
            result = @proc.call
            Platform.runLater{
              @cancel_button.setDisable(true)
              @process_done = true
              @start_button.setText("閉じる")
              @start_button.setDisable(false)
              @result_message.setText(result.to_s)
              @indicator.setVisible(false)
            }
          rescue
            $stderr.puts $!
            $stderr.puts $@

            Platform.runLater{
              @result_message.setText("エラー")
              @start_button.setDisable(false)
              @indicator.setVisible(false)
            }
          end
        }
      end
    }
    buttons.add( @start_button )

    @cancel_button = Button.new("キャンセル")
    @cancel_button.setOnAction{
      if @thread and @thread.alive?
        @thread.kill
      end
      close
    }
    
    buttons.add( @cancel_button )
    indicator_button_area.setRight( buttons )

    root.setBottom( indicator_button_area )

    setScene( Scene.new(root))
    ######
  end
    
end
