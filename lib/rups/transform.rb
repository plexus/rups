module Rups
  module Transform
    module_function

    def call(form)
      case form
      when Integer
        s(:int, form)
      when String
        s(:str, form)
      when Symbol
        s(:sym, form)
      when Float
        s(:float, form)
      when EDN::Type::Symbol
        form.symbol
      when EDN::Type::List
        s(:send, nil, *form.map(&method(:call)))
      end
    end

    def s(type, *rest)
      Parser::AST::Node.new(type, rest)
    end

  end
end
