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
  lib/road-forest/rdf/graph-store.rb
  lib/road-forest/rdf/normalization.rb
  lib/road-forest/rdf/focus-list.rb
  lib/road-forest/rdf/graph-reading.rb
  lib/road-forest/rdf/graph-copier.rb
  lib/road-forest/rdf/context-fascade.rb
  lib/road-forest/rdf/source-rigor.rb
  lib/road-forest/rdf/graph-focus.rb
  lib/road-forest/rdf/source-rigor/null-investigator.rb
  lib/road-forest/rdf/source-rigor/credence.rb
  lib/road-forest/rdf/source-rigor/credence/any.rb
  lib/road-forest/rdf/source-rigor/credence/role-if-available.rb
  lib/road-forest/rdf/source-rigor/credence/none-if-role-absent.rb
  lib/road-forest/rdf/source-rigor/http-investigator.rb
  lib/road-forest/rdf/source-rigor/investigator.rb
  lib/road-forest/rdf/source-rigor/credence-annealer.rb
  lib/road-forest/rdf/update-focus.rb
  lib/road-forest/rdf/vocabulary.rb
  lib/road-forest/rdf/document.rb
  lib/road-forest/rdf/focus-wrapping.rb
  lib/road-forest/rdf/resource-pattern.rb
  lib/road-forest/rdf/parcel.rb
  lib/road-forest/rdf/resource-query.rb
  lib/road-forest/http/message.rb
  lib/road-forest/http/graph-response.rb
  lib/road-forest/http/adapters/excon.rb
  lib/road-forest/http/graph-transfer.rb
  lib/road-forest/resource/rdf/list.rb
  lib/road-forest/resource/rdf/parent-item.rb
  lib/road-forest/resource/rdf/read-only.rb
  lib/road-forest/resource/rdf/leaf-item.rb
  lib/road-forest/resource/http/form-parsing.rb
  lib/road-forest/resource/role/writable.rb
  lib/road-forest/resource/role/has-children.rb
  lib/road-forest/resource/handlers.rb
  lib/road-forest/resource/rdf.rb
  lib/road-forest/test-support/matchers.rb
  lib/road-forest/test-support/remote-host.rb
  lib/road-forest/server.rb
  lib/road-forest/application/services-host.rb
  lib/road-forest/application/path-provider.rb
  lib/road-forest/application/parameters.rb
  lib/road-forest/application/dispatcher.rb
  lib/road-forest/application/results.rb
  lib/road-forest/application/route-adapter.rb
  lib/road-forest/model.rb
  lib/road-forest/test-support.rb
  lib/road-forest/rdf.rb
  lib/road-forest/utility/class-registry.rb
  lib/road-forest/content-handling/type-handlers/jsonld.rb
  lib/road-forest/content-handling/media-type.rb
  lib/road-forest/content-handling/engine.rb
  lib/road-forest/application.rb
  lib/road-forest/remote-host.rb
  spec/graph-store.rb
  spec/graph-copier.rb
  spec/rdf-parcel.rb
  spec/media-types.rb
  spec/update-focus.rb
  spec/client.rb
  spec/credence-annealer.rb
  ]

  spec.test_file        = "spec_support/gem_test_suite.rb"
  spec.licenses = ["MIT"]
  spec.require_paths = %w[lib/]
  spec.rubygems_version = "1.3.5"

  spec.has_rdoc		= true
  spec.extra_rdoc_files = Dir.glob("doc/**/*")
  spec.rdoc_options	= %w{--inline-source }
  spec.rdoc_options	+= %w{--main doc/README }
  spec.rdoc_options	+= ["--title", "#{spec.name}-#{spec.version} Documentation"]

  spec.add_dependency("rdf", ">= 1.0.4")
  spec.add_dependency("json-ld", "~> 1.0.0")

  spec.add_dependency("webmachine", ">= 1.1.0")
  spec.add_dependency("addressable", "~> 2.2.8")
  spec.add_dependency("tilt", ">= 1.3.6")
  spec.add_dependency("valise", ">= 0.9.1")
end
