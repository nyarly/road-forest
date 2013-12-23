Gem::Specification.new do |spec|
  spec.name		= "roadforest"
  spec.version		= "0.0.3"
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

  # Do this: y$jj@"
  # !!find lib bin doc spec spec_help -not -regex '.*\.sw.' -type f 2>/dev/null
  spec.files    = %w[
    lib/roadforest/rdf/graph-store.rb
    lib/roadforest/rdf/normalization.rb
    lib/roadforest/rdf/focus-list.rb
    lib/roadforest/rdf/graph-copier.rb
    lib/roadforest/rdf/access-manager.rb
    lib/roadforest/rdf/source-rigor.rb
    lib/roadforest/rdf/graph-focus.rb
    lib/roadforest/rdf/etagging.rb
    lib/roadforest/rdf/source-rigor/null-investigator.rb
    lib/roadforest/rdf/source-rigor/credence.rb
    lib/roadforest/rdf/source-rigor/credence/any.rb
    lib/roadforest/rdf/source-rigor/credence/role-if-available.rb
    lib/roadforest/rdf/source-rigor/credence/none-if-role-absent.rb
    lib/roadforest/rdf/source-rigor/http-investigator.rb
    lib/roadforest/rdf/source-rigor/investigator.rb
    lib/roadforest/rdf/source-rigor/credence-annealer.rb
    lib/roadforest/rdf/post-focus.rb
    lib/roadforest/rdf/investigation.rb
    lib/roadforest/rdf/vocabulary.rb
    lib/roadforest/rdf/document.rb
    lib/roadforest/rdf/resource-pattern.rb
    lib/roadforest/rdf/parcel.rb
    lib/roadforest/rdf/resource-query.rb
    lib/roadforest/http/message.rb
    lib/roadforest/http/graph-response.rb
    lib/roadforest/http/adapters/excon.rb
    lib/roadforest/http/graph-transfer.rb
    lib/roadforest/resource/rdf/list.rb
    lib/roadforest/resource/rdf/parent-item.rb
    lib/roadforest/resource/rdf/read-only.rb
    lib/roadforest/resource/rdf/leaf-item.rb
    lib/roadforest/resource/http/form-parsing.rb
    lib/roadforest/resource/role/writable.rb
    lib/roadforest/resource/role/has-children.rb
    lib/roadforest/resource/rdf.rb
    lib/roadforest/test-support/http-client.rb
    lib/roadforest/test-support/trace-formatter.rb
    lib/roadforest/test-support/matchers.rb
    lib/roadforest/test-support/dispatcher-facade.rb
    lib/roadforest/test-support/remote-host.rb
    lib/roadforest/server.rb
    lib/roadforest/application/services-host.rb
    lib/roadforest/application/path-provider.rb
    lib/roadforest/application/parameters.rb
    lib/roadforest/application/dispatcher.rb
    lib/roadforest/application/route-adapter.rb
    lib/roadforest/model.rb
    lib/roadforest/models.rb
    lib/roadforest/test-support.rb
    lib/roadforest/rdf.rb
    lib/roadforest/blob-model.rb
    lib/roadforest/utility/class-registry.rb
    lib/roadforest/content-handling/type-handlers/jsonld.rb
    lib/roadforest/content-handling/media-type.rb
    lib/roadforest/content-handling/engine.rb
    lib/roadforest/application.rb
    lib/roadforest/remote-host.rb
    lib/roadforest.rb
    examples/file-management.rb
    spec/graph-store.rb
    spec/focus-list.rb
    spec/graph-copier.rb
    spec/rdf-parcel.rb
    spec/media-types.rb
    spec/rdf-normalization.rb
    spec/excon-adapater.rb
    spec/update-focus.rb
    spec/client.rb
    spec/form-parsing.rb
    spec/credence-annealer.rb
    spec/full-integration.rb
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

  spec.add_dependency("rdf", "~> 1.1.0")
  spec.add_dependency("json-ld", "~> 1.0.8")
  spec.add_dependency("rdf-rdfa", "~> 1.1.0")

  spec.add_dependency("webmachine", ">= 1.1.0")
  spec.add_dependency("addressable", "~> 2.2.8")
  spec.add_dependency("excon", "~> 0.25")

  spec.add_dependency("tilt", ">= 1.3.6")
  spec.add_dependency("valise", ">= 0.9.1")
end
