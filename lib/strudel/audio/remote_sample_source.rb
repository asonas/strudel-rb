# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "fileutils"

module Strudel
  module Audio
    class RemoteSampleSource
      CACHE_DIR = File.expand_path("~/.cache/strudel-rb/samples")

      attr_reader :source_url

      def initialize(source)
        @source_url = source
        @user, @repo, @branch = parse_github_parts(source)
        @base_url, @sample_map = resolve_and_fetch(source)
        download_all
        download_pitch_jsons
      end

      def has?(name)
        @sample_map.key?(name)
      end

      def get_path(name, n = 0)
        paths = @sample_map[name]
        return nil unless paths

        paths = [paths] unless paths.is_a?(Array)
        index = n % paths.length
        path = paths[index]
        return nil unless path
        return nil unless path.end_with?(".wav")

        cache_path(name, index)
      end

      def pitch_json_path(name)
        path = File.join(CACHE_DIR, @user, @repo, name, "pitch.json")
        File.exist?(path) ? path : nil
      end

      private

      def resolve_and_fetch(source)
        url = github_url
        json = fetch_json(url)
        base = json.delete("_base") || url.sub(/strudel\.json$/, "")
        [base, json]
      end

      def parse_github_parts(source)
        path = source.delete_prefix("github:")
        parts = path.split("/")
        user = parts[0]
        repo = parts[1] || "samples"
        branch = parts[2] || "main"
        [user, repo, branch]
      end

      def github_url
        "https://raw.githubusercontent.com/#{@user}/#{@repo}/#{@branch}/strudel.json"
      end

      def download_all
        wav_entries = []
        @sample_map.each do |name, paths|
          paths = [paths] unless paths.is_a?(Array)
          paths.each_with_index do |path, n|
            wav_entries << [name, n, path] if path.end_with?(".wav")
          end
        end

        wav_entries.each_with_index do |(name, n, path), i|
          local = cache_path(name, n)
          unless File.exist?(local)
            warn "Downloading #{name}/#{n}.wav (#{i + 1}/#{wav_entries.size})..."
            begin
              download(File.join(@base_url, path), local)
            rescue StandardError => e
              warn "Failed to download #{path}: #{e.message}"
            end
          end
        end
      end

      def download_pitch_jsons
        @sample_map.each_key do |name|
          local = File.join(CACHE_DIR, @user, @repo, name, "pitch.json")
          next if File.exist?(local)

          url = "#{@base_url}#{name}/pitch.json"
          next unless head_exists?(url)

          begin
            download(url, local)
          rescue StandardError => e
            warn "Failed to download pitch.json for #{name}: #{e.message}"
          end
        end
      end

      def fetch_json(url)
        body = http_get(url)
        JSON.parse(body)
      end

      def download(url, local_path)
        FileUtils.mkdir_p(File.dirname(local_path))
        body = http_get(url)
        File.binwrite(local_path, body)
      end

      def head_exists?(url)
        uri = URI.parse(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          response = http.head(uri.request_uri)
          response.is_a?(Net::HTTPSuccess)
        end
      rescue StandardError
        false
      end

      def http_get(url, limit = 3)
        raise "Too many redirects" if limit == 0

        uri = URI.parse(url)
        response = Net::HTTP.get_response(uri)
        case response
        when Net::HTTPSuccess
          response.body
        when Net::HTTPRedirection
          http_get(response["location"], limit - 1)
        else
          raise "HTTP #{response.code}: #{url}"
        end
      end

      def cache_path(name, n)
        File.join(CACHE_DIR, @user, @repo, name, "#{n}.wav")
      end
    end
  end
end
