
counts = HomekitEvent.group(:accessory_name, :characteristic, :value).count
duplicates = counts.select { |k, v| v > 1 }.sort_by { |k, v| -v }
puts "Top duplicate events (Accessory | Characteristic | Value | Count):"
duplicates.first(20).each do |(acc, char, val), count|
  puts "#{acc} | #{char} | #{val} | #{count}"
end

total_events = HomekitEvent.count
duplicate_count = duplicates.sum { |k, v| v - 1 }
puts "\nTotal Events: #{total_events}"
puts "Potential Duplicates (same value consecutive or not): #{duplicate_count}"
puts "Percentage: #{(duplicate_count.to_f / total_events * 100).round(2)}%"

puts "\nChecking consecutive duplicates with 1s window (noisy bursts)..."
consecutive_within_1s = 0

HomekitEvent.order(timestamp: :asc).group_by { |e| [ e.accessory_name, e.characteristic ] }.each do |key, events|
  events.each_cons(2) do |e1, e2|
    if e1.value == e2.value && (e2.timestamp - e1.timestamp <= 1.second)
      consecutive_within_1s += 1
    end
  end
end

puts "Consecutive Duplicates (<= 1s): #{consecutive_within_1s}"
puts "Percentage of Total: #{(consecutive_within_1s.to_f / total_events * 100).round(2)}%"
