module Forwardable
  
  def def_instance_delegators(accessor, *methods)
    methods.each { |x| def_instance_delegator(accessor, x) }
  end
  alias :def_delegators :def_instance_delegators  
  
  def def_instance_delegator(accessor, method, ali = method)
    define_method(ali) { |*args, &block|
      get_instance_context(accessor).send(method, *args, &block)
    }
  end
  alias :def_delegator :def_instance_delegator  

  def instance_delegate(hash)
    hash.each { |*keys, value| def_instance_delegators(value, *keys) }
  end
  alias :delegate :instance_delegate
  
  private
  def get_instance_context(accessor)
    case accessor
      when ::Symbol
        if accessor.first == '@'
          instance_variable_get(accessor)
        else
          method(accessor)
        end
      when ::Object then accessor
    end
  end
end
