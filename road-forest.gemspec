Gem::Specification.new do |spec|
  spec.name		= "road-forest"
  spec.version		= "0.0.1"
  author_list = {
    "Judson Lester" => 'nyarly@gmail.com'
  }
  spec.authors		= author_list.keys
  spec.email		= spec.authors.map {|name| author_list[name]}
  spec.summary		= "An RDF+ReST web framework"
  spec.description	= <<-EndDescription
  RoaD FoReST is a web framework designed to use the Resource Description
  Framework to accomplish Representative State Transfer. I'm stoked, even if
  everyone else is rolling their eyes.

  This gem represents the Ruby implementation of both client and server. The
  next step will be to set up an adapter for a Javascript framework.
  EndDescription

  spec.rubyforge_project= spec.name.downcase
  spec.homepage        = "http://nyarly.github.com/#{spec.name.downcase}"
  spec.required_rubygems_version = Gem::Requirement.new(">= 0") if spec.respond_to? :required_rubygems_version=

  # Do this: y$@"
  # !!find lib bin doc spec spec_help -not -regex '.*\.sw.' -type f 2>/dev/null
  spec.files		= %w[
  ]

  spec.test_file        = "spec_help/gem_test_suite.rb"
  spec.licenses = ["MIT"]
  spec.require_paths = %w[lib/]
  spec.rubygems_version = "1.3.5"

  spec.has_rdoc		= true
  spec.extra_rdoc_files = Dir.glob("doc/**/*")
  spec.rdoc_options	= %w{--inline-source }
  spec.rdoc_options	+= %w{--main doc/README }
  spec.rdoc_options	+= ["--title", "#{spec.name}-#{spec.version} Documentation"]

  spec.add_dependency("rdf", ">= 1.0.4")
  spec.add_dependency("webmachine", ">= 1.1.0")
  spec.add_dependency("tilt", ">= 1.3.6")
  spec.add_dependency("valise", ">= 0.9.1")
end
