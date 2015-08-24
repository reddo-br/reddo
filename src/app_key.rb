# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'
require 'app'

import 'javafx.scene.input.KeyCode'

module AppKey
  def set_key( node )
    node.setOnKeyPressed{|ev|

      page = App.i.active_page
      node.setUserData( nil )
      case [ ev.getCode() , ev.isShiftDown() , ev.isControlDown() ]
      when [ KeyCode::R , false , false ] , [ KeyCode::F5, false , false ]
        key_send( page , :key_reload )
      when [ KeyCode::G, false , false ]
        key_send( page , :key_top )
      when [ KeyCode::G, true , false ], [ KeyCode::G, false , true ]
        key_send( page , :key_buttom )
      when [ KeyCode::J, false , false ]  #, [ KeyCode::S, false , false ] 
        key_send( page , :key_down )
      when [ KeyCode::K, false , false ]  #, [ KeyCode::W, false , false ]
        key_send( page , :key_up )

      when [ KeyCode::H, false , false ] #,  [ KeyCode::A, false , false ]
        App.i.tab_pane.getSelectionModel().selectPrevious()
      when [ KeyCode::L, false , false ] #,  [ KeyCode::D, false , false ]
        App.i.tab_pane.getSelectionModel().selectNext()
        
      when [ KeyCode::F, false , true ]
        key_send( page , :key_next )
      when [ KeyCode::B, false , true ]
        key_send( page , :key_previous)
        
      when [ KeyCode::SPACE, false , false ]
        key_send( page,  :key_space )

      when [ KeyCode::P, false , false ]
        key_send( page,  :key_open_link )

      when [ KeyCode::O, false , false ]
        key_send( page,  :key_open_comment )

      when [ KeyCode::C, false , false ]
        key_send( page,  :key_close )

      when [ KeyCode::A , false , false ]
        key_send( page, :key_add )
        
      when [ KeyCode::H , false , true ]
        key_send( page, :key_hot )
        
      when [ KeyCode::N , false , true ]
        key_send( page, :key_new )
        
      when [ KeyCode::ESCAPE , false , false ]
        page.requestFocus
        
      when [ KeyCode::U , false , false ]
        key_send( page , :key_upvote )

      when [ KeyCode::D , false , false ]
        key_send( page , :key_downvote )
        
      when [ KeyCode::Q , false , true ]
        App.i.stage.close()
        
      # when [ KeyCode::I , false , false ]
      #   key_send( page , :key_input )
        
      end
      
    }
    
    node.setOnKeyTyped{|ev|
      page = App.i.active_page

      case ev.getCharacter
      when "/"
        key_send( page , :key_find )
      when ":"
        if tb = App.i.root.lookup(".app-toolbar")
          key_send( tb , :key_command )
        end
      end
    }

  end
  module_function :set_key
  
  def key_send( tab , name )
    if tab and tab.respond_to?( name )
      Platform.runLater{
        tab.send( name ) 
      }
    end
  end
  module_function :key_send
end
