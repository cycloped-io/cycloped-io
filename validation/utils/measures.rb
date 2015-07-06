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

  def accuracy
    return Float::NAN
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

class Errors
  attr_accessor :tp, :fp, :fn, :tn

  def initialize
    @tp=0
    @fp=0
    @fn=0
    @tn=0
  end
end

class ClassScore
  def initialize(name_service=nil)
    @scores = Hash.new {|hash,key| hash[key] = Errors.new}
    @samples=0
    @name_service=name_service
  end

  def score(predicted, reference)
    @samples+=1
    predicted,reference = preprocess(predicted, reference)

    (predicted&reference).each do |type|
      @scores[type].tp+=1
    end
    (predicted-reference).each do |type|
      @scores[type].fp+=1
    end
    (reference-predicted).each do |type|
      @scores[type].fn+=1
    end
  end

  def preprocess(predicted, reference)
    if predicted.nil?
      predicted = []
    end
    predicted.reject!{|t| t==Thing.id}
    reference.reject!{|t| t==Thing.id}

    return predicted, reference
  end

  def precision
    sum = 0
    pr=0.0
    @scores.each do |type, errors|
      pri=errors.tp.to_f/(errors.tp+errors.fp)*(errors.tp+errors.fn)
      if pri.nan?
        pri=0.0
      end
      pr+=pri
      sum+=(errors.tp+errors.fn)
    end
    return pr/sum*100
  end

  def recall
    sum = 0
    rc=0.0
    @scores.each do |type, errors|
      rci=errors.tp.to_f #/(errors.tp+errors.fn)*(errors.tp+errors.fn)
      if rci.nan?
        rci=0.0
      end
      rc+=rci
      sum+=(errors.tp+errors.fn)
    end
    return rc/sum*100
  end

  def f1
    return 2 * precision * recall / (precision + recall)
  end

  def accuracy
    sum = 0
    acc=0.0
    @scores.each do |type, errors|
      errors.tn = @samples-(errors.tp+errors.fp+errors.fn)
      acci=(errors.tp+errors.tn).to_f/(errors.tp+errors.fp+errors.fn+errors.tn)*(errors.tp+errors.fn)
      if acci.nan?
        acci=0.0
      end
      acc+=acci
      sum+=(errors.tp+errors.fn)
    end
    return acc/sum*100
  end
end