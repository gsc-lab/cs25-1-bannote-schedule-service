# -*- encoding: utf-8 -*-
# stub: google-iam-v1 1.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "google-iam-v1".freeze
  s.version = "1.5.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Google LLC".freeze]
  s.date = "1980-01-02"
  s.description = "An add-on interface used by some Google API clients to provide IAM Policy calls. Note that google-iam-v1 is a version-specific client library. For most uses, we recommend installing the main client library google-iam instead. See the readme for more details.".freeze
  s.email = "googleapis-packages@google.com".freeze
  s.homepage = "https://github.com/googleapis/google-cloud-ruby".freeze
  s.licenses = ["Apache-2.0".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1".freeze)
  s.rubygems_version = "3.6.9".freeze
  s.summary = "Manages access control for Google Cloud Platform resources.".freeze

  s.installed_by_version = "3.6.9".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<gapic-common>.freeze, ["~> 1.2".freeze])
  s.add_runtime_dependency(%q<google-cloud-errors>.freeze, ["~> 1.0".freeze])
  s.add_runtime_dependency(%q<grpc-google-iam-v1>.freeze, ["~> 1.11".freeze])
end
