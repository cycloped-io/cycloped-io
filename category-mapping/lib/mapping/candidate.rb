module Mapping
  module CandidateUtils
    def cyc_name
      self.cyc_term.to_ruby.to_s
    end

    def genls?(other)
      self.cyc_service.cyc.genls?(self.cyc_term,other.cyc_term)
    end

    def inspect
      self.cyc_name
    end
  end

  class Candidate < Struct.new(:cyc_id,:cyc_name,:positive,:total)
    #include CandidateUtils

    def initialize(cyc_id,cyc_name,positive,total)
      super(cyc_id,cyc_name,positive,total)
      self.positive = self.positive.to_f
      self.total = self.total.to_f
    end

    def probability
      return @probability if @probability
      @probability = self.mle_probability
      @probability = [[@probability,0.0].max,0.95].min
    end

    # MLE probability
    def mle_probability
      if self.total > 0
        (self.positive / self.total).round(5)
      else
        0
      end
    end

    # MAP probability
    def map_probability
      raise ArgumentError.new("Mean probability not set") if self.class.mean_probability.nil?
      ([[((self.positive + self.class.alpha - 1) / (self.total + self.class.alpha + self.class.beta - 2)),0].max,1].min).round(5)
    end

    def to_a(probability=:probability)
      [self.cyc_id,self.cyc_name,self.send(probability)]
    end

    def self.mean_probability
      @mean_probability
    end

    def self.mean_probability=(value)
      @mean_probability = value
    end

    def self.probability_variance=(value)
      @probability_variance = value
    end

    def self.alpha
      return @alpha unless @alpha.nil?
      raise ArgumentError.new("Variance too large") if @probability_variance >= @mean_probability * (1 - @mean_probability)
      @alpha = @mean_probability * (@mean_probability * (1 - @mean_probability) / @probability_variance - 1)
    end

    def self.beta
      return @beta unless @beta.nil?
      raise ArgumentError.new("Variance too large") if @probability_variance >= @mean_probability * (1 - @mean_probability)
      @beta = (1 - @mean_probability) * (@mean_probability * (1 - @mean_probability) / @probability_variance - 1)
    end
  end

  class TypeCandidate < Struct.new(:cyc_id,:category_genls_count,:cyc_service)
    include CandidateUtils

    def cyc_term
      return @cyc_term if @cyc_term_defined
      @cyc_term = self.cyc_service.find_by_id(self.cyc_id)
      @cyc_term_defined = true
      @cyc_term
    end

    def total_count
      self.category_genls_count
    end

    def to_a
      [self.cyc_id,self.category_genls_count]
    end
  end
end
