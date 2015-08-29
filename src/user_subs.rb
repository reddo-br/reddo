require 'redd_patched'

class UserSubs

  def initialize( account_name , &load_cb)
    @account_name = account_name
    @loaded = false
    load_thread( &load_cb )
  end
  attr_reader :subscribes , :multis , :loaded , :account_name
  
  def get_all_subscribes(cl , current = [] , after = nil)
    subs_raw = cl.get('/subreddits/mine/subscriber' , :limit => 100 , :after => after).body
    subs  = cl.object_from_body( subs_raw )
    if subs.length == 0
      current
    else
      current += subs
      get_all_subscribes( cl , current , subs.last[:name] )
    end
  end

  def load_thread( &load_cb )
    @subscribes = []
    @multis = []
    cl = App.i.client( @account_name )
    Thread.new{
      sub_thread = Thread.new{
        begin
          ss = get_all_subscribes( cl )
          ss = ss.sort_by{|e| e[:display_name].downcase }
          # $stderr.puts "***** subscribes #{ss}"
          ss.each{|sub|
            App.i.subs_data_hash[ sub[:display_name] ] = sub
            @subscribes << sub[:display_name]
          }
        rescue
          $stderr.puts $!
          $stderr.puts $@
        end
      }

      multi_thread = Thread.new{
        begin
          mul = cl.my_multis
          # $stderr.puts "***** mulits #{mul}"
          mul = mul.sort_by{|e| e[:display_name].downcase }
          mul.each{|m|
            @multis << ".." + m[:path]
          }
        rescue
          $stderr.puts $!
          $stderr.puts $@
        end
      }

      sub_thread.join
      multi_thread.join
      @loaded = true
      load_cb.call(self) if load_cb
    }
  end

end
