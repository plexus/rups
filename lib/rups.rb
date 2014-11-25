require 'pathname'

require 'polyglot'
require 'edn'
require 'unparser'

require 'rups/transform'

module Rups

  Root = Pathname(__FILE__).dirname.parent

  def self.transform(code)
    Transform.call(code)
  end

  module Loader
    def self.load(filename, options = nil, &block)
      EDN::Reader.new(open(filename)).each do |form|
        eval(Unparser.unparse(Rups.transform(form)))
      end
    end
  end

end

Polyglot.register("rp", Rups::Loader)
