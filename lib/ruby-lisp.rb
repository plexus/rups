

module RubyLisp
  class Eval
    def call(sexp)
      ruby = to_ruby(sexp)
      code = Unparser.unparse(ruby)
      eval(code)
    end

    def to_ruby(node)
      case node
      when Integer
        s(:int, node)
      when String
        s(:str, node)
      when Symbol
        s(:sym, node)
      when Float
        s(:float, node)
      when AST::Node
        send("handle_#{node.type}", node)
      end
    end

    def parse_ruby(str)
      Parser::CurrentRuby.parse(str)
    end

    def handle_list(node)
      children = node.children
      type = children.first
      rest = children.drop(1)
      recurse = method(:to_ruby)
      case type
      when :class, :module
        name = parse_ruby(rest[0].to_s)
        rest = rest.drop(1)
        superclass = nil
        s(type, name, superclass, *rest.map(&recurse))
      when :defn
        name = rest[0]
        args = s(:args, *rest[1].children.map {|arg| s(:arg, recurse(arg))})
        body = rest.drop(2).map(&recurse)
        s(:def, name, args, *body)
      when ->(sym) { sym.to_s =~ /^\.([\w_]+)/ } # (.foo)
        target = recurse.(children[1])
        name   = $1.to_sym
        body = children.drop(2).map(&recurse)
        s(:send, target, name, *body)
      when ->(sym) { sym.to_s =~ /([\w_]+)\.$/ } # (Foo.)
        klass = $1
        body = children.drop(1).map(&recurse)
        s(:send, s(:const, nil, klass), :new, *body)
      else
        body = children.drop(1).map(&recurse)
        s(:send, nil, type, *body)
      end
    end

    def unpack_symbol(str)
      str.sub(/^:/, '').to_sym
    end

    def s(type, *rest)
      Parser::AST::Node.new(type, rest)
    end
  end

  def self.eval(sexp)
    Eval.new.call(sexp)
  end

  def self.read(string)
    sexpistol.parse_string(string)
  end

  def self.sexpistol
    @parser ||= Sexpistol.new
  end

  module Loader
    def self.load(filename, options = nil, &block)
      RubyLisp.read(File.read(filename)).children.each(&RubyLisp.method(:eval))
    end
  end
end
