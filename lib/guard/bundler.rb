# encoding: utf-8
require 'bundler'

require "guard/compat/plugin"

require "optparse"

module Guard
  class Bundler < Plugin
    autoload :Notifier, 'guard/bundler/notifier'

    def start
      refresh_bundle
    end

    def reload
      refresh_bundle
    end

    def run_all
      refresh_bundle
    end

    def run_on_additions(paths = [])
      refresh_bundle
    end

    def run_on_modifications(paths = [])
      refresh_bundle
    end

    def cli?
      !!options[:cli]
    end

    def gemfile
      custom_gemfile || "Gemfile"
    end

    private

    def refresh_bundle
      start_at = Time.now
      result = bundle_check || bundle_install
      duration = Time.now - start_at
      case result
      when :bundle_already_up_to_date
        Guard::Compat::UI.info 'Bundle already up-to-date', reset: true
      when :bundle_installed_using_local_gems
        Guard::Compat::UI.info 'Bundle installed using local gems', reset: true
        Notifier.notify 'bundle_check_install', nil
      when :bundle_installed
        Guard::Compat::UI.info 'Bundle installed', reset: true
        Notifier.notify true, duration
      else
        Guard::Compat::UI.info "Bundle can't be installed -- Please check manually", reset: true
        Notifier.notify false, nil
      end
      result
    end

    def bundle_check
      gemfile_lock_mtime = File.exists?(lockfile) ? File.mtime(lockfile) : nil
      ::Bundler.with_clean_env do
        ENV["BUNDLE_GEMFILE"] = custom_gemfile if custom_gemfile
        `bundle check`
      end
      return false unless $? == 0
      if gemfile_lock_mtime && gemfile_lock_mtime == File.mtime(lockfile)
        :bundle_already_up_to_date
      else
        :bundle_installed_using_local_gems
      end
    end

    def bundle_install
      Guard::Compat::UI.info 'Bundling...', reset: true
      ::Bundler.with_clean_env do
        system("bundle install#{" #{options[:cli]}" if options[:cli]}")
      end
      $? == 0 ? :bundle_installed : false
    end

    def custom_gemfile
      cli_args[:custom_gemfile]
    end

    def cli_args
      cli_args = {}

      parser = OptionParser.new do |parser|
        parser.on("--gemfile=GEMFILE") do |file_name|
          cli_args[:custom_gemfile] = file_name
        end
      end

      parser.parse(options[:cli])
      cli_args
    end

    def lockfile
      "#{gemfile}.lock"
    end
  end
end
