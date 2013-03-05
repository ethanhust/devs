module DEVS
  module Parallel
    class RootCoordinator < Classic::RootCoordinator
      def simulate
        @real_start_time = Time.now
        info "*** Beginning simulation at #{@real_start_time} with duration:" \
           + "#{duration}"

        child.dispatch(Event.new(:i, @time))
        @time = child.time_next

        loop do
          info "* Tick at: #{@time}, #{Time.now - @real_start_time} secs elapsed"
          child.dispatch(Event.new(:'@', @time))
          child.dispatch(Event.new(:*, @time))
          @time = child.time_next
          break if @time >= @duration
        end

        msg = "*** Simulation ended after #{Time.now - @real_start_time} secs."
        DEVS.logger ? info(msg) : puts(msg)

        info "* Events stats :"
        stats = child.stats
        stats[:total] = stats.values.reduce(&:+)
        info "    OVERALL #{stats}"

        info "* Calling post simulation hooks"
        changed
        notify_observers(:post_simulation)
      end
    end
  end
end
