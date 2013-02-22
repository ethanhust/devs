$:.push File.expand_path('../../lib', __FILE__)

require 'devs'
require 'gnuplot'
require 'csv'

class RandomGenerator < DEVS::Classic::AtomicModel
  def initialize(min = 0, max = 10, min_step = 1, max_step = 1)
    super()

    @min = min
    @max = max
    @min_step = min_step
    @max_step = max_step
    self.sigma = 0
  end

  delta_int { self.sigma = (@min_step + rand * @max_step).round }

  output do
    messages_count = (1 + rand * output_ports.count).round
    selected_ports = output_ports.sample(messages_count)
    selected_ports.each { |port| send((@min + rand * @max).round, port) }
  end

  time_advance { self.sigma }
end

class Collector < DEVS::Classic::AtomicModel
  def initialize
    super()
    @results = {}
  end

  external_transition do
    input_ports.each do |port|
      value = retrieve(port)

      if @results.has_key?(port.name)
        ary = @results[port.name]
      else
        ary = []
        @results[port.name] = ary
      end

      ary << [self.time, value] unless value.nil?
    end

    self.sigma = 0
  end

  internal_transition { self.sigma = DEVS::INFINITY }

  time_advance { self.sigma }
end

class PlotCollector < Collector
  post_simulation_hook do
    Gnuplot.open do |gp|
      Gnuplot::Plot.new(gp) do |plot|

        #plot.terminal 'png'
        #plot.output File.expand_path("../#{self.name}.png", __FILE__)

        plot.title  self.name
        plot.ylabel "events"
        plot.xlabel "time"

        @results.each { |key, value|
          x = []
          y = []
          @results[key].each { |a| x << a.first; y << a.last }
          plot.data <<  Gnuplot::DataSet.new([x, y]) do |ds|
            ds.with = "lines"
            ds.title = key
          end
        }
      end
    end
  end
end

class CSVCollector < Collector
  post_simulation_hook do
    content = CSV.generate do |csv|
      columns = []
      @results.keys.each { |column| columns << "time"; columns << column }
      csv << columns

      values = []
      @results.each { |key, value|
        y = []
        x = []
        @results[key].each { |a| x << a.first; y << a.last }
        values << x
        values << y
      }

      max = values.map { |column| column.size }.max
      0.upto(max) do |i|
        row = []
        values.each { |column| row << (column[i].nil? ? 0 : column[i]) }
        csv << row
      end
    end
    File.open("#{self.name}.csv", 'w') { |file| file.write(content) }
  end
end

#DEVS.logger = nil

# require 'perftools'
# PerfTools::CpuProfiler.start("/tmp/ground_simulation") do
DEVS.simulate do
  duration 100

  atomic(RandomGenerator, 0, 5) { name :random }

  select { |imm| imm.last }

  atomic do
    name :ground

    init do
      @pluviometrie = 0
      @cc = 40.0
      @out_flow = 5.0
      @ruissellement = 0
    end

    delta_ext do
      input_ports.each do |port|
        value = retrieve(port)
        @pluviometrie += value unless value.nil?
      end

      @pluviometrie = [@pluviometrie - (@pluviometrie * (@out_flow / 100)), 0].max

      if @pluviometrie > @cc
        @ruissellement = @pluviometrie - @cc
        @pluviometrie = @cc
      end

      self.sigma = 0
    end

    delta_int {
      @ruissellement = 0
      self.sigma = DEVS::INFINITY
    }

    output do
      send(@pluviometrie, output_ports.first)
      send(@ruissellement, output_ports.last)
    end

    time_advance { self.sigma }
  end

  atomic(PlotCollector) { name :plot_output }
  atomic(CSVCollector) { name :csv_output }

  add_internal_coupling(:random, :ground)
  add_internal_coupling(:ground, :plot_output, :pluviometrie, :pluviometrie)
  add_internal_coupling(:ground, :plot_output, :ruissellement, :ruissellement)
  add_internal_coupling(:ground, :csv_output, :pluviometrie, :pluviometrie)
  add_internal_coupling(:ground, :csv_output, :ruissellement, :ruissellement)
end
#end

