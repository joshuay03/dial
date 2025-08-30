# frozen_string_literal: true

require "zlib"
require "fileutils"

module Dial
  class Storage
    class FileAdapter
      def initialize options = {}
        @ttl = options[:ttl] || STORAGE_TTL
        @profile_dir = ::Rails.root.join VERNIER_PROFILE_OUT_RELATIVE_DIRNAME
        FileUtils.mkdir_p @profile_dir
      rescue Errno::ENOENT
        FileUtils.mkdir_p File.dirname @profile_dir
        FileUtils.mkdir_p @profile_dir
      end

      def store key, data, ttl: nil
        ttl ||= @ttl
        store_profile key, data, ttl
      end

      def fetch key
        fetch_profile key
      end

      def delete key
        delete_profile key
      end

      def cleanup
        stale_files("#{@profile_dir}/*#{VERNIER_PROFILE_OUT_FILE_EXTENSION}").each { |file| File.delete file rescue nil }
        expired_files("#{@profile_dir}/*").each { |file| File.delete file rescue nil }
      end

      private

      def store_profile key, data, ttl = nil
        uuid = extract_uuid key
        path = profile_path uuid
        File.binwrite path, data
        set_file_expiry path, ttl if ttl
      end

      def fetch_profile key
        uuid = extract_uuid key
        path = profile_path uuid
        File.binread path if File.exist? path
      end

      def delete_profile key
        uuid = extract_uuid key
        path = profile_path uuid
        File.delete path if File.exist? path
      end

      def extract_uuid key
        key.split(":", 2).first
      end

      def profile_path uuid
        @profile_dir.join "#{uuid}#{VERNIER_PROFILE_OUT_FILE_EXTENSION}"
      end

      def stale_files glob_pattern
        Dir.glob(glob_pattern).select do |file|
          uuid = File.basename file, ".*"
          timestamp = Util.uuid_timestamp uuid.gsub(/_vernier$/, "")
          timestamp < Time.now - STORAGE_TTL
        rescue StandardError
          true
        end
      end

      def expired_files glob_pattern
        Dir.glob(glob_pattern).select { |file| file_expired? file }
      end

      def set_file_expiry path, ttl
        expire_time = Time.now + ttl
        File.utime expire_time, expire_time, path
      end

      def file_expired? path
        return false unless File.exist? path
        File.mtime(path) < Time.now
      end
    end
  end
end
