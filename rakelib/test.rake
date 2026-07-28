# frozen_string_literal: true

require "rake/testtask"

config = lambda do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

Rake::TestTask.new(:test, &config)

namespace :test do
  class GdbTestTask < Rake::TestTask
    def ruby(*args, **options, &block)
      command = "gdb --args #{RUBY} #{args.join(" ")}"
      sh(command, **options, &block)
    end
  end

  GdbTestTask.new(gdb: :compile, &config)

  class LldbTestTask < Rake::TestTask
    def ruby(*args, **options, &block)
      command = "lldb #{RUBY} -- #{args.join(" ")}"
      sh(command, **options, &block)
    end
  end

  LldbTestTask.new(lldb: :compile, &config)

  desc "Run the tests for the rust bindings"
  task :rust do
    ["rust/ruby-prism", "rust/ruby-prism-sys"].each do |dir|
      Dir.chdir(dir) do
        sh("cargo test")
      end
    end
  end
end

# If we're on JRuby or TruffleRuby, we don't want to bother to configure valgrind
return if RUBY_ENGINE == "jruby" || RUBY_ENGINE == "truffleruby"

# Needs good support for RUBY_FREE_AT_EXIT
return if RUBY_VERSION < "3.4"

require "rake"
config = lambda do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

namespace :test do
  task :valgrind_internal do
    # Recompile with PRISM_BUILD_DEBUG=1
    ENV["PRISM_BUILD_DEBUG"] = "1"
    # Rake::Task["clobber"].invoke
    # Rake::Task["compile"].invoke
  end

  class ValgrindTestTask < Rake::TestTask
    XML_PATH = File.expand_path("#{__dir__}/../tmp/valgrind-%p.xml")
    SUPPRESSIONS_PATH = File.expand_path("#{__dir__}/../supressions/ruby-dev.supp")

    def ruby(*args, **options, &block)
      command = [
        "valgrind",
        "--num-callers=50",
        "--error-limit=no",
        "--trace-children=yes",
        "--undef-value-errors=no",
        "--leak-check=full",
        "--show-leak-kinds=definite",
        # "--suppressions", SUPPRESSIONS_PATH,
        RUBY,
        args.join(" "),
      ].join(" ")
      binding.irb
      sh({ **ENV, "RUBY_FREE_AT_EXIT" => "1" }, command, **options, &block)
    end
  end
  ValgrindTestTask.new(valgrind: :valgrind_internal, &config)
end
