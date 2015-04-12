require 'csv'

module Umbel
  class SearchService
    attr_accessor :concept_map, :cyc_map

    # Arguments are paths to umbel_concepts.csv exported by 'extract_umbel_concept_names.rb'
    # (data/umbel_concepts.csv') and path to UMBEL to Cyc mapping ('data/umbel_to_cyc_mapping.csv')
    def initialize(umbel_reference, umbel_to_cyc)
      @concept_map = {}
      @cyc_map = {}
      CSV.open(umbel_reference) do |input|
        input.each do |name, label, *parents|
          name.chomp!
          rc = ReferenceConcept.new(name, label, parents)
          @concept_map[name] = rc

          parents.select { |parent| parent.start_with?('umbel#') }.each do |super_type_name|
            next if @concept_map.include? super_type_name
            @concept_map[super_type_name] = SuperType.new(super_type_name)
          end
        end
      end

      @concept_map.each do |name, rc|
        rc.parents.map! { |parent_name| @concept_map[parent_name] }
        rc.parents.each do |parent|
          parent.children << rc
        end
      end

      load_mapping_to_cyc(umbel_to_cyc)
    end

    private
    def load_mapping_to_cyc(umbel_to_cyc)
      CSV.open(umbel_to_cyc) do |input|
        input.each do |umbel, cyc_id, cyc_name|
          @concept_map[umbel].cyc_id = cyc_id
          @cyc_map[cyc_id] = @concept_map[umbel]
        end
      end
    end
  end
end
