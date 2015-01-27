module Concerns
  # Shortcut methods for doing simple validations
  module Validations
    def presence_of(attr)
      errors.add(attr, %{No #{attr} present}) unless send(attr)
    end

    def length_of(attr, options = {})
      if options[:in].is_a?(Range) && send(attr)
        errors.add(attr, %{#{attr.capitalize} is too short}) if send(attr).to_s.length < options[:in].min
        errors.add(attr, %{#{attr.capitalize} is too long}) if send(attr).to_s.length > options[:in].max
      end

      # TODO: Can implement more later, like min, max, etc.
    end
  end
end
