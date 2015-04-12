import java.io.FileReader;
import java.io.IOException;
import java.util.List;

import java.io.Reader;
import java.io.StringReader;
import java.io.BufferedReader;

import edu.stanford.nlp.ling.CoreLabel;
import edu.stanford.nlp.ling.HasWord;
import edu.stanford.nlp.process.CoreLabelTokenFactory;
import edu.stanford.nlp.process.DocumentPreprocessor;
import edu.stanford.nlp.process.PTBTokenizer;
import edu.stanford.nlp.process.TokenizerFactory;

// Prins first sentence of each line
// Usage: java -cp stanford-parser.jar:. FirstSentence FILE

public class FirstSentence {
  public static TokenizerFactory TokenizerFactory = PTBTokenizer.factory(new CoreLabelTokenFactory(),
                "normalizeParentheses=false,normalizeOtherBrackets=false,invertible=true");

  public static void main(String[] args) throws IOException {
    for (String arg : args) {
      BufferedReader br = new BufferedReader(new FileReader(arg));
      String line;
      while ((line = br.readLine()) != null) {
        Reader reader = new StringReader(line);
        DocumentPreprocessor dp = new DocumentPreprocessor(reader);
        dp.setTokenizerFactory(TokenizerFactory);
        int i=0;
        for (List sentence : dp) {
          ++i;
          System.out.println(edu.stanford.nlp.util.StringUtils.joinWithOriginalWhiteSpace(sentence));
          break;
        }
        if (i==0) System.out.println();
      }
      br.close();
    }
  }
}