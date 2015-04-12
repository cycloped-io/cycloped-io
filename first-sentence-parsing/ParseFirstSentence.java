import org.apache.commons.csv.*;
import java.io.*;
import java.util.*;

import edu.stanford.nlp.dcoref.CorefChain;
import edu.stanford.nlp.dcoref.CorefCoreAnnotations;
import edu.stanford.nlp.io.*;
import edu.stanford.nlp.ling.*;
import edu.stanford.nlp.pipeline.*;
import edu.stanford.nlp.semgraph.SemanticGraph;
import edu.stanford.nlp.semgraph.SemanticGraphCoreAnnotations;
import edu.stanford.nlp.trees.*;
import edu.stanford.nlp.util.*;

// TODO This implementation is not multithreaded.
// First argument is CSV file with two columns: article name and abstract. Second argument is output CSV file. Output is:
// article name, first sentence, parse tree, dependencies.

public class ParseFirstSentence {
  public static void main(String[] args) {
    String modelPath = "edu/stanford/nlp/models/srparser/englishSR.ser.gz";
    String taggerPath = "edu/stanford/nlp/models/pos-tagger/english-left3words/english-left3words-distsim.tagger";
    
    Properties props = new Properties();
    props.put("annotators", "tokenize, ssplit");
    //props.put("parse.model", "edu/stanford/nlp/models/srparser/englishSR.ser.gz");
    //props.put("ssplit.eolonly", "true");
    StanfordCoreNLP pipeline = new StanfordCoreNLP(props);
    
    
    Properties props2 = new Properties();
    props2.put("annotators", "tokenize, ssplit, pos, parse");
    props2.put("parse.model", "edu/stanford/nlp/models/srparser/englishSR.ser.gz");
    props2.put("ssplit.eolonly", "true");
    StanfordCoreNLP pipeline2 = new StanfordCoreNLP(props2);
  
    PrintWriter out = new PrintWriter(System.out);
  
    CSVFormat csvFileFormat = CSVFormat.DEFAULT.withHeader("name", "abstract");
    
    
  
    Annotation annotation;
  
 
    try {
      //System.out.println(args[0]);
      FileWriter fileWriter = new FileWriter(args[1]);
      CSVPrinter csvFilePrinter = new CSVPrinter(fileWriter, CSVFormat.DEFAULT);
      
      Reader in = new FileReader(args[0]);
      Iterable<CSVRecord> records = csvFileFormat.parse(in);
      for (CSVRecord record : records) {
	  String name = record.get("name");
	  String paragraph = record.get("abstract");
	  //System.out.println(record);
	  annotation = new Annotation(paragraph);
	  pipeline.annotate(annotation);
	  
	  List<CoreMap> sentences = annotation.get(CoreAnnotations.SentencesAnnotation.class);
	  
	  List row = new ArrayList<String>();
	  row.add(name);
	  
	  if (sentences != null && ! sentences.isEmpty()) {
	    CoreMap sentence = sentences.get(0);
	    List <CoreMap> sentenceList = new ArrayList<CoreMap>();
	    sentenceList.add(sentence);
	    Annotation annotation2 = new Annotation(sentenceList);
	    pipeline2.annotate(annotation2);
	    
	    List<CoreMap> sentences2 = annotation2.get(CoreAnnotations.SentencesAnnotation.class);
	    CoreMap sentence2 = sentences2.get(0);
	    row.add(sentence2.toString());
	    Tree tree = sentence2.get(TreeCoreAnnotations.TreeAnnotation.class);
	    row.add(tree.pennString());
	    row.add(sentence2.get(SemanticGraphCoreAnnotations.CollapsedCCProcessedDependenciesAnnotation.class).toString(SemanticGraph.OutputFormat.LIST));
	  }
	  else {
	    out.println();
	  }
	  csvFilePrinter.printRecord(row);
	  
	  
      }
      fileWriter.close();
 
    } catch (FileNotFoundException e) {
      out.println(e);
    
    } catch (IOException e) {
      out.println(e);
    }
    
  }
}