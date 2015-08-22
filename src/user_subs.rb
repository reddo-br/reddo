require 'redd_patched'

class UserSubs

  def initialize( account_name , &load_cb)
    @account_name = account_name
    load_thread( &load_cb )
    @subscribes = []
    @multis = []
    @loaded = false
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
    cl = App.i.prepare_client( @account_name )
    Thread.new{
      sub_thread = Thread.new{
        begin
          subscribes = get_all_subscribes( cl )
          subscribes.each{|sub|
            @subscribes << sub[:display_name]
          }
        rescue

        end
      }

      multi_thread = Thread.new{
        begin
          multis = cl.my_multis
          multis.each{|m|
            @multis << ".." + multis[:path]
          }
        rescue

        end
      }

      sub_thread.join
      multi_thread.join
      @loaded = true
      laod_cb.call if load_cb
    }
  end

end
