module Snoot
  # ReportConsumer is the external entity from snoot.allium that reads a
  # rendered report. The spec declares no fields and no narrowing
  # behaviour, so the type is a structural marker.
  ReportConsumer = Data.define
end
