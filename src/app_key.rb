# -*- coding: utf-8 -*-
require 'java'
require 'jrubyfx'
require 'app'

import 'javafx.scene.input.KeyCode'

module AppKey
  module_function
  def set_key( node )
    node.setOnKeyPressed{|ev|

      page = App.i.active_page
      node.setUserData( nil )
      case [ ev.getCode() , ev.isShiftDown() , ev.isControlDown() , ev.isAltDown() ]
      when [ KeyCode::R , false , false , false] , [ KeyCode::F5, false , false , false]
        key_send( page , :key_reload )
      when [ KeyCode::G, false , false , false]
        key_send( page , :key_top )
      when [ KeyCode::G, true , false , false], [ KeyCode::G, false , true , false]
        key_send( page , :key_buttom )
      when [ KeyCode::J, false , false , false] 
        key_send( page , :key_down )
      when [ KeyCode::K, false , false , false]
        key_send( page , :key_up )

      when [ KeyCode::H, false , false , false]
        model = App.i.tab_pane.getSelectionModel()
        if model.getSelectedIndex == 0
          model.selectLast
        else
          model.selectPrevious()
        end
      when [ KeyCode::L, false , false , false] #,  [ KeyCode::D, false , false ]
        model = App.i.tab_pane.getSelectionModel()
        if model.getSelectedIndex == model.getItemCount() - 1
          model.selectFirst()
        else
          model.selectNext()
        end
        
      when [ KeyCode::H, true , false , false] 
        page.tab_move( -1 )
      when [ KeyCode::L, true , false , false] 
        page.tab_move(  1 )

      when [ KeyCode::F, false , true , false]
        key_send( page , :key_next )
      when [ KeyCode::B, false , true , false]
        key_send( page , :key_previous)
        
      when [ KeyCode::CLOSE_BRACKET, false , false , false]
        key_send( page , :key_next_paragraph )
      when [ KeyCode::OPEN_BRACKET, false , false , false]
        key_send( page , :key_previous_paragrah)
        
      when [ KeyCode::SPACE, false , false , false]
        key_send( page,  :key_space )

      when [ KeyCode::P, false , false , false]
        key_send( page,  :key_open_link )

      when [ KeyCode::P, true , false , false]
        key_send( page,  :key_open_link_alt )

      when [ KeyCode::O, false , false , false]
        key_send( page,  :key_open_comment )

      when [ KeyCode::O, true , false , false]
        key_send( page,  :key_open_comment_without_focus )

      when [ KeyCode::S, false , false , false]
        key_send( page,  :key_open_sub )

      when [ KeyCode::S, true , false , false]
        key_send( page,  :key_open_sub_without_focus )

      when [ KeyCode::C, false , false , false]
        key_send( page,  :key_close )

      when [ KeyCode::C, true , false , false]
        key_send( page,  :key_close_focus_next )

      when [ KeyCode::C, false , false , true]
        App.i.close_pages{|p| not p.pinned }

      when [ KeyCode::A , false , false , false]
        key_send( page, :key_add )
        
      when [ KeyCode::H , false , true , false]
        key_send( page, :key_hot )
        
      when [ KeyCode::N , false , true , false]
        key_send( page, :key_new )
        
      when [ KeyCode::ESCAPE , false , false , false]
        page.requestFocus
        if btn = App.i.root.lookup(".inbox-button")
          btn.setSelected(false)
        end
      when [ KeyCode::U , false , false , false]
        key_send( page , :key_upvote )

      when [ KeyCode::D , false , false , false]
        key_send( page , :key_downvote )
        
      when [ KeyCode::Q , false , true , false]
        App.i.stage.close()
        
      # when [ KeyCode::I , false , false ]
      #   key_send( page , :key_input )
        
      when [ KeyCode::DIGIT1 , false , false ,false] # alt-1
        select_tab(0)
      when [ KeyCode::DIGIT2 , false , false ,false] 
        select_tab(1)
      when [ KeyCode::DIGIT3 , false , false ,false]
        select_tab(2)
      when [ KeyCode::DIGIT4 , false , false ,false]
        select_tab(3)
      when [ KeyCode::DIGIT5 , false , false ,false]
        select_tab(4)
      when [ KeyCode::DIGIT6 , false , false ,false]
        select_tab(5)
      when [ KeyCode::DIGIT7 , false , false ,false]
        select_tab(6)
      when [ KeyCode::DIGIT8 , false , false ,false]
        select_tab(7)
      when [ KeyCode::DIGIT9 , false , false ,false]
        select_tab(8)
      when [ KeyCode::DIGIT0 , false , false ,false]
        select_tab(9)

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
  
  def select_tab(num)
    model = App.i.tab_pane.getSelectionModel()
    model.select( num )
  end

  def key_send( tab , name )
    if tab and tab.respond_to?( name )
      Platform.runLater{
        tab.send( name ) 
      }
    end
  end
end
