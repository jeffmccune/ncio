module Ncio
  module Support
    ##
    # Helper methods for transforming a backup data structure.  The
    # transformation methods match groups against class names.  If there's a
    # match, the rules and the matching class paramter values are transformed,
    # mapping one hostname to another.
    module Transform
      def group_matches?(group)
        classes = group['classes'].keys
        name = classes.find { |class_name| class_matches?(class_name) }
        msg = name ? 'Matched' : 'Did not match'
        debug(msg + " group: #{group['name']}, classes: #{JSON.dump(classes)}")
        name ? true : false
      end

      def class_matches?(class_name)
        opts[:matcher].match(class_name)
      end

      ##
      # @param [Hash] group
      def transform_group(group)
        # Transform rules if they're present in the 'rule' key
        group['rule'] = transform_rules(group['rule']) if group['rule']
        # Transform class parameters if there are classes with parameters
        classes = group['classes']
        group['classes'] = classes.each_with_object({}) do |(name, params), hsh|
          hsh[name] = if class_matches?(name) then transform_params(params)
                      else params
                      end
          hsh
        end
        # Return the updated group
        group
      end

      ##
      # Recursively transform an array of rules
      #
      # @param [Array] rules Array of rule objects.  See the [Rule
      #   Grammar](https://goo.gl/6BNc6D)
      #
      # @return [Array] transformed rules
      def transform_rules(rules)
        rules.map do |rule|
          case rule
          when Array
            transform_rules(rule)
          when String
            opts[:hostname_map][rule]
          end
        end
      end

      ##
      # Transform class parameters, which are a simple key / value JSON hash.
      # The values of each hash are routed through the hostname "smart map"
      #
      # @return [Hash<String, String>] transformed parameter hash map
      def transform_params(params)
        params.each_with_object({}) do |(key, val), hsh|
          hsh[key] = case val
                     when Array then val.map { |v| opts[:hostname_map][v] }
                     when String then opts[:hostname_map][val]
                     else val
                     end
          hsh
        end
      end
    end
  end
end
