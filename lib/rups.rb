require 'pathname'

require 'polyglot'
require 'edn'
require 'unparser'

require 'rups/transform'

module Rups
  Root = Pathname(__FILE__).dirname.parent

  def self.read(string)
    EDN.read(string)
  end

  def self.eval(sexp)
    Context.new.eval(sexp)
  end

  class Lambda < Struct.new(:arg_names, :body, :bindings)
    def call(*args)
      ctx = Context.new(bindings.merge(arg_names.zip(args).to_h))
      body.map(&ctx.method(:eval)).last
    end

    def to_proc
      method(:call).to_proc
    end
  end

  class Context
    attr_reader :env
    private :env

    def initialize(env = {})
      @env = env
      if env.empty?
        import Rups
        import Kernel
        import self
      end
    end

    def import(object)
      env.merge! object.public_methods.map{|name| [name, object.method(name)] }.to_h
    end

    define_method :def do |name, val|
      env[name.symbol] = val
    end

    define_method :lambda do |arg_names, *body|
      Lambda.new(arg_names.map(&:symbol), body, env.dup)
    end

    def quote(sexp) sexp end

    def eval(sexp)
      case sexp
      when Numeric, Symbol, String
        sexp
      when EDN::Type::Symbol
        if sexp.to_s =~ /\A[A-Z]/ && Kernel.const_defined?(fn.symbol)
          Kernel.const_get(sexp.symbol)
        else
          env[sexp.symbol]
        end
      when EDN::Type::List
        fn   = sexp[0]
        args = sexp.drop(1)

        case fn

        # don't do anything
        when EDN::Type::Symbol.new(:quote)
        when EDN::Type::Symbol.new(:lambda)

        # auto-quote the name
        when EDN::Type::Symbol.new(:def)
          args = [args[0]] + args.drop(1).map(&method(:eval))

        # sexp in function position
        when EDN::Type::List
          fn = eval(fn)
          args = args.map(&method(:eval))

        # evaluate the arguments
        else
          args = args.map(&method(:eval))
        end

        apply(fn, args)
      end
    end

    def apply(fn, args)
      case fn
      when EDN::Type::Symbol
        case fn.to_s
        when '.'
          args[0].public_send(*(args.drop(1)))
        when /\A\./
          args[0].public_send(fn.to_s[1..-1], *(args.drop(1)))
        when ->(fn) { fn =~ /\A[A-Z].*\.\z/ && Kernel.const_defined?(fn[0..-2]) }
          Kernel.const_get(fn.to_s[0..-2]).new(*args)
        else
          env.fetch(fn.symbol) { raise "Undefined identifier in function position: #{fn}" }
            .call(*args)
        end
      when Lambda
        fn.call(*args)
      else
        raise "Bad function: #{fn.inspect}"
      end
    end
  end

  # def self.transform(code)
  #   Transform.call(code)
  # end

  module Loader
    def self.load(filename, options = nil, &block)
      ctx = Rups::Context.new
      EDN::Reader.new(open(filename)).each do |form|
        ctx.eval(form)
        #eval(Unparser.unparse(Rups.transform(form)))
      end
    end
  end

end

Polyglot.register("rp", Rups::Loader)
