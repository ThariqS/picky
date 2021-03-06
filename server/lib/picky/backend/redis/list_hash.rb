module Backend

  class Redis

    class ListHash < Basic

      # Writes the hash into Redis.
      #
      def dump hash
        clear
        hash.each_pair do |key, values|
          redis_key = "#{namespace}:#{key}"
          i = 0
          values.each do |value|
            i += 1
            backend.zadd redis_key, i, value
          end
        end
      end

      # Clear the index for this list.
      #
      # Note: Perhaps we can use a server only command.
      #       This is not the optimal way to do it.
      #
      def clear
        redis_key = "#{namespace}:*"
        backend.keys(redis_key).each do |key|
          backend.del key
        end
      end

      # Get a collection.
      #
      def collection key
        backend.zrange "#{namespace}:#{key}", 0, -1
      end

      # Get a single value.
      #
      def member key
        raise "Can't retrieve single value :#{key} from a Redis ListHash. Use Index::Redis::StringHash."
      end

    end

  end

end