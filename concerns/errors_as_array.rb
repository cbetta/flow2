module Concerns
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
