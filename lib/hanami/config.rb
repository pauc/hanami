# frozen_string_literal: true

require "uri"
require "pathname"
require "dry/configurable"
require "dry/inflector"

require_relative "constants"

module Hanami
  # Hanami app config
  #
  # @since 2.0.0
  class Config
    include Dry::Configurable

    # @!attribute [rw] root
    #   Sets the root for the app or slice.
    #
    #   For the app, this defaults to `Dir.pwd`. For slices detected in `slices/` `config/slices/`,
    #   this defaults to `slices/[slice_name]/`.
    #
    #   Accepts a string path and will return a `Pathname`.
    #
    #   @return [Pathname]
    #
    #   @api public
    #   @since 2.0.0
    setting :root, constructor: ->(path) { Pathname(path) if path }

    # @!attribute [rw] inflector
    #   Sets the app's inflector.
    #
    #   This expects a `Dry::Inflector` (or compatible) inflector instance.
    #
    #   To configure custom inflection rules without having to assign a whole inflector, see
    #   {#inflections}.
    #
    #   @return [Dry::Inflector]
    #
    #   @see #inflections
    #
    #   @api public
    #   @since 2.0.0
    setting :inflector, default: Dry::Inflector.new

    # @!attribute [rw] settings_store
    #   Sets the store used to retrieve {Hanami::Settings} values.
    #
    #   Defaults to an instance of {Hanami::Settings::EnvStore}.
    #
    #   @return [#fetch]
    #
    #   @see Hanami::Settings
    #   @see Hanami::Settings::EnvStore#fetch
    #
    #   @api public
    #   @since 2.0.0
    setting :settings_store, default: Hanami::Settings::EnvStore.new

    # @!attribute [rw] slices
    #   Sets the slices to load when the app is preared or booted.
    #
    #   Defaults to `nil`, which will load all slices. Set this to an array of slice names to load
    #   only those slices.
    #
    #   This attribute is also populated from the `HANAMI_SLICES` environment variable.
    #
    #   @example
    #     config.slices = ["admin", "search"]
    #
    #   @example
    #     ENV["HANAMI_SLICES"] # => "admin,search"
    #     config.slices # => ["admin", "search"]
    #
    #   @return [Array<String>, nil]
    #
    #   @api public
    #   @since 2.0.0
    setting :slices

    # @!attribute [rw] shared_app_component_keys
    #   Sets the keys for the components to be imported from the app into all other slices.
    #
    #   You should append items to this array, since the default shared components are essential for
    #   slices to operate within the app.
    #
    #   @example
    #     config.shared_app_component_keys += ["shared_component_a", "shared_component_b"]
    #
    #   @return [Array<String>]
    #
    #   @api public
    #   @since 2.0.0
    setting :shared_app_component_keys, default: %w[
      inflector
      logger
      notifications
      rack.monitor
      routes
      settings
    ]

    # @!attribute [rw] no_auto_register_paths
    #   Sets the paths to skip from container auto-registration.
    #
    #   Defaults to `["entities"]`.
    #
    #   @return [Array<String>] array of relative paths
    #
    #   @api public
    #   @since 2.0.0
    setting :no_auto_register_paths, default: %w[entities]

    # @!attribute [rw] base_url
    #   Sets the base URL for app's web server.
    #
    #   This is passed to the {Slice::ClassMethods#router router} and used for generating links.
    #
    #   Defaults to `"http://0.0.0.0:2300"`. String values passed are turned into `URI` instances.
    #
    #   @return [URI]
    #
    #   @see Slice::ClassMethods#router
    #
    #   @api public
    #   @since 2.0.0
    setting :base_url, default: "http://0.0.0.0:2300", constructor: ->(url) { URI(url) }

    # Returns the app or slice's {Hanami::SliceName slice_name}.
    #
    # This is useful for default config values that depend on this name.
    #
    # @return [Hanami::SliceName]
    #
    # @api private
    # @since 2.0.0
    attr_reader :app_name

    # Returns the app's environment.
    #
    # @example
    #   config.env # => :development
    #
    # @return [Symbol]
    #
    # @see #environment
    #
    # @api private
    # @since 2.0.0
    attr_reader :env

    # Returns the app's actions config, or a null config if hanami-controller is not bundled.
    #
    # @example When hanami-controller is bundled
    #   config.actions.default_request_format # => :html
    #
    # @example When hanami-controller is not bundled
    #   config.actions.default_request_format # => NoMethodError
    #
    # @return [Hanami::Config::Actions, Hanami::Config::NullConfig]
    #
    # @api public
    # @since 2.0.0
    attr_reader :actions

    # Returns the app's middleware stack, or nil if hanami-router is not bundled.
    #
    # Use this to configure middleware that should apply to all routes.
    #
    # @example
    #   config.middleware.use :body_parser, :json
    #   config.middleware.use MyCustomMiddleware
    #
    # @return [Hanami::Slice::Routing::Middleware::Stack, nil]
    #
    # @api public
    # @since 2.0.0
    attr_reader :middleware

    # @api private
    # @since 2.0.0
    alias_method :middleware_stack, :middleware

    # Returns the app's router config, or a null config if hanami-router is not bundled.
    #
    # @example When hanami-router is bundled
    #   config.router.resolver # => Hanami::Slice::Routing::Resolver
    #
    # @example When hanami-router is not bundled
    #   config.router.resolver # => NoMethodError
    #
    # @return [Hanami::Config::Router, Hanami::Config::NullConfig]
    #
    # @api public
    # @since 2.0.0
    attr_reader :router

    # Returns the app's views config, or a null config if hanami-view is not bundled.
    #
    # This is NOT RELEASED as of 2.0.0.
    #
    # @api private
    attr_reader :views

    # Returns the app's assets config.
    #
    # This is NOT RELEASED as of 2.0.0.
    #
    # @api private
    attr_reader :assets

    # @api private
    def initialize(app_name:, env:)
      @app_name = app_name
      @env = env

      # Apply default values that are only knowable at initialize-time (vs require-time)
      self.root = Dir.pwd
      load_from_env

      @logger = Config::Logger.new(env: env, app_name: app_name)

      # TODO: Make assets config dependent
      require "hanami/assets/app_config"
      @assets = Hanami::Assets::AppConfig.new

      @actions = load_dependent_config("hanami-controller") {
        require_relative "config/actions"
        Actions.new
      }

      @router = load_dependent_config("hanami-router") {
        require_relative "config/router"
        @middleware = Slice::Routing::Middleware::Stack.new
        Router.new(self)
      }

      @views = load_dependent_config("hanami-view") {
        require_relative "config/views"
        Views.new
      }

      yield self if block_given?
    end

    # @api private
    def initialize_copy(source)
      super

      @app_name = app_name.dup

      @assets = source.assets.dup
      @actions = source.actions.dup
      @middleware = source.middleware.dup
      @router = source.router.dup.tap do |router|
        router.instance_variable_set(:@base_config, self)
      end
      @views = source.views.dup
    end
    private :initialize_copy

    # Finalizes the config.
    #
    # This is called when the app or slice is prepared. After this, no further changes to config can
    # be made.
    #
    # @api private
    def finalize!
      # Finalize nested configs
      assets.finalize!
      actions.finalize!
      views.finalize!
      logger.finalize!
      router.finalize!

      use_body_parser_middleware

      super
    end

    # Configures the app's custom inflections.
    #
    # You should call this one time only. Subsequent calls will override previously configured
    # inflections.
    #
    # @example
    #   config.inflections do |inflections|
    #     inflections.acronym "WNBA"
    #   end
    #
    # @see https://dry-rb.org/gems/dry-inflector
    #
    # @return [Dry::Inflector] the configured inflector
    #
    # @api public
    # @since 2.0.0
    def inflections(&block)
      self.inflector = Dry::Inflector.new(&block)
    end

    # Disabling this to permit distinct documentation for `#logger` vs `#logger=`
    #
    # rubocop:disable Style/TrivialAccessors

    # Returns the logger config.
    #
    # Use this to configure various options for the default `Dry::Logger::Dispatcher` logger instance.
    #
    # @example
    #   config.logger.level = :debug
    #
    # @return [Hanami::Config::Logger]
    #
    # @see Hanami::Config::Logger
    #
    # @api public
    # @since 2.0.0
    def logger
      @logger
    end

    # Sets the app's logger instance.
    #
    # This entirely replaces the default `Dry::Logger::Dispatcher` instance that would have been
    #
    # @see #logger_instance
    #
    # @api public
    # @since 2.0.0
    def logger=(logger_instance)
      @logger_instance = logger_instance
    end

    # rubocop:enable Style/TrivialAccessors

    # Returns the configured logger instance.
    #
    # Unless you've replaced the logger with {#logger=}, this returns a `Dry::Logger::Dispatcher` configured
    # with the options configured through {#logger}.
    #
    # This configured logger is registered in all app and slice containers as `"logger"`. For
    # typical usage, you should access the logger via this component, not directly from config.
    #
    # @example Accessing the logger component
    #   Hanami.app["logger"] # => #<Dry::Logger::Dispatcher>
    #
    # @example Injecting the logger as a dependency
    #   module MyApp
    #     class MyClass
    #       include Deps["logger"]
    #
    #       def my_method
    #         logger.info("hello")
    #       end
    #     end
    #   end
    #
    # @return [Dry::Logger::Dispatcher]
    #
    # @see #logger
    # @see Hanami::Config::Logger
    #
    # @api public
    # @since 2.0.0
    def logger_instance
      @logger_instance || logger.instance
    end

    private

    def load_from_env
      self.slices = ENV["HANAMI_SLICES"]&.split(",")&.map(&:strip)
    end

    SUPPORTED_MIDDLEWARE_PARSERS = %i[json].freeze
    private_constant :SUPPORTED_MIDDLEWARE_PARSERS

    def use_body_parser_middleware
      return unless Hanami.bundled?("hanami-controller")

      return if actions.formats.empty?
      return if middleware.stack["/"].map(&:first).any? { |klass| klass == "Hanami::Middleware::BodyParser" }

      parsers = SUPPORTED_MIDDLEWARE_PARSERS & actions.formats.values
      return if parsers.empty?

      middleware.use(
        :body_parser,
        [parsers.to_h { |parser_format|
          [parser_format, actions.formats.mime_types_for(parser_format)]
        }]
      )
    end

    def load_dependent_config(gem_name)
      if Hanami.bundled?(gem_name)
        yield
      else
        require_relative "config/null_config"
        NullConfig.new
      end
    end

    def method_missing(name, *args, &block)
      if config.respond_to?(name)
        config.public_send(name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(name, _incude_all = false)
      config.respond_to?(name) || super
    end
  end
end