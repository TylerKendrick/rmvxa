module SingleForwardable
  
  def def_delegator(accessor, method, ali = method)
    context = get_single_context(accessor)
    define_singleton_method(ali, context.method(method))
  end
  alias :def_single_delegator :def_delegator
  
  def def_delegators(accessor, *methods)
    methods.each(&method(:def_delegator))
  end
  alias :def_single_delegators :def_delegators
  
  def single_delegate(hash)
    hash.each { |*methods, accessor| def_delegators(accessor, *methods) }
  end
  alias :delegate :single_delegate
  
  private
  def get_single_context(accessor)
    case accessor
      when ::Symbol
        if accessor.to_s[0] == '@'
          singleton_class.instance_variable_get(accessor)
        else
          singleton_class.method(accessor)
        end
      when ::Object then accessor
    end
  end
end
