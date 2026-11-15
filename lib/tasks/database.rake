# frozen_string_literal: true

desc 'Write every row to a file as JSON lines, to move a server between SQLite and PostgreSQL'
task :export_database, [:path] => :environment do |_task, args|
  counts = File.open(args.fetch(:path), 'w', 0o600) { |file| Database::Export.call(file) }
  puts "Exported #{counts.map { |table, count| "#{count} #{table}" }.join(', ')}."
end

desc 'Read rows written by export_database, skipping the ones already here'
task :import_database, [:path] => :environment do |_task, args|
  counts = File.open(args.fetch(:path)) { |file| Database::Import.call(file) }
  puts "Imported #{counts.map { |table, count| "#{count} #{table}" }.join(', ')}."
end
