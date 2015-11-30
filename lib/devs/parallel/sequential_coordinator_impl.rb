module DEVS
  module SequentialParallel
    module CoordinatorImpl
      def init(time)
        @influencees = Hash.new { |hsh, key| hsh[key] = {} }
        @synchronize = {}
        @parent_bag = {}
        @bag = {}

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
        @scheduler = if DEVS.scheduler == SortedList || DEVS.scheduler == MinimalList
          DEVS.scheduler.new(@children)
        else
          DEVS.scheduler.new(selected)
        end

        @time_last = max_time_last
        @time_next = min
      end

      def collect(time)
        if time != @time_next
          raise BadSynchronisationError, "\ttime: #{time} should match time_next: #{@time_next}"
        end
        @time_last = time

        @bag.clear
        imm = @scheduler.pop_simultaneous
        # imm = if DEVS.scheduler == SortedListScheduler || DEVS.scheduler == MinimalListScheduler
        #   read_imminent_children
        # else
        #   imminent_children
        # end

        i = 0
        while i < imm.size
          child = imm[i]
          @bag.merge!(child.collect(time))
          @synchronize[child] = true
          i += 1
        end

        # keep internal couplings and send EOC up
        @parent_bag.clear

        @bag.each do |port, payload|
          # check internal coupling to get children who receive sub-bag of y
          i = 0
          ic = @model.internal_couplings(port)
          while i < ic.size
            coupling = ic[i]
            receiver = coupling.destination.processor
            @influencees[receiver][coupling.destination_port] = payload
            @synchronize[receiver] = true
            i += 1
          end

          # check external coupling to form sub-bag of parent output
          i = 0
          oc = @model.output_couplings(port)
          while i < oc.size
            @parent_bag[oc[i].destination_port] = payload
            i += 1
          end
        end

        @parent_bag
      end

      def remainder(time, bag)
        bag.each do |port, payload|
          # check external input couplings to get children who receive sub-bag of y
          i = 0
          ic = @model.input_couplings(port)
          while i < ic.size
            coupling = ic[i]
            receiver = coupling.destination.processor
            @influencees[receiver][coupling.destination_port] = payload
            @synchronize[receiver] = true
            i += 1
          end
        end

        influencees = @synchronize.keys
        i = 0
        while i < influencees.size
          receiver = influencees[i]
          sub_bag = @influencees[receiver]
          if DEVS.scheduler == SortedList || DEVS.scheduler == MinimalList
            receiver.remainder(time, sub_bag)
          else
            tn = receiver.time_next
            # before trying to cancel a receiver, test if time is not strictly
            # equal to its time_next. If true, it means that its model will
            # receiver either an internal_transition or a confluent transition,
            # and that the receiver is no longer in the scheduler
            @scheduler.delete(receiver) if tn < DEVS::INFINITY && time != tn
            tn = receiver.remainder(time, sub_bag)
            @scheduler.push(receiver) if tn < DEVS::INFINITY
          end
          sub_bag.clear
          i += 1
        end
        @scheduler.reschedule! if DEVS.scheduler == SortedList || DEVS.scheduler == MinimalList
        @synchronize.clear

        @time_last = time
        @time_next = min_time_next
      end
    end
  end
end
