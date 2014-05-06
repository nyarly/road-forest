# This file generated automatically using vocab-fetch from path.ttl
require 'rdf'
module RDF
  class RoadForest::Graph::Path < StrictVocabulary("http://judsonlester.info/rdf-vocab/path#")

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
    property :is, :comment =>
      %(The target of this step has exactly this value.)
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
