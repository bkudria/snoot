module Snoot
  DuplicationCluster = Data.define(:signature, :locations) do
    include Finding

    def kind = :DuplicationCluster
  end
end
