require 'rspec'
require 'rr'

def stub_module(full_name)
  full_name.to_s.split(/::/).inject(Object) do |context, name|
    begin
      context.const_get(name)
    rescue NameError
      context.const_set(name, Module.new)
    end
  end
end

def stub_class(full_name)
  full_name.to_s.split(/::/).inject(Object) do |context, name|
    begin
      context.const_get(name)
    rescue NameError
      if /#{name}$/ =~ full_name
        context.const_set(name, Class.new)
      else
        context.const_set(name, Module.new)
      end
    end
  end
end
