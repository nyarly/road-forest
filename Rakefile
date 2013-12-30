# vim: set ft=ruby :
require 'corundum/tasklibs'

module Corundum
  Corundum::register_project(__FILE__)

  core = Core.new do |core|
    core.file_patterns.code << %r{^examples/}
  end

  core.in_namespace do
    GemspecFiles.new(core) do |files|
      files.extra_files = Rake::FileList["lib/roadforest/templates/**"]
    end

    %w{debug profanity racism ableism}.each do |type| #"issues" also available
      QuestionableContent.new(core) do |qc|
        qc.type = type
      end
    end
    rspec = RSpec.new(core)
    cov = SimpleCov.new(core, rspec) do |cov|
      cov.threshold = 88
    end

    gem = GemBuilding.new(core)
    cutter = GemCutter.new(core,gem)
    email = Email.new(core)
    vc = Git.new(core) do |vc|
      vc.branch = "master"
    end

    yd = YARDoc.new(core)

    docs = DocumentationAssembly.new(core, yd, rspec, cov)

    pages = GithubPages.new(docs)
  end
end

task :default => [:release, :publish_docs]
