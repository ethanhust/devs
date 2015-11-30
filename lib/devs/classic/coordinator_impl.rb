module DEVS
  module Classic
    module CoordinatorImpl
      # Handles init (i) messages
      #
      # @param time
      def init(time)
        @bag = {}
        @parent_bag = {}

        i = 0
        selected = []
        min = DEVS::INFINITY
        while i < @children.size
          child = @children[i]
          tn = child.init(time)
          selected.push(child) if tn < DEVS::INFINITY
          min = tn if tn < min
          i += 1
        end

        @scheduler = if DEVS.scheduler == MinimalList || DEVS.scheduler == SortedList
          DEVS.scheduler.new(@children)
        else
          DEVS.scheduler.new(selected)
        end

        @time_last = max_time_last
        @time_next = min
      end

      # Handles internal (*) messages
      #
      # @param time
      # @raise [BadSynchronisationError] if the time is not equal to
      #   {Coordinator#time_next}
      def internal_message(time)
        if time != @time_next
          raise BadSynchronisationError,
                "time: #{time} should match time_next: #{@time_next}"
        end

        imm = if DEVS.scheduler == MinimalList || DEVS.scheduler == SortedList
          @scheduler.peek_simultaneous
        else
          @scheduler.pop_simultaneous
        end

        child = if imm.size > 1
          model.select(imm.map(&:model)).processor
        else
          imm.first
        end

        if DEVS.scheduler == MinimalList || DEVS.scheduler == SortedList
          @bag.merge!(child.internal_message(time))
        else
          i = 0
          while i < imm.size
            c = imm[i]
            @scheduler.enqueue(c) unless c == child
            i += 1
          end
          @bag.merge!(child.internal_message(time))
          @scheduler.enqueue(child) if child.time_next < DEVS::INFINITY
        end

        # handle child output bag
        @parent_bag.clear
        @bag.each do |port, value|
          eoc = @model.output_couplings(port)
          ic = @model.internal_couplings(port)

          i = 0
          while i < eoc.size
            @parent_bag[eoc[i].destination_port] = value
            i += 1
          end

          i = 0
          while i < ic.size
            coupling = ic[i]
            child = coupling.destination.processor
            if DEVS.scheduler == MinimalList || DEVS.scheduler == SortedList
              child.handle_input(time, value, coupling.destination_port)
            else
              @scheduler.delete(child) if child.time_next < DEVS::INFINITY
              child.handle_input(time, value, coupling.destination_port)
              @scheduler.enqueue(child) if child.time_next < DEVS::INFINITY
            end
            i += 1
          end
        end

        @bag.clear
        @scheduler.reschedule! if DEVS.scheduler == MinimalList || DEVS.scheduler == SortedList
        @time_last = time
        @time_next = min_time_next

        @parent_bag
      end

      # Handles input (x) messages
      #
      # @param time
      # @param payload [Object]
      # @param port [Port]
      # @raise [BadSynchronisationError] if the time isn't in a proper
      #   range, e.g isn't between {Coordinator#time_last} and
      #   {Coordinator#time_next}
      def handle_input(time, payload, port)
        if @time_last <= time && time <= @time_next
          eic = @model.input_couplings(port)
          i = 0
          while i < eic.size
            coupling = eic[i]
            child = coupling.destination.processor
            if DEVS.scheduler == MinimalList || DEVS.scheduler == SortedList
              child.handle_input(time, payload, coupling.destination_port)
            else
              @scheduler.delete(child) if child.time_next < DEVS::INFINITY
              child.handle_input(time, payload, coupling.destination_port)
              @scheduler.enqueue(child) if child.time_next < DEVS::INFINITY
            end
            i += 1
          end
          @scheduler.reschedule! if DEVS.scheduler == MinimalList || DEVS.scheduler == SortedList

          @time_last = time
          @time_next = min_time_next
        else
          raise BadSynchronisationError, "time: #{time} should be between time_last: #{@time_last} and time_next: #{@time_next}"
        end
      end
    end
  end
end
