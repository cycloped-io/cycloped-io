#!/usr/bin/env ruby

$:.unshift "lib"

require 'csv'
require 'progress'

path = ARGV[0]

file = CSV.open(path, 'r')


sss = File.open(path, 'r')
size=sss.size
sss.close
Progress.start(size)


stats = Hash.new(0)

counter = 0

file.each do |row|
  counter += 1
  Progress.set(file.pos)
  heads = row[-7..-1]
  #p heads
  c = 0
  heads.each_with_index do |head, index|
    if not head.nil?
      stats['Head method '+index.to_s] += 1
      c+=1
    end
  end
  stats['Found '+c.to_s+' heads'] += 1

end
Progress.stop

p stats
p counter

puts '|  | Category count |'
puts '| --- | --- |'
stats.sort_by{|k, _| k}.reverse.each do |k,count|
  puts '| '+ k + ' | ' + count.to_s + ' |'
end
puts '| All | '+counter.to_s+' |'

# {"head_0"=>849722, "head_1"=>849722, "head_4"=>789387, "head_6"=>848441, "sum_4"=>209891, "head_2"=>580463, "head_3"=>580463, "head_5"=>580150, "sum_7"=>579808, "sum_6"=>338, "sum_3"=>58722, "sum_2"=>967}
#849726

#{"sum_0"=>1922, "head_0"=>67912, "head_1"=>67912, "head_2"=>59257, "head_3"=>59257, "head_4"=>59323, "head_5"=>35994, "head_6"=>67910, "sum_7"=>35781, "sum_6"=>15674, "sum_4"=>8063, "sum_1"=>20, "sum_5"=>7800, "sum_3"=>594}
#69854
