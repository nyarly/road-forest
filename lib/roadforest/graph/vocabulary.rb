require 'roadforest/graph'
require 'rdf'

module RoadForest::Graph
  module Vocabulary
    class RF < ::RDF::Vocabulary("http://lrdesign.com/graph/roadforest#")
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
    property :LiteralTemplate
    property :Metadata, :comment =>
      %(There is extra metadata available about this resource)
    property :Mutate, :comment =>
      %(Triggering this affordance expresses a desire to make changes
        to a resource)
    property :Navigate, :comment =>
      %(A link to another resource. The assumption is that otherwise
        undescribed URLs have a navigation affordance)
    property :Null, :comment =>
      %(The provided affordance is null. i.e. not dereferenceable, no
        actions provided)
    property :Remove, :comment =>
      %(Triggering this affordance is a request to delete the resource)
    property :ResourceTemplate
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
    property :defaultValue
    property :label
    property :name
    property :objectTemplate, :comment =>
      %(Used to indicate that a resource or literal template can be
        used as the property in a statement)
    property :pattern, :comment =>
      %(An IRITemplate \(RFC 5xxx\) that defines how the template is
        rendered - implicitly, all the parameters of the template are
        provided as a key, value set called param_list, so something
        like \(?param_list*\) should work like an HTML action=GET form)
    property :payload
    property :predicateTemplate, :comment =>
      %(Used to indicate that a resource template can be used as the
        property in a statement)
    property :range
    property :statement
    property :subjectTemplate, :comment =>
      %(Used to indicate that a resource template can be used as the
        subject in a statement)
    property :target, :comment =>
      %(Could be a templated URL, or a URL resource. If not a
        template, but the Affordance has one or more uriVariable
        properties, the implication is that the target resource should
        be used as the basis of a URI template by appending
        \(?name,other,...\) to the URI.)
    property :var, :comment =>
      %(When the object is list, the members of the list should be
        Parameters, the the list order implies the order in which the
        parameters should be used)
  end

# This file generated automatically using vocab-fetch from path.ttl
  class Path < ::RDF::StrictVocabulary("http://judsonlester.info/rdf-vocab/path#")

    # Class definitions
    property :Literal
    property :MultipleStep, :comment =>
      %(A step that may appear more than once on a subject)
    property :RepeatingStep, :comment =>
      %(A step that repeats - the subject of a matching step become
        the subject of a new match)
    property :Root, :comment =>
        %(The starting point of a path pattern)
    property :Step, :comment =>
        %(Base class for path steps)
    property :Target, :comment =>
        %(A target for the pattern)

    # Property definitions
    property :after, :comment =>
        %(Constrains the matching of this literal to values that come
        after the subject value in some order.)
    property :before, :comment =>
        %(Constrains the matching of this literal to values that come
        before the subject value in some order.)
    property :constraint, :comment =>
        %(Description of constraints on values that can match this
        Literal.)
    property :defaultValue
    property :forward, :comment =>
        %(Indicates that the subject of the matched statement matches
        the subject, and the predicate of the matched statement
        matches the predicate.)
    property :label
    property :maxMulti, :comment =>
        %(Limits the number of times a repeating step may repeat -
        otherwise a repeating step is assumed to have no limit to
        repetitions.)
    property :maxRepeat, :comment =>
        %(Limits the number of times a repeating step may repeat -
        otherwise a repeating step is assumed to have no limit to
        repetitions.)
    property :minMulti, :comment =>
        %(Limits the number of times a repeating step may repeat -
        otherwise a repeating step is assumed allow 0 repetions.)
    property :minRepeat, :comment =>
        %(Limits the number of times a repeating step may repeat -
        otherwise a repeating step is assumed allow 0 repetions.)
        property :name
    property :order, :comment =>
        %(The subject resource describes the order in which to consider
        values of this Literal.)
    property :predicate, :comment =>
        %(The property of a statement that matches this step)
    property :reverse, :comment =>
        %(Indicates that the subject of the matched statement matches
        the predicate, and the predicate of the matched statement
        matches the subject.)
    property :type
  end
end
