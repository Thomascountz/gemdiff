#!/usr/bin/env ruby

require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "tty-command", require: true
  gem "tty-prompt", require: true
  gem "tty-logger", require: true
  gem "tty-file", require: true
  gem "tty-link", require: true
  gem "gems", require: true
  gem "ostruct", require: true
end

require "fileutils"
require "rubygems/package"

# https://github.com/Thomascountz/tty-prompt/pull/1/files
module MultiListPatch
  def keyenter(*)
    valid = true
    valid = @min <= @selected.size if @min
    valid &= @selected.size <= @max if @max

    super if valid
  end
end

TTY::Prompt::MultiList.include(MultiListPatch)

class GemDiff
  CACHE_DIR = File.join(Dir.home, ".gemdiff_cache")
  DIFFOSCOPE_COMMAND = "type diffoscope"
  DIFFOSCOPE_INSTALL_MESSAGE = "run `brew install diffoscope` to install diffoscope."
  DIFFOSCOPE_SUCCESS_MESSAGE = "diffoscope detected."
  FETCH_GEM_COMMAND = "gem fetch"
  DIFFOSCOPE_OUTPUT_DIR = "out"
  DIFFOSCOPE_CSS_PATH = "diffoscope.css"

  def initialize
    @logger = TTY::Logger.new { |config| config.metadata = [:date, :time] }
    @cmd = TTY::Command.new(printer: :pretty, uuid: false)
    @prompt = TTY::Prompt.new
    setup_prompt_key_mappings
    FileUtils.mkdir_p(CACHE_DIR)
  end

  def run
    ensure_diffoscope_installed
    gem_source = choose_gem_source
    gem_client = create_gem_client(gem_source)
    gem_name = @prompt.ask("Enter the gem name:")
    available_versions = fetch_gem_versions(gem_client, gem_name)
    version_a, version_b = select_versions(available_versions)
    gem_package_1 = fetch_gem(gem_name, version_a, gem_source)
    gem_package_2 = fetch_gem(gem_name, version_b, gem_source)
    generate_diff(gem_name, version_a, version_b, gem_package_1, gem_package_2)
  end

  private

  def setup_prompt_key_mappings
    @prompt.on(:keypress) do |event|
      case event.value
      when "j" then @prompt.trigger(:keydown)
      when "k" then @prompt.trigger(:keyup)
      when "l" then @prompt.trigger(:keyspace)
      end
    end
    @prompt.on(:keyescape) { |_key| exit }
  end

  def ensure_diffoscope_installed
    check_requirement = @cmd.run!(DIFFOSCOPE_COMMAND)
    if check_requirement.failure?
      @logger.fatal("diffoscope was not detected in your PATH.")
      @logger.fatal(DIFFOSCOPE_INSTALL_MESSAGE)
      exit 1
    end
    @logger.success(DIFFOSCOPE_SUCCESS_MESSAGE)
  end

  def choose_gem_source
    client_configs = build_client_configs
    @prompt.select("Choose a gem source:", client_configs.keys)
  end

  def create_gem_client(gem_source)
    client_configs = build_client_configs
    Gems::Client.new(client_configs[gem_source])
  end

  def build_client_configs
    Gem.sources.sources.each_with_object({}) do |source, config|
      config[source.uri.host] = {host: source.uri, password: source.uri.password, username: source.uri.user}
    end
  end

  def fetch_gem_versions(client, gem_name)
    versions = client.versions(gem_name)
    versions.map { |version| version["number"] }.sort_by { |v| Gem::Version.new(v) }.reverse
  rescue
    @logger.error("Failed to fetch gem versions for #{gem_name}.")
    exit(1)
  end

  def select_versions(available_versions)
    @prompt.multi_select(
      "Select two versions to compare:",
      available_versions,
      min: 2,
      max: 2,
      per_page: 15,
      show_help: :start
    ).sort_by { |v| Gem::Version.new(v) }
  end

  def fetch_gem(gem_name, version, source)
    filename = "#{gem_name}-#{version}.gem"
    cache_filename = File.join(CACHE_DIR, filename)

    if File.exist?(cache_filename)
      @logger.info("Using cached gem file for #{gem_name} version #{version}.")
    else
      @logger.info("Fetching #{gem_name} version #{version}...")

      @cmd.run("#{FETCH_GEM_COMMAND} #{gem_name} -v #{version} -s https://#{source}")

      unless File.exist?(filename)
        @logger.error("Failed to fetch gem #{gem_name} version #{version}.")
        exit(1)
      end
      FileUtils.mv(filename, cache_filename)
      @logger.success("#{cache_filename} saved.")
    end

    cache_filename
  end

  def generate_diff(gem_name, version_a, version_b, gem_package_1, gem_package_2)
    outfile = File.join(DIFFOSCOPE_OUTPUT_DIR, "#{gem_name}-#{version_a}-#{version_b}.html")
    diff_command = "diffoscope --new-file --html=#{outfile} --css=#{DIFFOSCOPE_CSS_PATH}"

    @cmd.run!("#{diff_command} #{gem_package_1} #{gem_package_2}", printer: :null)

    link = TTY::Link.link_to(outfile, "file://#{File.expand_path(outfile)}")
    @logger.success("Diff generated at #{link}")

    open_diff(outfile) if @prompt.yes?("Open diff?")
  end

  def open_diff(outfile)
    @cmd.run!("open #{outfile}")
  end
end

GemDiff.new.run
