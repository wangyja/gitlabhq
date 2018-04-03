module Gitlab
  module Ci
    class Trace
      module ChunkedFile
        class LiveTrace < ChunkedIO
          class << self
            def exist?(job_id)
              ChunkedFile::ChunkStore::Redis.chunks_count(job_id) > 0 || ChunkedFile::ChunkStore::Database.chunks_count(job_id) > 0
            end
          end

          after_callback :write_chunk, :stash_to_database

          def stash_to_database(store)
            # Once data is filled into redis, move the data to database
            if store.filled?
              ChunkedFile::ChunkStore::Database.open(job_id, chunk_index, params_for_store) do |to_store|
                to_store.write!(store.get)
                store.delete!
              end
            end
          end

          # This is more efficient than iterating each chunk store and deleting
          def truncate(offset)
            if offset == 0
              delete
              @size = @tell = 0
            elsif offset == size
              # no-op
            else
              raise NotImplementedError, 'Unexpected operation'
            end
          end

          def delete
            ChunkedFile::ChunkStore::Redis.delete_all(job_id)
            ChunkedFile::ChunkStore::Database.delete_all(job_id)
          end

          private

          def calculate_size(job_id)
            ChunkedFile::ChunkStore::Redis.chunks_size(job_id) +
              ChunkedFile::ChunkStore::Database.chunks_size(job_id)
          end

          def chunk_store
            if last_chunk?
              ChunkedFile::ChunkStore::Redis
            else
              ChunkedFile::ChunkStore::Database
            end
          end

          def buffer_size
            128.kilobytes
          end
        end
      end
    end
  end
end
