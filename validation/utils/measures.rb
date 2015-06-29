class Score
  attr_accessor :true_positives, :false_positives, :false_negatives

  def initialize(name_service=nil)
    @true_positives = 0
    @false_positives = 0
    @false_negatives = 0
    @name_service=name_service
  end

  def score(predicted, reference)
    predicted,reference = preprocess(predicted, reference)
    true_positives,false_positives,false_negatives=example_score(predicted, reference)

    @true_positives += true_positives
    @false_positives += false_positives
    @false_negatives += false_negatives

    return true_positives,false_positives,false_negatives
  end

  def example_score(predicted, reference)
    true_positives=(predicted&reference).size
    false_positives=(predicted-reference).size
    false_negatives=(reference-predicted).size

    return true_positives,false_positives,false_negatives
  end

  def preprocess(predicted, reference)

  end

  def precision
    return (@true_positives) / (@true_positives + @false_positives).to_f * 100
  end

  def recall
    return (@true_positives) / (@true_positives + @false_negatives).to_f * 100

  end

  def f1
    return 2 * precision * recall / (precision + recall)
  end

end

class SimpleScore < Score
  def preprocess(predicted, reference)
    if predicted.nil?
      predicted = []
    end

    return predicted, reference
  end
end

class AprosioScore < Score
  def preprocess(predicted, reference)
    if predicted.nil?
      predicted_genls = [Thing]
    else
      predicted_genls = predicted.map{|cyc_id|  @name_service.cyc.all_genls(@name_service.find_by_id(cyc_id))}.flatten.uniq
    end
    reference_genls =reference.map{|cyc_id| @name_service.cyc.all_genls(@name_service.find_by_id(cyc_id))}.flatten.uniq

    return predicted_genls,reference_genls
  end
end

class AprosioScoreNormalized < AprosioScore
  alias aprosio_example_score example_score
  def example_score(predicted, reference)
    tp,fp,fn=aprosio_example_score(predicted, reference)
    sum = (tp+fp+fn).to_f

    return tp/sum, fp/sum, fn/sum
  end
end