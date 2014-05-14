module DEVS
  module Builders
    class CoupledBuilder
      include BaseBuilder

      def initialize(parent, namespace, dsl_type, klass, *args, &block)
        @model = if klass.nil? || !klass.respond_to?(:new)
          CoupledModel.new
        else
          klass.new(*args)
        end
        parent.model << @model

        @namespace = namespace
        @dsl_type = dsl_type
        @processor = Coordinator.new(@model, namespace)
        parent.processor << @processor

        case dsl_type
        when :eval then instance_eval(&block)
        when :yield then block.call(self)
        end if block
      end

      # @return [CoupledModel] the new coupled model
      def add_coupled_model(*args, &block)
        type = nil
        type, *args = *args if args.first != nil && args.first.respond_to?(:new)

        CoupledBuilder.new(self, @namespace, @dsl_type, type, *args, &block).model
      end

      # @return [AtomicModel] the new atomic model
      def add_model(type=nil, opts={}, &block)
        AtomicBuilder.new(self, @namespace, @dsl_type, type, opts[:name], *opts[:with_args], &block).model
      end

      def select(&block)
        @model.define_singleton_method(:select, &block) if block
      end

      def plug(child, opts={})
        a, from = child.split('@')
        b, to = opts[:with].split('@')
        @model.add_internal_coupling(a.to_sym, b.to_sym, from.to_sym, to.to_sym)
      end

      def plug_output_port(port, opts={})
        plug_port(port, :output, opts)
      end

      def plug_input_port(port, opts={})
        plug_port(port, :input, opts)
      end

      def plug_port(port, type, opts)
        blk = Proc.new do |id|
          child, child_port = id.split('@')

          if type == :input
            @model.add_external_input_coupling(child.to_sym, port.to_sym, child_port.to_sym)
          elsif type == :output
            @model.add_external_output_coupling(child.to_sym, port.to_sym, child_port.to_sym)
          end
        end

        if opts.has_key?(:with_children)
          opts[:with_children].each { |id| blk.(id) }
        else
          blk.(opts[:with_child])
        end
      end
      private :plug_port
    end
  end
end
