require "language_pack"
require "language_pack/rails3"

# Rails 3 Language Pack. This is for all Rails 3.x apps.
class LanguagePack::Custom < LanguagePack::Rails3
  # Name the app
  def name
    "Our application"
  end

  # Specify what Ruby version to install
  def ruby_version
    "1.9.3"
  end

  # Used to enable #install_jvm
  def ruby_version_jruby?
    true
  end

  # Specify what addons need to be instantiated with the project
  # Pull these from the `heroku addons:add __addon name__` descriptions
  def default_addons
    ["redistogo:nano", "heroku-postgresql:dev"]
  end

  # overriding to implement step that creates other yaml files
  def create_database_yml
    super # create the original database.yaml
    create_resque_yml
  end

  def create_resque_yml
    log("create_resque_yml") do
      return unless File.directory?("config")
      topic("Writing config/resque.yml to read from REDISTOGO_URL")
      File.open("config/resque.yml", "w") do |file|
        file.puts <<-RESQUE_YML
<%

require 'cgi'
require 'uri'

begin
  uri = URI.parse(ENV["REDISTOGO_URL"])
rescue URI::InvalidURIError
  raise "Invalid RESQUE_URL"
end

def attribute(name, value, force_string = false)
  if value
    value_string =
      if force_string
        '"' + value + '"'
      else
        value
      end
    "\#{name}: \#{value_string}"
  else
    ""
  end
end

database = (uri.path || "").split("/")[1]

username = uri.user
password = uri.password

host = uri.host
port = uri.port
%>

default:
  <%= attribute "password", password, true %>
  <%= attribute "host",     host %>
  <%= attribute "port",     port %>
  timeout: 1
        RESQUE_YML
      end
    end
  end


  # Use compass and jammit to compile assets, not the asset pipeline
  def run_assets_precompile_rake_task
    log("assets_precompile") do
      setup_database_url_env

      topic("Preparing app for compass assets")
      ENV["RAILS_ENV"] ||= "production"

      puts "Running: compass compile"
      require 'benchmark'
      time = Benchmark.realtime {
        pipe("env PATH=$PATH:bin bundle exec compass compile -e #{ENV['RAILS_ENV']} --force")
        pipe("env PATH=$PATH:bin bundle exec jammit -f")
      }

      if $?.success?
        log "assets_precompile", :status => "success"
        puts "Asset precompilation completed (#{"%.2f" % time}s)"
      else
        log "assets_precompile", :status => "failure"
        puts "Precompiling assets failed"
        raise "Precompiling assets failed"
      end
    end
  end
end