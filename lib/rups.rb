require 'pathname'

require 'polyglot'
require 'edn'
require 'unparser'
require 'concord'

module Rups
  Root = Pathname(__FILE__).dirname.parent

  Symbol = EDN::Type::Symbol
  class Symbol
    def inspect
      to_sym.to_s
    end
  end

  List = EDN::Type::List
  class List
    def inspect
      "(#{map(&:inspect).join(' ')})"
    end
  end

  def self.read(string)
    EDN.read(string)
  end

  def self.eval(sexp)
    Context.new.eval(sexp)
  end

  class Lambda
    include Concord.new(:arg_names, :body, :bindings)

    def call(*args)
      ctx = Context.new(bindings)
      arg_names.each_with_index do |name, idx|
        if name.to_sym == :&
          ctx.def arg_names[idx+1], args[idx..-1]
          break
        else
          ctx.def name, args[idx]
        end
      end
      body.map(&ctx.method(:eval)).last
    end

    def inspect
      "(lambda [#{arg_names.join(' ')}] #{body.inspect})"
    end

    def to_proc
      method(:call).to_proc
    end
  end

  class Macro < Lambda
  end

  class Block
    include Concord::Public.new(:callable)
  end

  class Context
    attr_reader :env
    private :env

    def initialize(env = {})
      @env = env
      if env.empty?
        import Rups
        import Kernel
      end
      import self
    end

    def lookup(sym, &block)
      env.fetch(sym.to_sym) { block.call if block_given? }
    end

    def import(object)
      object.public_methods.each do |name|
        self.def name, object.method(name)
      end
    end

    # def ns(name, *body)
    #   m = Module.new { extend self }
    #   defn = ->(name, *args) { m.module_eval { define_method(name.symbol, &lamda(*args)) } }
    #   ctx = Context.new(env.merge(:defn => defn, name => m, ns: name))
    #   env[name] = m
    # end

    define_method :def do |name, val|
      @env = env.merge(name.to_sym => val)
    end

    define_method :"." do |receiver, message, *args|
      receiver = eval(receiver)
      args = args.map(&method(:eval))

      block = args.last.is_a?(Block) ? args.pop.callable : nil
      receiver.public_send(message.to_sym, *args, &block)
    end

    define_method :do do |*args|
      if args.length == 1
        Block.new(eval(args[0]))
      else
        Block.new(lambda(*args))
      end
    end

    def lambda(arg_names, *body)
      Lambda.new(arg_names, body, env)
    end

    def defmacro(name, arg_names, *body)
      self.def name, Macro.new(arg_names, body, env)
    end

    def list(*args)
      List.new(*args)
    end

    def begin(*args)
      args.last
    end

    def quote(sexp) sexp end

    def eval(sexp)
      case sexp
      when Numeric,::Symbol, String
        sexp
      when Rups::Symbol
        if sexp.to_s =~ /\A[A-Z]/ && Kernel.const_defined?(fn.symbol)
          Kernel.const_get(sexp.symbol)
        else
          lookup(sexp)
        end
      when List
        fn   = sexp[0]
        args = sexp.drop(1)

        case fn

        when Rups::Symbol
          case fn.to_sym

          # Pass on unevaluated forms
          when :quote, :lambda, :defmacro, :".", :do
            return public_send(fn.to_sym, *args)

          when :fn
            return lambda(*args)

          when /^\.(.+)/
            return self.public_send(".", args[0], Rups::Symbol.new($1.to_sym), *args.drop(1))

          # auto-quote the name
          when :def
            fn = lookup(fn) { raise "Undefined identifier in function position: #{fn}" }
            args[0] = List.new(Rups::Symbol.new(:quote), args[0])

          else
            fn = lookup(fn) { raise "Undefined identifier in function position: #{fn}" }
          end

        # sexp in function position
        when List
          fn = eval(fn)
        end

        apply(fn, args)
      when Array
        sexp.map(&method(:eval))
      end
    end

    def apply(fn, *args)
      list = args.pop
      args = List[*args, *list]
      case fn
      when Macro
        sexp = fn.call(*args)
        eval(sexp)
      else
        args = args.map(&method(:eval))
        fn.call(*args)
      end
    end
  end

  module Loader
    def self.load(filename, options = nil, &block)
      io = filename.respond_to?(:read) ? filename : open(filename)
      eval(io)
    end

    def self.eval(io, ctx = nil)
      if ctx == nil
        ctx = Rups::Context.new
        eval(StringIO.new(BOOTSTRAP), ctx)
      end
      result = nil
      EDN::Reader.new(io).each do |form|
        result = ctx.eval(form)
      end
      result
    end
  end

end

Polyglot.register("rp", Rups::Loader)

BOOTSTRAP = <<EOF

(defmacro defn [name args & body]
  (list (quote def) name (.concat (list (quote lambda) args) body)))

(defn reduce [f val coll]
  (.reduce coll val (do f)))

(defn + [& args]
  (reduce (fn [x y] (.+ x y)) 0 args))

(defmacro str [& args]
  (list (quote .join) args))



EOF
