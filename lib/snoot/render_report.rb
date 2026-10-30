# frozen_string_literal: true

module Snoot
  # Given a finding_rendered Run, produces a Report. Smell findings get
  # header, remaining, instances, tuning and doc; ComplexityHit and
  # DuplicationCluster get header, remaining, finding_context and doc.
  # SmellSections, ComplexitySections and DuplicationSections build their
  # variants' sections; the helpers below build the rest.
  module RenderReport
    # Report is the value returned by RenderReport.invoke: the source
    # Run, the selected Finding it was built from, and the ordered
    # sections hash that CLI joins into stdout output.
    Report = Data.define(:run, :finding, :sections)
    # The doc is always the last section, so the first line equal to this
    # heading marks where it starts, even though reek's docs use ## headings too.
    REFERENCE_HEADING = "## Reference"

    module_function

    def invoke(run, smells:, remaining:, orchestration:)
      finding = run.selected_finding
      sections = if finding.is_a?(Smell)
                   SmellSections.build(smells, finding, orchestration)
                 else
                   non_smell_sections(finding)
                 end
      header, *rest = sections.merge(doc: reference(sections[:doc])).to_a
      remaining_line = render_remaining(remaining, orchestration.significance_cutoffs)
      Report.new(run: run, finding: finding, sections: [header, [:remaining, remaining_line], *rest].to_h)
    end

    def reference(doc) = "#{REFERENCE_HEADING}\n\n#{doc}"

    def render_remaining(remaining, cutoffs)
      counts = [
        count_of(remaining.smell_types, "smell type"),
        count_of(remaining.duplication_clusters, "duplication cluster"),
        count_of(remaining.complexity_hits, "complexity hit")
      ]
      below_cutoff = describe_below_cutoff(remaining.below_cutoff_smell_types)
      "Also significant: #{counts.join(', ')}; #{below_cutoff} (#{describe_cutoffs(cutoffs)})"
    end

    def describe_below_cutoff(smell_types)
      summary = "#{count_of(smell_types.size, 'smell type')} below cutoff"
      smell_types.empty? ? summary : "#{summary}: #{smell_types.map(&:name).join(', ')}"
    end

    def describe_cutoffs(cutoffs)
      clauses = [
        cutoff_clause("smell types", cutoffs.smell_type_instances&.then { |floor| "#{floor}+ instances" }),
        cutoff_clause("complexity hits", cutoffs.complexity_score&.then { |floor| "score #{format_score(floor)}+" }),
        cutoff_clause("duplication clusters", cutoffs.duplication_locations&.then { |floor| "#{floor}+ locations" })
      ]
      "cutoffs: #{clauses.join('; ')}"
    end

    def cutoff_clause(category, requirement)
      requirement ? "#{category} need #{requirement}" : "#{category} have no cutoff"
    end

    def format_score(score)
      score.frac.zero? ? score.to_i.to_s : score.to_s("F")
    end

    def count_of(count, noun)
      count == 1 ? "1 #{noun}" : "#{count} #{noun}s"
    end

    def non_smell_sections(finding)
      case finding
      when ComplexityHit then ComplexitySections.build(finding)
      when DuplicationCluster then DuplicationSections.build(finding)
      end
    end
  end
end
