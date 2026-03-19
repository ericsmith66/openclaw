# frozen_string_literal: true

require "liquid"

module Legion
  # Builds prompts from Liquid templates for different phases of the workflow.
  #
  # Templates are stored in `app/prompts/` with names like `phase_prompt.md.liquid`.
  # Liquid strict mode is enabled by default to catch missing context variables.
  #
  # @example Basic usage
  #   PromptBuilder.build(
  #     phase: :decompose,
  #     context: { prd_content: "...", project_path: "/path" }
  #   )
  #
  # @example Error handling
  #   begin
  #     prompt = PromptBuilder.build(phase: :unknown, context: {})
  #   rescue PromptBuilder::TemplateNotFoundError => e
  #     # Handle missing template
  #   end
  #
  # @see PromptBuilder.available_phases
  # @see PromptBuilder.required_context
  class PromptBuilder
    # Raised when a required context variable is missing in the Liquid template.
    class PromptContextError < StandardError; end

    # Raised when a template is not found for a given phase.
    class TemplateNotFoundError < StandardError; end

    # Raised when a Liquid template contains syntax errors.
    class TemplateSyntaxError < StandardError; end

    # Directory for prompt templates
    TEMPLATES_DIR = Rails.root.join("app/prompts").freeze

    # Mapping of phase symbols to template names
    PHASE_TEMPLATES = {
      conductor: "conductor_prompt.md.liquid",
      decompose: "decomposition_prompt.md.liquid",
      code: "task_prompt.md.liquid",
      architect_review: "architect_review_prompt.md.liquid",
      qa_score: "qa_score_prompt.md.liquid",
      retry: "retry_prompt.md.liquid",
      retrospective: "retrospective_prompt.md.liquid"
    }.freeze

    # Create an Environment with registered filters for this service
    def self.environment
      @environment ||= begin
        env = Liquid::Environment.new
        env.register_filter(Legion::LiquidFilters)
        env.error_mode = :strict
        env
      end
    end

    # Renders a prompt template for the given phase with the provided context.
    #
    # @param phase [Symbol] The phase name (e.g., :conductor, :decompose)
    # @param context [Hash] Context variables for the template (symbol keys are converted to strings)
    # @return [String] Rendered prompt
    # @raise [PromptBuilder::TemplateNotFoundError] if no template exists for the phase
    # @raise [PromptBuilder::PromptContextError] if a required context variable is missing
    # @raise [PromptBuilder::TemplateSyntaxError] if the template has Liquid syntax errors
    def self.build(phase:, context:)
      template_name = PHASE_TEMPLATES[phase]
      raise TemplateNotFoundError, "No template for phase :#{phase}" unless template_name

      template_path = TEMPLATES_DIR.join(template_name)
      raise TemplateNotFoundError, "Template not found: #{template_name}" unless template_path.exist?

      source = template_path.read
      template = Liquid::Template.parse(source, environment: environment)

      # Extract required variables from the template
      required_vars = extract_required_variables_from_template(template, context)
      missing_vars = required_vars - context.keys.map(&:to_s)

      if missing_vars.any?
        raise PromptContextError, "Missing context variable '#{missing_vars.first}' for phase :#{phase}"
      end

      # Convert symbol keys to string keys for Liquid compatibility (recursively)
      liquid_context = deep_transform_keys_to_strings(context)
      template.render!(liquid_context)
    rescue Liquid::UndefinedVariable => e
      variable_name = e.message.split("'")[1]
      raise PromptContextError, "Missing context variable '#{variable_name}' for phase :#{phase}"
    rescue Liquid::SyntaxError => e
      raise TemplateSyntaxError, "Liquid syntax error in #{template_name}: #{e.message}"
    end

    # Recursively transforms all hash keys to strings, including nested hashes and arrays.
    #
    # @param object [Object] The object to transform (Hash, Array, or other)
    # @return [Object] Transformed object with all hash keys converted to strings
    def self.deep_transform_keys_to_strings(object)
      case object
      when Hash
        object.transform_keys(&:to_s).transform_values { |v| deep_transform_keys_to_strings(v) }
      when Array
        object.map { |v| deep_transform_keys_to_strings(v) }
      else
        object
      end
    end

    # Extracts variable names from a template that are NOT covered by default filters.
    #
    # @param template [Liquid::Template] The parsed template
    # @param context [Hash] The context hash (for checking which variables are provided)
    # @return [Array<String>] List of variable names that must be provided
    def self.extract_required_variables_from_template(template, context)
      required_vars = []
      provided_vars = Set.new(context.keys.map(&:to_s))

      extract_required_from_node(template.root, required_vars, provided_vars)
      required_vars.uniq
    end

    # Extracts all variable names from a template.
    #
    # @param template [Liquid::Template] The parsed template
    # @return [Array<String>] List of variable names used in the template
    def self.extract_variables_from_template(template)
      variables = []
      extract_from_node(template.root, variables)
      variables.uniq
    end

    private

    # Recursively extracts variable names from a template node for required validation.
    # Only adds variables that are not provided in the context.
    # Loop variables (like `task` in `{% for task in tasks %}`) are provided by the loop
    # and should not be counted as required top-level variables.
    #
    # @param node [Object] A Liquid template node
    # @param required_vars [Array<String>] Accumulator for required variable names
    # @param provided_vars [Set<String>] Set of provided variable names
    def self.extract_required_from_node(node, required_vars, provided_vars)
      case node
      when Liquid::Variable
        # Extract the variable name
        if node.name.is_a?(Liquid::VariableLookup)
          var_name = node.name.name
          # Check if this variable is NOT provided in context
          unless provided_vars.include?(var_name)
            required_vars << var_name
          end
        end
      when Liquid::For
        # Loop blocks define their own variables - add the loop variable to provided_vars
        loop_variable = node.instance_variable_get(:@variable_name)
        if loop_variable
          # Mark the loop variable as provided so we don't require it at top level
          provided_vars.add(loop_variable)
        end
        node.nodelist.each { |n| extract_required_from_node(n, required_vars, provided_vars) }
      when Liquid::Block
        node.nodelist.each { |n| extract_required_from_node(n, required_vars, provided_vars) }
      when Liquid::Document
        node.nodelist.each { |n| extract_required_from_node(n, required_vars, provided_vars) }
      when Liquid::BlockBody
        node.nodelist.each { |n| extract_required_from_node(n, required_vars, provided_vars) }
      when Array
        node.each { |n| extract_required_from_node(n, required_vars, provided_vars) }
      end
    end

    # Recursively extracts all variable names from a template node.
    #
    # @param node [Object] A Liquid template node
    # @param variables [Array<String>] Accumulator for variable names
    def self.extract_from_node(node, variables)
      case node
      when Liquid::Variable
        # Extract the variable name
        if node.name.is_a?(Liquid::VariableLookup)
          variables << node.name.name
        end
      when Liquid::Block
        node.nodelist.each { |n| extract_from_node(n, variables) }
      when Liquid::Document
        node.nodelist.each { |n| extract_from_node(n, variables) }
      when Liquid::BlockBody
        node.nodelist.each { |n| extract_from_node(n, variables) }
      when Array
        node.each { |n| extract_from_node(n, variables) }
      end
    end

    # Returns a list of all available phases with templates.
    #
    # @return [Array<Symbol>] List of phase symbols
    def self.available_phases
      PHASE_TEMPLATES.keys.select { |phase| template_exists?(phase) }
    end

    # Returns the required context keys for a given phase based on template analysis.
    #
    # This method scans the template for Liquid variable references (e.g., `{{ var_name }}`)
    # and returns them as a list of required context keys.
    #
    # @param phase [Symbol] The phase name
    # @return [Array<String>] List of required context variable names
    # @raise [PromptBuilder::TemplateNotFoundError] if no template exists for the phase
    def self.required_context(phase:)
      template_name = PHASE_TEMPLATES[phase]
      raise TemplateNotFoundError, "No template for phase :#{phase}" unless template_name

      template_path = TEMPLATES_DIR.join(template_name)
      raise TemplateNotFoundError, "Template not found: #{template_name}" unless template_path.exist?

      source = template_path.read

      # Extract variable references from Liquid template using regex
      variables = source.scan(/\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)*)\s*\}\}/).flatten

      # Get unique variable names (top-level only, not nested properties)
      variables.map { |v| v.split(".").first }.uniq
    end

    private

    def self.template_exists?(phase)
      template_name = PHASE_TEMPLATES[phase]
      template_path = TEMPLATES_DIR.join(template_name)
      template_path.exist?
    end
  end
end
