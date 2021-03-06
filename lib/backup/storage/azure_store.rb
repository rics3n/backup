# encoding: utf-8
require 'azure'

module Backup
  module Storage
    class AzureStore < Base
      class Error < Backup::Error; end

      # Azure credentials
      attr_accessor :storage_account, :storage_access_key

      # Azure Storage Container
      attr_accessor :container_name, :container
      attr_accessor :blob_service, :chunk_size

      def initialize(model, storage_id = nil)
        super
        @path       ||= 'backups'
        @chunk_size ||= 1024 * 1024 * 4 # bytes
      end

      def init_blob_service
        Azure.config.storage_account_name = storage_account
        Azure.config.storage_access_key = storage_access_key

        Azure::Blob::BlobService.new
      end

      def transfer!
        blob_service = init_blob_service 
        container = blob_service.get_container_properties(container_name)

        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)

          backup_date = DateTime.parse(`date`).strftime("%Y-%m-%d-%H-%M-%S")
          path = @path unless path
          dest = "%s/%s-%s" % [path, backup_date, filename ]
          Logger.info "Creating Block Blob '#{ container.name }/#{ dest }'..."
          blob = blob_service.create_block_blob(container.name, dest, "")
          chunk_ids = []

          File.open(src,"r") do |fh_in|
            until fh_in.eof?
              chunk = "#{"%05d"%(fh_in.pos/chunk_size)}"
              Logger.info "Storing blob'#{ blob.name }/#{ chunk }'..."
              blob_service.create_blob_block(container.name, blob.name, chunk, fh_in.read(chunk_size))
              chunk_ids.push([chunk])
            end
          end
          blob_service.commit_blob_blocks(container.name, blob.name, chunk_ids)
        end
      end
    end
  end
end
