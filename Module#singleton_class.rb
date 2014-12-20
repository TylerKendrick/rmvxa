class ::Module

  def singleton_class
    case self
      when nil? then ::NilClass
      when true then ::TrueClass
      when false then ::FalseClass
      when ::FixNum, ::Symbol then raise TypeError.new
      else; class << self; self; end
    end
  end
  
end
