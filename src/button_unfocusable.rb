require 'java'
require 'jrubyfx'

require 'jruby/core_ext'

class ButtonUnfocusable < Java::JavafxSceneControl::Button
  include JRubyFX::DSLControl

  java_signature 'void requestFocus()'
  def requestFocus()
    # do nothing
  end
  become_java!
end
