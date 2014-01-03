require 'roadforest/rdf'
require 'rdf'

module RoadForest::RDF
  module Vocabulary
    class RF < ::RDF::Vocabulary("http://lrdesign.com/rdf/roadforest#")
      property :Impulse
      property :impulse
      property :begunAt
    end
  end

  class Af < ::RDF::StrictVocabulary("http://judsonlester.info/affordance#")
    # Class definitions
    property :Affordance, :comment =>
      %(Base class for all affordances)
    property :Control
    property :Create, :comment =>
      %(Triggering this affordance implies a request to create a new
        resource)
    property :Embed, :comment =>
      %(A resource that should be properly displayed in-line rather
        than provided as a hyperlink)
    property :Idempotent, :comment =>
      %(An affordance that will cause a change, but that can be
        repeated without further hazard)
    property :Metadata, :comment =>
      %(There is extra metadata available about this resource)
    property :Mutate, :comment =>
      %(Triggering this affordance expresses a desire to make changes
        to a resource)
    property :Navigation, :comment =>
      %(A link to another resource. The assumption is that otherwise
        undescribed URLs have a navigation affordance)
    property :Null, :comment =>
      %(The provided affordance is null. i.e. not dereferenceable, no
        actions provided)
    property :Parameter
    property :Remove, :comment =>
      %(Triggering this affordance is a request to delete the resource)
    property :Safe, :comment =>
      %(A safe affordance - it is asserted that no change will be
        triggered by activating the affordance)
    property :Unsafe, :comment =>
      %(Affordances whose effects cannot be simply modeled and should
        be triggered with care)
    property :Update, :comment =>
      %(Acting on this affordance will update the targeted resource.
        Repeated updates will have not further effect)

    # Property definitions
    property :authorizedBy, :comment =>
      %(Opaque descriptors of authorization tokens - resource can be
        dereferenced by users with that token. It's recommended that
        the tokens be defreferenceable, and that they be accessible
        iff the user is authorized to activate the affordance in
        question.)
    property :controlName, :comment =>
      %(Valid values are limited per application. Examples include
        'Media-Type', 'Encoding' or 'EntityTag')
    property :controlValue
    property :controlledBy
    property :parameterName
    property :parameterRange
    property :payload, :comment =>
      %(Points to a the name of a named graph that describes the
        possible payload of the affordance. Graph might need a
        different entailment - allowing e.g. a blank node to be the
        object of a property whose domain is Literal... i.e. only
        using RDF entailment, not RDFS)
    property :target, :comment =>
      %(Could be a templated URL, or a URL resource. If not a
        template, but the Affordance has one or more uriVariable
        properties, the implication is that the target resource should
        be used as the basis of a URI template by appending
        \(?name,other,...\) to the URI.)
    property :uriVariable, :comment =>
      %(When the object is list, the members of the list should be
        Parameters, the the list order implies the order in which the
        parameters should be used)
  end
end
