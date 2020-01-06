require "active_support/string_inquirer"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/try"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/hash_with_indifferent_access"
require "yaml"

require_relative "railtie" if defined?(Rails)

class ApplicationConfig
  class ImportFromFile
    def initialize(env, filepath)
      filepath ||= File.expand_path("config/config.yml")
      @settings = import_from_file(env, filepath)
    end

    def to_hash
      @settings
    end

    def self.to_hash(env, filepath)
      new(env, filepath).to_hash
    end


    private

    def import_from_file(env, filepath)
      if File.exists?(filepath) && config = YAML.load_file(filepath)[env]
        HashWithIndifferentAccess[
          config["config"].map do |k,v|
            if v.is_a?(Hash)
              [k.downcase, v.with_indifferent_access]
            else
              [k.downcase, v]
            end
          end
        ]
      end
    end
  end

  # TODO check if settings mutator can be hidden. It should"ve never been exposed in the first place.
  attr_accessor :app_name, :settings

  def initialize(app_name = "application", importer = ImportFromFile, &block)
    @app_name = app_name
    @settings = importer.to_hash(env, config_filepath)

    @keys     = {}

    self.instance_exec(&block) if block_given?

    @keys.freeze
  end

  def keys
    @keys
  end

  def config_filepath
    get(app_name + ".config.filepath")
  end

  def db_config_filepath
    get(app_name + ".db_config.filepath")
  end

  def mongodb_config_filepath
    get(app_name + ".mongodb_config.filepath")
  end

  def config_key(key_name, options = {}, &block)
    key       = (options[:key] || key_name).to_sym

    key_value = if get(key).nil?
                  (block_given? ? block.call(self) : nil) || get_value(options[:default])
                else
                  get(key)
                end

    if key_value.nil? && (options[:mandatory] == true || (options[:mandatory].is_a?(Hash) && options[:mandatory].has_key?(:unless) && @keys[options[:mandatory][:unless]].blank?))
      raise ArgumentError, "Mandatory key: #{key_name} not specified!"
    end

    @keys[key_name] = key_value
  end

  def get_value(value)
    (value && value.respond_to?(:call)) ? value.call : value
  end

  def respond_to?(method_name, _include_all = false)
    (@keys && @keys.keys.include?(method_name)) || super
  end

  def method_missing(method_name, *args, &block)
    if @keys && @keys.include?(method_name)
      @keys[method_name]
    else
      super
    end
  end

  def env
    ActiveSupport::StringInquirer.new((
      get("#{app_name}.environment") || ENV["RAILS_ENV"] ||
      ENV["RACK_ENV"] || "development"
    ).downcase)
  end

  private

  def get(key)
    key = key.to_s

    val = java.lang.System.getProperty(key) if defined?(Java)
    return val if val.present?

    key = key.gsub(".", "_")
    ENV[key.upcase] || settings.try(:[], key.downcase)
  end
end
