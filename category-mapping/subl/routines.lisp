(define symbol-str (symbol)
   (ret (cdr (caar 
      (cyc-query `(#$prettyString-Canonical ,symbol ?w) #$EnglishMt)
   )))
)

(define str-symbol (str)
   (ret (cdr (caar 
      (cyc-query `(#$prettyString-Canonical ?s ,str) #$EnglishMt)
   )))
)

(define str-symbols (str)
   (ret 
      (cyc-query `(#$prettyString ?s ,str) #$EnglishMt)
   )
)

(define strCanonical-symbols (str)
   (ret 
      (cyc-query `(#$prettyString-Canonical ?s ,str) #$EnglishMt)
   )
)