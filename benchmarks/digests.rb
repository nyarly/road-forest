require 'openssl'
require 'benchmark'

digest_classes = []
ObjectSpace::each_object(Class) do |klass|
  if klass < OpenSSL::Digest
    digest_classes << klass
  end
end

digests = {}
digest_classes.each do |klass|
  begin
    digest = klass.new
    digests[digest.name] = digest
  rescue
  end
end

Strings = (<<-EOS).each_line.to_a
a;sldkfja;sdlfj;asldkfj
as;ldkfja;lsdkfj
a;sdlf;sldkfj;alskjf;aslkdfj
a;sldfkja;slkdfj;alskdfj;alskdfj
asdlkfj;laskdjf;lasdjf;alskdjf;alsd
;alskdfja;sldkfj;aslkdfja;slkdfj
a;sdlkfja;sldfja;sldfj;alskdjf;alskfj
a;sldkfj;aslkdjfa;sldkfj
EOS

COUNT = 100000

p Strings

longest_name = digests.keys.map(&:length).max

def digest_with(digester)
  digester.reset
  Strings.each do |string|
    digester << string
  end
  digester.base64digest
end

Benchmark.bm do |bench|
  digests.each do |name, digester|
    bench.report "#{digester.name.ljust(longest_name)} :" do
      COUNT.times do
        digest_with(digester)
      end
    end
    puts "  " + digest_with(digester)
  end
end
