(def defn
     (lambda [name args body]
       (eval
        (list (quote def) name (list (quote lambda) args body)))))


((lambda [x] (puts x)) 7)

(apply (quote defn) (quote (times [x] (puts x))))

(times 5)
