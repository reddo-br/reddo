require 'java'
require 'jrubyfx'

class RotateTransitionFPSLimited < Java::JavafxAnimation::Transition
  def initialize( fps , dur , node)
    super(fps.to_f)
    setCycleDuration( dur )
    @node = node
    @axis_x = @node.getLayoutBounds().getWidth() / 2
    @axis_y = @node.getLayoutBounds().getHeight() / 2
  end

  def interpolate(frac)
    # @node.getTransforms().setAll( Rotate.new(360 - 360 * frac, @axis_x , @axis_y))
    @node.getTransforms().setAll( Rotate.new(360 * frac, @axis_x , @axis_y))
  end

  def stop()
    super()
    @node.getTransforms().setAll()
  end

end
