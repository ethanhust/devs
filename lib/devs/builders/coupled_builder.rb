module DEVS
  class CoupledBuilder
    include BaseBuilder

    def initialize(parent, klass, name: nil, with_args: [], &block)
      @model = if klass.nil? || !klass.respond_to?(:new)
        CoupledModel.new(name)
      else
        klass.new(name, *with_args)
      end
      parent.model << @model
      instance_eval(&block) if block
    end

    # @return [CoupledModel] the new coupled model
    def add_coupled_model(type=nil, name: nil, with_args: [], &block)
      CoupledBuilder.new(self, type, name: name, with_args: with_args, &block)
    end

    # @return [AtomicModel] the new atomic model
    def add_model(type=nil, name: nil, with_args: {}, &block)
      AtomicBuilder.new(self, type, name: name, with_args: with_args, &block)
    end

    def select(&block)
      @model.define_singleton_method(:select, &block) if block
    end

    def attach(p1, to:, between: nil, and: nil)
      @model.attach(p1, to: to, between: between, and: binding.local_variable_get(:and))
    end

    def attach_input(myport, to:, of:)
      @model.attach_input(myport, to: to, of: of)
    end

    def attach_output(oport, of:, to:)
      @model.attach_output(oport, of: of, to: to)
    end

    # @deprecated Use {#attach} instead
    def plug(child, opts={})
      a, from = child.split('@')
      b, to = opts[:with].split('@')
      @model.add_internal_coupling(a.to_sym, b.to_sym, from.to_sym, to.to_sym)
    end

    # @deprecated Use {#attach_output} instead
    def plug_output_port(port, opts={})
      plug_port(port, :output, opts)
    end

    # @deprecated Use {#attach_input} instead
    def plug_input_port(port, opts={})
      plug_port(port, :input, opts)
    end

    def plug_port(port, type, opts)
      list = opts.has_key?(:with_children) ? opts[:with_children] : [opts[:with_child]]
      i = 0
      while i < list.size
        child, child_port = list[i].split('@')
        if type == :input
          @model.add_external_input_coupling(child.to_sym, port.to_sym, child_port.to_sym)
        elsif type == :output
          @model.add_external_output_coupling(child.to_sym, port.to_sym, child_port.to_sym)
        end
        i+=1
      end
    end
    private :plug_port
  end
end
