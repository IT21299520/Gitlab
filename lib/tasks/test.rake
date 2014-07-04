Rake::Task["test"].clear

desc "GITLAB | Run all tests"
task :test do
  Rake::Task["gitlab:test"].invoke
end

unless Rails.env.production?
  require 'coveralls/rake/task'
  Coveralls::RakeTask.new
  desc "GITLAB | Run all tests on CI with simplecov"
  # TODO
  #task :test_ci => [:spinach, :spec, 'coveralls:push']
  task :test_ci => [:spec]
end
