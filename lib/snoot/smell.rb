module Snoot
  Smell = Data.define(:smell_type, :location, :message) do
    include Finding

    def kind = :Smell
  end
end
