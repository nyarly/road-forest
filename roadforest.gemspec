Gem::Specification.new do |spec|
  spec.name		= "roadforest"
  spec.version		= "0.5"
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
    lib/roadforest-client.rb
    lib/roadforest/http/message.rb
    lib/roadforest/http/graph-response.rb
    lib/roadforest/http/keychain.rb
    lib/roadforest/http/adapters/excon.rb
    lib/roadforest/http/user-agent.rb
    lib/roadforest/http/graph-transfer.rb
    lib/roadforest/graph/normalization.rb
    lib/roadforest/graph/focus-list.rb
    lib/roadforest/graph/graph-copier.rb
    lib/roadforest/graph/graph-focus.rb
    lib/roadforest/graph/etagging.rb
    lib/roadforest/graph/post-focus.rb
    lib/roadforest/graph/vocabulary.rb
    lib/roadforest/graph/path-vocabulary.rb
    lib/roadforest/graph/document.rb
    lib/roadforest/graph/access-manager.rb
    lib/roadforest/graph.rb
    lib/roadforest/path-matcher.rb
    lib/roadforest/resource/role/writable.rb
    lib/roadforest/resource/role/has-children.rb
    lib/roadforest/resource/list.rb
    lib/roadforest/resource/parent-item.rb
    lib/roadforest/resource/read-only.rb
    lib/roadforest/resource/leaf-item.rb
    lib/roadforest/test-support/http-client.rb
    lib/roadforest/test-support/trace-formatter.rb
    lib/roadforest/test-support/matchers.rb
    lib/roadforest/test-support/dispatcher-facade.rb
    lib/roadforest/test-support/remote-host.rb
    lib/roadforest/authorization.rb
    lib/roadforest/server.rb
    lib/roadforest/application/services-host.rb
    lib/roadforest/application/path-provider.rb
    lib/roadforest/application/parameters.rb
    lib/roadforest/application/dispatcher.rb
    lib/roadforest/application/route-adapter.rb
    lib/roadforest/resource.rb
    lib/roadforest/source-rigor.rb
    lib/roadforest/interfaces.rb
    lib/roadforest/type-handlers/rdf-handler.rb
    lib/roadforest/type-handlers/rdfa.rb
    lib/roadforest/type-handlers/handler.rb
    lib/roadforest/type-handlers/rdfa-writer.rb
    lib/roadforest/type-handlers/rdfpost.rb
    lib/roadforest/type-handlers/rdfa-writer/render-engine.rb
    lib/roadforest/type-handlers/rdfa-writer/subject-environment.rb
    lib/roadforest/type-handlers/rdfa-writer/render-environment.rb
    lib/roadforest/type-handlers/rdfa-writer/property-environment.rb
    lib/roadforest/type-handlers/rdfa-writer/document-environment.rb
    lib/roadforest/type-handlers/rdfa-writer/environment-decorator.rb
    lib/roadforest/type-handlers/rdfa-writer/object-environment.rb
    lib/roadforest/type-handlers/jsonld.rb
    lib/roadforest/test-support.rb
    lib/roadforest/debug.rb
    lib/roadforest/source-rigor/graph-store.rb
    lib/roadforest/source-rigor/null-investigator.rb
    lib/roadforest/source-rigor/rigorous-access.rb
    lib/roadforest/source-rigor/investigation.rb
    lib/roadforest/source-rigor/credence.rb
    lib/roadforest/source-rigor/engine.rb
    lib/roadforest/source-rigor/credence/any.rb
    lib/roadforest/source-rigor/credence/role-if-available.rb
    lib/roadforest/source-rigor/credence/none-if-role-absent.rb
    lib/roadforest/source-rigor/resource-pattern.rb
    lib/roadforest/source-rigor/http-investigator.rb
    lib/roadforest/source-rigor/investigator.rb
    lib/roadforest/source-rigor/parcel.rb
    lib/roadforest/source-rigor/credence-annealer.rb
    lib/roadforest/source-rigor/resource-query.rb
    lib/roadforest/augmentations.rb
    lib/roadforest/utility/class-registry.rb
    lib/roadforest/content-handling/media-type.rb
    lib/roadforest/content-handling/handler-wrap.rb
    lib/roadforest/content-handling/common-engines.rb
    lib/roadforest/content-handling/engine.rb
    lib/roadforest/content-handling.rb
    lib/roadforest/augment/augmenter.rb
    lib/roadforest/augment/augmentation.rb
    lib/roadforest/augment/affordance.rb
    lib/roadforest/http.rb
    lib/roadforest/interface/rdf.rb
    lib/roadforest/interface/blob.rb
    lib/roadforest/interface/application.rb
    lib/roadforest/application.rb
    lib/roadforest/remote-host.rb
    lib/roadforest/templates/min/subject.haml
    lib/roadforest/templates/min/doc.haml
    lib/roadforest/templates/min/property-values.haml
    lib/roadforest/templates/base/subject.haml
    lib/roadforest/templates/base/property-value.haml
    lib/roadforest/templates/base/doc.haml
    lib/roadforest/templates/base/property-values.haml
    lib/roadforest/templates/rdfpost-curie.haml
    lib/roadforest/templates/distiller/subject.haml
    lib/roadforest/templates/distiller/nil-object.haml
    lib/roadforest/templates/distiller/property-value.haml
    lib/roadforest/templates/distiller/doc.haml
    lib/roadforest/templates/distiller/property-values.haml
    lib/roadforest/templates/uri-object.haml
    lib/roadforest/templates/xml-literal-object.haml
    lib/roadforest/templates/affordance-doc.haml
    lib/roadforest/templates/object.haml
    lib/roadforest/templates/node-object.haml
    lib/roadforest/templates/nil-object.haml
    lib/roadforest/templates/affordance-property-values.haml
    lib/roadforest/templates/affordance-subject.haml
    lib/roadforest/templates/affordance-uri-object.haml
    lib/roadforest.rb
    lib/roadforest-common.rb
    lib/roadforest-testing.rb
    lib/roadforest-server.rb

    spec/graph-store.rb
    spec/authorization.rb
    spec/focus-list.rb
    spec/graph-copier.rb
    spec/rdfa-handler.rb
    spec/rdf-parcel.rb
    spec/affordances-flow.rb
    spec/media-types.rb
    spec/source-rigor.rb
    spec/.ctrlp-root
    spec/keychain.rb
    spec/rdf-normalization.rb
    spec/update-focus.rb
    spec/client.rb
    spec/excon-adapter.rb
    spec/rdfpost.rb
    spec/affordance-augmenter.rb
    spec/credence-annealer.rb
    spec/full-integration.rb

    examples/file-management.rb
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
  spec.add_dependency("valise", "~> 1.1")
end
