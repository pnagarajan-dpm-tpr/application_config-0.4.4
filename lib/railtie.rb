if Rails.version > '3.0' && Rails.version < '4.0'
  ActiveSupport.on_load(:active_record) do
    module ActiveRecord
      class Base
        class ConnectionSpecification
          class Resolver
            def spec
              case config
              when nil
                raise AdapterNotSpecified unless defined?(Rails.env)
                resolve_string_connection AppConfig.env
              when Symbol, String
                if AppConfig.env
                  resolve_string_connection AppConfig.env
                else
                  resolve_string_connection config.to_s
                end
              when Hash
                resolve_hash_connection config
              end
            end
          end
        end
      end
    end
  end
end
