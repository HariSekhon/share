#!/usr/bin/env ruby

require "rubygems"
require "optparse"
require "rest-client"
require "json"

EXIT_OK = 0
EXIT_WARNING = 1
EXIT_CRITICAL = 2
EXIT_UNKNOWN = 3

@@options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)} [options]"

  @@options[:url] = nil
  opts.on("-u", "--url URL", "Target url") do |url|
    @@options[:url] = url
  end
  @@options[:metric] = nil
  opts.on("-m", "--metric NAME", "Metric path string") do |metric|
    @@options[:metric] = metric
  end
  @@options[:label]     = nil
  opts.on("-l", "--label ", "Label to use for the check") do |label|
    @@options[:label] = label
  end
  @@options[:shortname] = nil
  opts.on("-s", "--shortname SHORTNAME", "Metric short name (used for performance data)") do |shortname|
    @@options[:shortname] = shortname
  end
  @@options[:duration] = 5
  opts.on("-d", "--duration LENGTH", "Length, in minute of data to parse (default: 5)") do |duration|
    @@options[:duration] = duration
  end
  @@options[:function] = "average"
  opts.on("-f", "--function \[average \| sum\]", "Function applied to metrics for thresholds (default: average)") do |function|
    @@options[:function] = function
  end
  @@options[:warning] = nil
  opts.on("-w", "--warning VALUE", "Warning threshold") do |warning|
    @@options[:warning] = warning
  end
  @@options[:critical] = nil
  opts.on("-c", "--critical VALUE", "Critical threshold") do |critical|
    @@options[:critical] = critical
  end
  opts.on( "-h", "--help", "Display this screen" ) do
    puts opts
    exit
  end
end

optparse.parse!

if (@@options[:url].nil? || @@options[:metric].nil? || @@options[:warning].nil? || @@options[:critical].nil?)
  puts optparse
  exit 2
end

def url
  base_url = @@options[:url]
  metric = @@options[:metric]
  duration = @@options[:duration].to_s
  base_url + "/render/?target=" + metric + "&format=json&from=-" + duration + "mins"
end

data = {}
data["total"] = 0

JSON.parse(RestClient.get(URI.encode(url))).each do |cache|
  data["#{cache['target']}"] = 0
  count = 0
  cache["datapoints"].each do |point|
    unless (point[0].nil?)
      data["#{cache['target']}"] += point[0]
      count += 1
    end
  end
  if (count == 0)
    count = 1
  end
  if (@@options[:function] == "average")
    data["#{cache['target']}"] /= count  
  end
  data["total"] += data["#{cache['target']}"]
end

total = data["total"].to_i
perfdata = ""
perfdata = "| #{@@options[:shortname]}=#{total}" if !@@options[:shortname].nil?
label = @@options[:label] << ',' || 'Metric'

if (@@options[:critical].to_i > @@options[:warning].to_i)
  if (total >= @@options[:critical].to_i)
    puts "CRITICAL: %s value: #{total} #{perfdata}" % [ label ]
    exit EXIT_CRITICAL
  elsif (total >= @@options[:warning].to_i)
    puts "WARNING: %s value: #{total} #{perfdata}" % [ label ]
    exit EXIT_WARNING
  else
    puts "OK: %s value: #{total} #{perfdata}" % [ label ]
    exit EXIT_OK
  end
else
  if (total <= @@options[:critical].to_i)
    puts "CRITICAL: %s value: #{total} #{perfdata}" % [ label ]
    exit EXIT_CRITICAL
  elsif (total <= @@options[:warning].to_i)
    puts "WARNING: %s value: #{total} #{perfdata}" % [ label ]
    exit EXIT_WARNING
  else
    puts "OK: %s value: #{total} #{perfdata}" % [ label ]
    exit EXIT_OK
  end
end

