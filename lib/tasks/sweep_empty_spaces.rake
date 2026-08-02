# frozen_string_literal: true

# .rake, not .rb: everything else in lib/tasks is a Tasks:: command object that Zeitwerk
# autoloads, and it skips this extension.
desc 'Delete spaces that have never held a task'
task sweep_empty_spaces: :environment do
  puts "Swept #{Spaces::SweepEmpty.call} empty spaces."
end
