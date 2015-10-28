require 'optparse'

class CommandlineOptions
  def initialize(args)
    set_default

    parser = OptionParser.new{|opt|
      opt.on("-d","--discard-session"){
        @discard_session = true
      }
    }
    parser.parse!(args)
  end

  def set_default
    @discard_session = false
  end
  attr_reader :discard_session

end

