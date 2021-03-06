module Procedo
  class Procedure
    # A Computation defines an information computed to stored in given
    # destinations
    class Computation < Field
      code_trees :condition, root: 'boolean_expression'
      code_trees :expression

      attr_reader :destinations

      def initialize(parameter, name, options = {})
        super(parameter, name, options)
        @destinations = options[:destinations]
        self.expression = options[:expression]
        self.condition = options[:if]
      end

      def depend_on?(parameter_name)
        expression_with_parameter?(parameter_name) ||
          condition_with_parameter?(parameter_name)
      end
    end
  end
end
