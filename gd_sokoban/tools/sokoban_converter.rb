require 'json'
require 'fileutils'

def parse_and_save_levels
  current_level = []
  level_number = 1

  ARGF.each_line do |line|
    line = line.rstrip

    next if line.empty? || line.start_with?(";") 

    if line.start_with?("Title:")
      process_level(level_number, current_level)
      current_level = []
      level_number += 1
    elsif line.match(/^.+\:/) 
      next
    else
      current_level << line.chars
    end
  end

  if !current_level.empty?
    process_level(level_number, current_level)
  end
end

def process_level(number, level_data)
  max_length = level_data.map(&:length).max

  level_data.each do |row|
    row.fill(' ', row.length...max_length)
  end

  save_level_as_json(number, level_data)
end

def save_level_as_json(number, level_data)
  file_name = format("%03d.json", number)

  converted_level = level_data.map do |row|
    row.map do |char|
      case char
      when '#' then 'wall'
      when ' ' then 'floor'
      when '.' then 'goal'
      when '@' then 'player'
      when '$' then 'box'
      else nil
      end
    end.compact
  end

  File.open(file_name, 'w') do |f|
    json_data = {
      level: converted_level
    }
    f.write(JSON.pretty_generate(json_data))
  end
end

if __FILE__ == $0
  parse_and_save_levels
end
