require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.test_files = Rake::FileList['test/**/*_test.rb']
end

task default: :test
