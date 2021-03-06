# Statistics tasks.
#
desc "Analyzes indexes (index, category optional)."
task :analyze, [:index, :category] => :'stats:prepare' do |_, options|
  index, category = options.index, options.category

  specific = Indexes
  specific = specific[index]    if index
  specific = specific[category] if category

  statistics = Statistics.new

  begin
    statistics.analyze specific
  rescue StandardError
    puts "\n\033[31mNote: rake analyze needs prepared indexes. Run rake index first.\033[m\n\n"
    raise
  end

  puts statistics
end

task :stats => :'stats:prepare' do
  stats = Statistics.new
  puts stats.application
end

namespace :stats do

  task :prepare => :application do
    require File.expand_path('../../picky/statistics', __FILE__)
  end

end