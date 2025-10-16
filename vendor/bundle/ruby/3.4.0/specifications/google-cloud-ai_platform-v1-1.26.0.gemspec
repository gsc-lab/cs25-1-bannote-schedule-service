# -*- encoding: utf-8 -*-
# stub: google-cloud-ai_platform-v1 1.26.0 ruby lib

Gem::Specification.new do |s|
  s.name = "google-cloud-ai_platform-v1".freeze
  s.version = "1.26.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Google LLC".freeze]
  s.date = "1980-01-02"
  s.description = "Vertex AI enables data scientists, developers, and AI newcomers to create custom machine learning models specific to their business needs by leveraging Google's state-of-the-art transfer learning and innovative AI research. Note that google-cloud-ai_platform-v1 is a version-specific client library. For most uses, we recommend installing the main client library google-cloud-ai_platform instead. See the readme for more details.".freeze
  s.email = "googleapis-packages@google.com".freeze
  s.homepage = "https://github.com/googleapis/google-cloud-ruby".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1".freeze)
  s.rubygems_version = "3.6.9".freeze
  s.summary = "Train high-quality custom machine learning models with minimal machine learning expertise and effort.".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<gapic-common>.freeze, ["~> 1.2".freeze])
  s.add_runtime_dependency(%q<google-cloud-errors>.freeze, ["~> 1.0".freeze])
  s.add_runtime_dependency(%q<google-cloud-location>.freeze, ["~> 1.0".freeze])
  s.add_runtime_dependency(%q<google-iam-v1>.freeze, ["~> 1.3".freeze])
end
