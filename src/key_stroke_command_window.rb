# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'

class KeyStrokeCommandWindow < Java::JavafxStage::Stage
  
  def initialize
    super( StageStyle::UNDECORATED)
    # super( ) 
    if App.i.pref['use_dark_theme']
      sceneProperty.addListener{|ev|
        if s = ev.getValue()
          s.getStylesheets().add( App.res_url("/res/dark.css") )
        end
      }
    end

    initModality(Modality::WINDOW_MODAL)
    initOwner( App.i.stage )
    setWidth( 600 )

    root = VBox.new( 10.0 )
    root.setAlignment( Pos::TOP_LEFT )

    @label_title = Label.new()
    @label_title.setAlignment( Pos::TOP_CENTER )
    @label_choices = Label.new()

    root.getChildren().addAll( @label_title , @label_choices )

    root.class.setMargin( @label_title   , Insets.new( 6 , 6 , 6 , 6 ))
    root.class.setMargin( @label_choices , Insets.new( 6 , 6 , 6 , 6 ))
    

    style_string = "-fx-background-color:#{App.i.theme::COLOR::STRONG_GREEN}; -fx-text-fill:#{App.i.theme::COLOR::REVERSE_TEXT}"
    [ root , @label_title , @label_choices ].each{|n| n.setStyle( style_string ) }

    scene = Scene.new(root)
    setScene( scene )

    @choices = []

    scene.setOnKeyTyped{|ev|
      close()
      ch = ev.getCharacter
      if choice = @choices.assoc( ch )
        Platform.runLater{
          choice[2].call
        }
      end
      @choices = []
    }
  end

  def start( message )
    @label_title.setText(message.to_s)
    
    w = App.i.stage.getWidth / 2

    setWidth(w)
    setX( App.i.stage.getX + (App.i.stage.getWidth - w) / 2)
    setY( App.i.stage.getY + (App.i.stage.getHeight / 4) )

    set_choice_texts
    show

  end

  def clear_choices
    @choices = []
    set_choice_texts
  end

  def set_choice_texts
    choices_text = @choices.map{|c,text,proc|
      "[#{c}] #{text}"
    }.join("\n")
    @label_choices.setText( choices_text )
  end

  def add_choice(char,text,&block)
    @choices << [ char , text ,block ]
  end

end

