# encoding: utf-8

module CassandraMigrations
  class Migration

    # Used to define a table in a migration of table creation or to
    # add columns to an existing table.
    #
    # An instance of this class is passed to the block of the method
    # +create_table+, available on every migration.
    #
    # This class is also internally used in the method +add_column+.

    class TableDefinition

      #
      # C* Data Types. See http://www.datastax.com/documentation/cql/3.0/cql/cql_reference/cql_data_types_c.html
      #

      # Migration  | CQL Type	| Ruby          | Description
      # Type       |           | Class         |
      # ------------------------------------------------------------------------
      # string     | varchar	 | String        | UTF-8 encoded string
      # text       | text	    | String	      | UTF-8 encoded string
      # ascii      | ascii     | String	      | US-ASCII character string
      # ------------------------------------------------------------------------
      # integer(4) | int	     | Integer	     | 32-bit signed integer
      # integer(8) | bigint	  | Fixnum        | 64-bit signed long
      # varint	   | varint    | Bignum        | Arbitrary-precision integer
      # ------------------------------------------------------------------------
      # decimal	  | decimal   | BigDecimal    | Variable-precision decimal
      # float(4)	 | float	   |               | 32-bit IEEE-754 floating point
      # double     | double	  |	             | Float 64-bit IEEE-754 floating point
      # float(8)   | double    |               |
      # ------------------------------------------------------------------------
      # boolean    | boolean	 | TrueClass     | true or false
      #            |           | FalseClass    |
      # ------------------------------------------------------------------------
      # uuid	     | uuid      | Cql::Uuid     | A UUID in standard UUID format
      # timeuuid	 | timeuuid  | Cql::TimeUuid | Type 1 UUID only (CQL 3)
      # ------------------------------------------------------------------------
      # inet	     | inet      | IPAddr        | IP address string in IPv4 or
      #            |           |               | IPv6 format*
      # ------------------------------------------------------------------------
      # timestamp  | timestamp | Time          | Date plus time, encoded as 8
      #            |           |               | bytes since epoch
      # datetime   | timestamp |               |
      # ------------------------------------------------------------------------
      # list       | list	    | Array	       | A collection of one or more
      #            |           |               | ordered elements
      # map        | map	     | Hash	        | A JSON-style array of literals:
      #            |           |               | { literal : literal, ... }
      # set        | set	     | Set	         | A collection of one or more
      #            |           |               | elements
      # binary     | blob	    | 	            | Arbitrary bytes (no validation),
      #            |           |               | expressed as hexadecimal
      # 	         | counter   |               | Distributed counter value
      #            |           |               | (64-bit long)



      def initialize()
        @columns_name_type_hash = {}
        @primary_keys = []
        @partition_keys = []
      end

      def to_create_cql
        cql = []

        if !@columns_name_type_hash.empty?
          @columns_name_type_hash.each do |column_name, type|
            cql << "#{column_name} #{type}"
          end
        else
          raise Errors::MigrationDefinitionError, 'No columns defined for table.'
        end

        key_info = (@primary_keys - @partition_keys)
        key_info = ["(#{@partition_keys.join(', ')})", *key_info] if @partition_keys.any?

        if key_info.any?
          cql << "PRIMARY KEY(#{key_info.join(', ')})"
        else
          raise Errors::MigrationDefinitionError, 'No primary key defined.'
        end

        cql.join(', ')
      end

      def to_add_column_cql
        cql = ""

        if @columns_name_type_hash.size == 1
          cql = "#{@columns_name_type_hash.keys.first} #{@columns_name_type_hash.values.first}"
        elsif @columns_name_type_hash.empty?
          raise Errors::MigrationDefinitionError, 'No column to add.'
        else
          raise Errors::MigrationDefinitionError, 'Only one column can be added at once.'
        end

        cql
      end

      def boolean(column_name, options={})
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:boolean, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def integer(column_name, options={})
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:integer, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def decimal(column_name, options={})
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:decimal, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def float(column_name, options={})
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:float, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def double(column_name, options={})
        options[:limit] = 8
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:float, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def string(column_name, options={})
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:string, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def text(column_name, options={})
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:text, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def ascii(column_name, options={})
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:ascii, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def datetime(column_name, options={})
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:datetime, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def timestamp(column_name, options={})
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:timestamp, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def uuid(column_name, options={})
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:uuid, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def timeuuid(column_name, options={})
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:timeuuid, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def binary(column_name, options={})
        @columns_name_type_hash[column_name.to_sym] = column_type_for(:binary, options)
        define_primary_keys(column_name) if options[:primary_key]
      end

      def list(column_name, options={})
        type = options[:type]
        if type.nil?
          raise Errors::MigrationDefinitionError, 'A list must define a collection type.'
        elsif !self.respond_to?(type)
          raise Errors::MigrationDefinitionError, "Type '#{type}' is not valid for cassandra migration."
        end
        if options[:primary_key]
          raise Errors::MigrationDefinitionError, 'A collection cannot be used as a primary key.'
        end
        @columns_name_type_hash[column_name.to_sym] = :"list<#{column_type_for(type)}>"
      end

      def set(column_name, options={})
        type = options[:type]
        if type.nil?
          raise Errors::MigrationDefinitionError, 'A set must define a collection type.'
        elsif !self.respond_to?(type)
          raise Errors::MigrationDefinitionError, "Type '#{type}' is not valid for cassandra migration."
        end
        if options[:primary_key]
          raise Errors::MigrationDefinitionError, 'A collection cannot be used as a primary key.'
        end
        @columns_name_type_hash[column_name.to_sym] = :"set<#{column_type_for(type)}>"
      end

      def map(column_name, options={})
        key_type, value_type = options[:key_type], options[:value_type]
        [key_type, value_type].each_with_index do |type, index|
          if type.nil?
            raise Errors::MigrationDefinitionError, "A map must define a #{index = 0 ? 'key' : 'value'} type."
          elsif !self.respond_to?(type)
            raise Errors::MigrationDefinitionError, "Type '#{type}' is not valid for cassandra migration."
          end
        end

        if options[:primary_key]
          raise Errors::MigrationDefinitionError, 'A collection cannot be used as a primary key.'
        end
        @columns_name_type_hash[column_name.to_sym] = :"map<#{column_type_for(key_type)},#{column_type_for(value_type)}>"
      end

      def define_primary_keys(*keys)
        if !@primary_keys.empty?
          raise Errors::MigrationDefinitionError, 'Primary key defined twice for the same table.'
        end

        @primary_keys = keys.flatten
      end

      def define_partition_keys(*keys)
        if !@partition_keys.empty?
          raise Errors::MigrationDefinitionError, 'Partition key defined twice for the same table.'
        end

        @partition_keys = keys.flatten
      end

      private

      PASSTHROUGH_TYPES = [:text, :ascii, :decimal, :double, :boolean,
                           :uuid, :timeuuid, :inet, :timestamp, :list,
                           :map, :set]
      TYPES_MAP = { string: :varchar,
                    datetime: :timestamp,
                    binary: :blob }

      PRECISION_MAP = {
                        integer: { 4 => :int, 8 => :bigint, nil => :int },
                        float: { 4 => :float, 8 => :double, nil => :float }
                      }

      def column_type_for(type, options={})
        cql_type = type if PASSTHROUGH_TYPES.include?(type)
        cql_type ||= TYPES_MAP[type]
        if PRECISION_MAP.keys.include?(type)
          limit = options[:limit]
          unless PRECISION_MAP[type].keys.include?(limit)
            raise Errors::MigrationDefinitionError, ":limit option should be #{PRECISION_MAP[type].keys.compact.join(' or ')} for #{type}."
          end
          cql_type ||= PRECISION_MAP[type][limit]
        end
        cql_type
      end

    end
  end
end
