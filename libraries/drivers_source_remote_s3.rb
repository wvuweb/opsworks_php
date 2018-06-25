# frozen_string_literal: true

module Drivers
  module Source
    module Remote
      class S3 < Drivers::Source::Remote::Base
        adapter :s3
        allowed_engines :s3
        packages debian: %w[bzip2 git gzip p7zip tar unzip xz-utils],
                 rhel: %w[bzip2 git gzip tar unzip xz]
        output filter: %i[user password url]

        def initialize(context, app, options = {})
          super
        end

        def fetch_archive_from_remote # rubocop:disable Metrics/MethodLength
          s3_bucket, s3_key, base_url = parse_uri(out[:url])
          output = out

          context.s3_file File.join(archive_file_dir, @file_name) do
            bucket s3_bucket
            remote_path s3_key
            aws_access_key_id output[:user]
            aws_secret_access_key output[:password]
            owner node['deployer']['user'] || 'root'
            group www_group
            mode '0600'
            s3_url base_url
            action :create
          end
        end

        private

        # taken from https://github.com/aws/opsworks-cookbooks/blob/release-chef-11.10/scm_helper/libraries/s3.rb#L6
        def parse_uri(uri) # rubocop:disable Metrics/MethodLength
          #                base_uri                |         remote_path
          #----------------------------------------+------------------------------
          # scheme, userinfo, host, port, registry | path, opaque, query, fragment

          components = URI.split(uri)
          base_uri = URI::HTTP.new(*(components.take(5) + [nil] * 4))
          remote_path = URI::HTTP.new(*([nil] * 5 + components.drop(5)))

          virtual_host_match =
            base_uri.host.match(/\A(.+)\.s3(?:[-.](?:ap|eu|sa|us)-(?:.+-)\d|-external-1)?\.amazonaws\.com/i)

          if virtual_host_match
            # virtual-hosted-style: http://bucket.s3.amazonaws.com or http://bucket.s3-aws-region.amazonaws.com
            bucket = virtual_host_match[1]
          else
            # path-style: http://s3.amazonaws.com/bucket or http://s3-aws-region.amazonaws.com/bucket
            uri_path_components = remote_path.path.split('/').reject(&:empty?)
            bucket = uri_path_components.shift # cut first element
            base_uri.path = "/#{bucket}" # append bucket to base_uri
            remote_path.path = uri_path_components.join('/') # delete bucket from remote_path
          end

          # remote_path don't allow a "/" at the beginning
          # base_url don't allow a "/" at the end
          [bucket, remote_path.to_s.to_s.sub(%r{^/}, ''), base_uri.to_s.chomp('/')]
        end
      end
    end
  end
end
