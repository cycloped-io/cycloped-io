class Score
  attr_accessor :true_positives, :false_positives, :false_negatives

  def initialize(name_service=nil)
    @true_positives = 0
    @false_positives = 0
    @false_negatives = 0

    @samples = 0
    @unique_types = Set.new
    @name_service=name_service
  end

  def score(predicted, reference, name=nil)
    @samples+=1
    predicted, reference = preprocess(predicted, reference)
    @unique_types.merge(predicted+reference)
    true_positives, false_positives, false_negatives=example_score(predicted, reference)

    @true_positives += true_positives
    @false_positives += false_positives
    @false_negatives += false_negatives

    return true_positives, false_positives, false_negatives
  end

  def minus(predicted, reference)
    @samples-=1
    predicted, reference = preprocess(predicted, reference)
    true_positives, false_positives, false_negatives=example_score(predicted, reference)

    @true_positives -= true_positives
    @false_positives -= false_positives
    @false_negatives -= false_negatives

    return true_positives, false_positives, false_negatives
  end

  def example_score(predicted, reference)
    true_positives=(predicted&reference).size
    false_positives=(predicted-reference).size
    false_negatives=(reference-predicted).size

    return true_positives, false_positives, false_negatives
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
    sum = @true_positives + @false_negatives +@false_negatives
    tn = @samples*@unique_types.size - sum

    return (tn+@true_positives).to_f/(tn +@true_positives + @false_negatives +@false_negatives)*100
  end

  def f1
    return 2 * precision * recall / (precision + recall)
  end

end

class SimpleScore < Score # MicroAveraged
  def preprocess(predicted, reference)
    if predicted.nil?
      predicted = []
    end
    predicted.reject! { |t| t==Thing.id }
    reference.reject! { |t| t==Thing.id }

    if predicted.size==0 && reference.size==0
      predicted = [Thing.id]
      reference = [Thing.id]
    end

    return predicted, reference
  end
end

class AprosioScore < Score
  def preprocess(predicted, reference)
    if predicted.nil?
      predicted_genls = [Thing]
    else
      predicted_genls = predicted.map { |cyc_id| @name_service.cyc.all_genls(@name_service.find_by_id(cyc_id)) }.flatten.uniq
    end
    reference_genls =reference.map { |cyc_id| @name_service.cyc.all_genls(@name_service.find_by_id(cyc_id)) }.flatten.uniq

    return predicted_genls, reference_genls
  end
end

class AprosioScoreNormalized < AprosioScore
  alias aprosio_example_score example_score

  def example_score(predicted, reference)
    tp, fp, fn=aprosio_example_score(predicted, reference)
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

class WeightedAveraged
  def initialize(name_service=nil)
    @scores = Hash.new { |hash, key| hash[key] = Errors.new }
    @samples=0
    @name_service=name_service
  end

  def score(predicted, reference, name=nil)
    @samples+=1
    predicted, reference = preprocess(predicted, reference)

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

  def minus(predicted, reference)
    @samples-=1
    predicted, reference = preprocess(predicted, reference)

    (predicted&reference).each do |type|
      @scores[type].tp-=1
    end
    (predicted-reference).each do |type|
      @scores[type].fp-=1
    end
    (reference-predicted).each do |type|
      @scores[type].fn-=1
    end
  end

  def preprocess(predicted, reference)
    if predicted.nil?
      predicted = []
    end
    predicted.reject! { |t| t==Thing.id }
    reference.reject! { |t| t==Thing.id }

    if predicted.size==0 && reference.size==0
      predicted = [Thing.id]
      reference = [Thing.id]
    end

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

class MacroAveraged < WeightedAveraged
  def precision
    sum = 0
    pr=0.0
    @scores.each do |type, errors|
      pri=errors.tp.to_f/(errors.tp+errors.fp)
      if pri.nan?
        pri=0.0
        next
      end
      pr+=pri
      sum+=1
    end
    return pr/sum*100
  end

  def recall
    sum = 0
    rc=0.0
    @scores.each do |type, errors|
      rci=errors.tp.to_f/(errors.tp+errors.fn)
      if rci.nan?
        rci=0.0
        next
      end
      rc+=rci
      sum+=1
    end
    return rc/sum*100
  end

  def accuracy
    sum = 0
    acc=0.0
    @scores.each do |type, errors|
      errors.tn = @samples-(errors.tp+errors.fp+errors.fn)
      acci=(errors.tp+errors.tn).to_f/(errors.tp+errors.fp+errors.fn+errors.tn)
      if acci.nan?
        acci=0.0
        next
      end
      acc+=acci
      sum+=1
    end
    return acc/sum*100
  end
end


class ConfusionMatrix
  def initialize(name_service=nil)
    @scores = Hash.new { |hash, key| hash[key] = Hash.new { |hash, key| hash[key] = Set.new } }
    @samples=0
    @name_service=name_service
  end

  def preprocess(predicted, reference)
    if predicted.nil?
      predicted = []
    end
    predicted.reject! { |t| t==Thing.id }
    reference.reject! { |t| t==Thing.id }

    return predicted, reference
  end

  def score(predicted, reference, name=nil)
    predicted, reference = preprocess(predicted, reference)


    (predicted&reference).each do |type|
      @scores[type][type] << name
    end
    (predicted-reference).each do |type|
      reference.each do |reference_type|
        @scores[reference_type][type]<< name
      end
    end
    (reference-predicted).each do |reference_type|
      predicted.each do |predicted_type|
        @scores[reference_type][predicted_type]<< name
      end
    end
  end

  def invert_confusion_matrix
    @inverted_confusion_matrix = Hash.new { |hash, key| hash[key] = Hash.new { |hash, key| hash[key] = Set.new } }
    @scores.each do |reference_type, predicted_types|
      predicted_types.each do |predicted_type, names|
        @inverted_confusion_matrix[predicted_type][reference_type] = names
      end
    end
  end

  def print(inverted=false, verbose=true)
    if inverted
      invert_confusion_matrix
      print_confusion_matrix(@inverted_confusion_matrix, verbose)
    else
      print_confusion_matrix(@scores, verbose)
    end
  end

  def print_confusion_matrix(confusion_matrix, verbose)
    confusion_matrix.sort_by { |reference_type, predicted_types| -predicted_types.map { |predicted_type, names| names.size }.inject { |sum, x| sum + x } }.each do |reference_type, predicted_types|
      sum = predicted_types.map { |predicted_type, names| names.size }.inject { |sum, x| sum + x }
      reference_type_name=@name_service.find_by_id(reference_type).name
      puts '%s %s' % [reference_type_name, sum]
      predicted_types.sort_by { |type, names| -names.size }.each do |predicted_type, names|
        predicted_type_name=@name_service.find_by_id(predicted_type).name
        count=names.size
        puts "- %s %s (%.1f%%)" % [reference_type_name==predicted_type_name ? '*'+predicted_type_name : predicted_type_name, count, count/sum.to_f*100]
        if verbose && reference_type_name!=predicted_type_name
          names.each do |name|
            puts '  - %s' % [name]
          end
        end
      end
      puts
    end
  end
end
