# frozen_string_literal: true

require_relative "../../test_helper"

module Dial
  class Storage
    class TestFileAdapter < Dial::Test
      def setup
        super
        @adapter = FileAdapter.new
        @uuid = Dial::Util.uuid + "_vernier"
        @profile_key = "#{@uuid}:profile"
        @profile_data = "test profile data"
      end

      def teardown
        super
        cleanup_test_files
      end

      def test_store_and_fetch_profile
        @adapter.store @profile_key, @profile_data

        result = @adapter.fetch @profile_key
        assert_equal @profile_data, result
      end


      def test_fetch_nonexistent_key
        result = @adapter.fetch "nonexistent_vernier:profile"
        assert_nil result

      end

      def test_delete_profile
        @adapter.store @profile_key, @profile_data
        assert @adapter.fetch @profile_key

        @adapter.delete @profile_key
        assert_nil @adapter.fetch @profile_key
      end

      def test_cleanup_removes_stale_files
        old_uuid = generate_old_uuid
        old_profile_key = "#{old_uuid}:profile"

        @adapter.store old_profile_key, "old data"

        # Set file modification time to the past to simulate expiry
        old_file_path = @adapter.send(:profile_path, old_uuid)
        old_time = Time.now - STORAGE_TTL - 1
        File.utime(old_time, old_time, old_file_path)

        assert @adapter.fetch old_profile_key

        @adapter.cleanup

        assert_nil @adapter.fetch old_profile_key
      end

      def test_cleanup_preserves_recent_files
        @adapter.store @profile_key, @profile_data

        @adapter.cleanup

        assert_equal @profile_data, @adapter.fetch(@profile_key)
      end

      private

      def cleanup_test_files
        profile_dir = Rails.root.join VERNIER_PROFILE_OUT_RELATIVE_DIRNAME
        Dir.glob("#{profile_dir}/*").each do |file|
          File.delete file rescue nil
        end
      end

      def generate_old_uuid
        old_time = Time.now - STORAGE_TTL - 1
        timestamp_ms = (old_time.to_f * 1000).to_i
        timestamp_hex = timestamp_ms.to_s(16).rjust(12, '0')
        "#{timestamp_hex.slice(0, 8)}-#{timestamp_hex.slice(8, 4)}-7000-8000-123456789abc_vernier"
      end
    end
  end
end
