require 'rups'

describe do
  {
    '(.+ 3 3)' => 6,
    '((fn [x y] (.+ x y)) 4 7)' => 11,
    '(def x :foo)
     (def y ((fn [x y]
              (.+ x y)) 4 7))
     [x, y]' => [:foo, 11],
    '(apply (fn [x y z] (.* (.+ x y) z)) (list 1 2 3))' => 9,
    '(begin (.+ 2 2) (.+ 3 3))' => 6,
    '(def x 0)
     (defmacro two-times [x]
       (list (quote begin) x x))
     (two-times (def x (.+ x 1))) x' => 2,
    '(defmacro defn [name args body]
       (list (quote def) name (list (quote fn) args body)))
     (defn add [x y]
       (.+ x y))
     (add 2 3)' => 5,
    '(do puts)' => Rups::Block.new(Kernel.method(:puts)),
    '(. 3 next)' => 4,
    '(. [1 2 3] map (do [x] (.* x x)))' => [1, 4, 9],
    '(.map [1 2 3] (do [x] (.* x x)))' => [1, 4, 9],
    '(+ 1 2 3)' => 6,
    '(str "foo" 7 :bar " " "x")' => "foo7bar x",
    '(apply list 1 2 3 (quote (4 5 6)))' => Rups::List[1,2,3,4,5,6],
    '(defn local-def [x]
       (def y x)
       y)
     (def y 7)
     [(local-def 9) y]' => [9, 7],
    "(apply + '(4 5 6))" => 15,
    "`(1 2 (+ 3 4) ~(+ 3 4))" => Rups::List[1,2, Rups::List[Rups::Symbol.new(:+), 3, 4], 7],
    "`[:foo :bar [0 ~@(list 1 2 3) 4]]" => [:foo, :bar, [0, 1, 2, 3, 4]]

  }.each do |rups, result|
    specify(rups) {
      expect(Rups::Loader.eval(StringIO.new(rups))).to eql result
    }
  end
end
