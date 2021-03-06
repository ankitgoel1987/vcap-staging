require 'spec_helper'

describe "A simple Sinatra app being staged" do
  before do
    app_fixture :sinatra_trivial
  end

  it "is packaged with a startup script" do
    stage sinatra_staging_env do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      start_script = File.join(staged_dir, 'startup')
      start_script.should be_executable_file
      script_body = File.read(start_script)
      script_body.should == <<-EXPECTED
#!/bin/bash
export RACK_ENV="${RACK_ENV:-production}"
export RUBYOPT="-rubygems -I$PWD/ruby -rstdsync"
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
#{executable} app.rb $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
      EXPECTED
    end
  end

  it "contains a log indicating disabled autoconfig" do
    stage sinatra_staging_env do |staged_dir|
      executable = '%VCAP_LOCAL_RUNTIME%'
      staging_log = File.join(staged_dir, 'logs','staging.log')
      log_body = File.read(staging_log)
      log_body.should =~ /Auto-reconfiguration disabled because app does not use Bundler./
    end
  end

  describe "when bundled" do
    before do
      app_fixture :sinatra_gemfile
    end

    it "is packaged with a startup script" do
      stage sinatra_staging_env do |staged_dir|
        executable = '%VCAP_LOCAL_RUNTIME%'
        start_script = File.join(staged_dir, 'startup')
        start_script.should be_executable_file
        script_body = File.read(start_script)
        script_body.should == <<-EXPECTED
#!/bin/bash
export GEM_HOME="$PWD/app/rubygems/ruby/1.8"
export GEM_PATH="$PWD/app/rubygems/ruby/1.8"
export PATH="$PWD/app/rubygems/ruby/1.8/bin:$PATH"
export RACK_ENV="${RACK_ENV:-production}"
export RUBYOPT="-I$PWD/ruby -I$PWD/app/rubygems/ruby/1.8/gems/cf-autoconfig-#{AUTO_CONFIG_GEM_VERSION}/lib -rstdsync"
mkdir ruby
echo "\\$stdout.sync = true" >> ./ruby/stdsync.rb
cd app
#{executable} ./rubygems/ruby/1.8/bin/bundle exec #{executable} -rcfautoconfig ./app.rb $@ > ../logs/stdout.log 2> ../logs/stderr.log &
STARTED=$!
echo "$STARTED" >> ../run.pid
wait $STARTED
      EXPECTED
      end
    end

   it "installs autoconfig gem" do
     stage sinatra_staging_env do |staged_dir|
       gemfile = File.join(staged_dir,'app','Gemfile')
       gemfile_body = File.read(gemfile)
       gemfile_body.should == <<-EXPECTED
source "http://rubygems.org"
gem "rake"
gem "sinatra"
gem "thin"
gem "json"
group :test do
  gem "rspec"
end
gem "redis", :group => :development
gem "uglifier", :groups => [:assets, :test]
gem "rubyzip", :group => :development
group :assets do
  gem "thor"
end

gem "cf-autoconfig"
     EXPECTED
     end
   end
  end
end
def sinatra_staging_env
  {:runtime_info => {
     :name => "ruby18",
     :version => "1.8.7",
     :description => "Ruby 1.8.7",
     :executable => "/usr/bin/ruby",
     :environment => {"bundle_gemfile"=>nil}
   },
   :framework_info => {
     :name => "sinatra",
     :runtimes => [{"ruby18"=>{"default"=>true}}, {"ruby19"=>{"default"=>false}}],
     :detection =>[{"*.rb"=>"require\\s+'sinatra'|require\\s+\"sinatra\""}, {"config.ru"=>false}, {"config/environment.rb"=>false}]
   }}
end
