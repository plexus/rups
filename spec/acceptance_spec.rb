require 'rspec'
require 'rups'

Pathname.glob(Rups::Root.join('spec/acceptance/*.rp')).each do |infile|
  outfile = infile.dirname.join("#{infile.basename('.rp')}.rb")

  describe infile.basename do
    let(:ruby_ast) { Parser::CurrentRuby.parse(outfile.read) }
    let(:rups_ast) { Rups::Transform.call(EDN.read(infile.read)) }
    specify { expect(ruby_ast).to eql rups_ast }
  end
end
