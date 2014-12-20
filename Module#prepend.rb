class Module
  
  def prepend(*mods)
    mods.reverse_each(&method(:prepend_features))
  end
  
  def prepend_features(mod)
    current = self
    meta = class << self; self; end
    return if meta.ancestors.include?(mod)
    old_new = meta.method(:new).unbind
    
    subclass = Class.new(current) do
      extend Forwardable
      include mod;
      define_singleton_method(:new, &old_new.bind(self))
      def_singleton_delegators(meta, :inspect, :to_s)
      def_singleton_delegator(current, :name)
      def_delegators(current, :inspect, :to_s)
    end

    get_ancestors = subclass.method(:ancestors).to_proc
    subclass.send(:define_singleton_method, :ancestors) { 
      get_ancestors.call.drop(1)
    }
    
    define_singleton_method(:new, &subclass.method(:new))
    prepended(mod)
  end
  
  def prepended(mod)
  end
  
end
