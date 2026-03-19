namespace :homekit do
  desc "Sync HomeKit structure from Prefab"
  task sync: :environment do
    puts "Starting HomeKit sync from Prefab..."
    summary = HomekitSync.perform
    puts "✅ Sync complete!"
    puts "   Homes: #{summary[:homes]}"
    puts "   Rooms: #{summary[:rooms]}"
    puts "   Accessories: #{summary[:accessories]}"
    puts "   Scenes: #{summary[:scenes]}"
  end
end
