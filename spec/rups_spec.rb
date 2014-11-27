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
    '(defmacro two-times [x] [x x]) (two-times 3)' => [3, 3],
    '(defmacro defn [name args body]
       (list (quote def) name (list (quote fn) args body)))
     (defn add [x y]
       (.+ x y))
     (add 2 3)' => 5,
    '(do puts)' => Rups::Block.new(Kernel.method(:puts)),
    '(. 3 next)' => 4,
    '(. [1 2 3] map (do [x] (.* x x)))' => [1, 4, 9],
    '(.map [1 2 3] (do [x] (.* x x)))' => [1, 4, 9],
    '(+ 1 2 3)' => 6

  }.each do |rups, result|
    specify(rups) {
      expect(Rups::Loader.eval(StringIO.new(rups))).to eql result
    }
  end
end