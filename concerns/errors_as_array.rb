module Concerns
  # Allow a model to return all validation errors in a nested array
  # Used in JSON responses
  module ErrorsAsArray
    def errors_list
      list = []
      errors.each do |k, v|
        v.each do |msg|
          list << [k, msg]
        end
      end
      list
    end
  end
end
