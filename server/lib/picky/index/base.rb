# = Picky Indexes
#
# A Picky Index defines
# * where its data comes from (a data source).
# * how this data it is indexed.
# * a number of categories that may or may not map directly to data categories.
#
# == Howto
#
# This is a step-by-step description on how to create an index.
#
# Start by choosing an <tt>Index::Memory</tt> or an <tt>Index::Redis</tt>.
# In the example, we will be using an in-memory index, <tt>Index::Memory</tt>.
#
#   books = Index::Memory.new(:books)
#
# That in itself won't do much good, that's why we add a data source:
#
#   books = Index::Memory.new(:books) do
#     source Sources::CSV.new(:title, :author, file: 'data/books.csv')
#   end
#
# In the example, we use an explicit <tt>Sources::CSV</tt> of Picky.
# However, anything that responds to <tt>#each</tt>, and returns an object that
# answers to <tt>#id</tt>, works.
#
# For example, a 3.0 ActiveRecord class:
#
#   books = Index::Memory.new(:books) do
#     source Book.order('isbn ASC')
#   end
#
# Now we know where the data comes from, but not, how to categorize it.
#
# Let's add a few categories:
#
#   books = Index::Memory.new(:books) do
#     source   Book.order('isbn ASC')
#     category :title
#     category :author
#     category :isbn
#   end
#
# Categories offer quite a few options, see <tt>Index::Base#category</tt> for details.
#
# After adding more options, it might look like this:
#
#   books = Index::Memory.new(:books) do
#     source   Book.order('isbn ASC')
#     category :title,
#              partial: Partial::Substring.new(from: 1),
#              similarity: Similarity::DoubleMetaphone.new(3),
#              qualifiers: [:t, :title, :titulo]
#     category :author,
#              similarity: Similarity::Metaphone.new(2)
#     category :isbn,
#              partial: Partial::None.new,
#              from: :legacy_isbn_name
#   end
#
# For this to work, a <tt>Book</tt> should support methods <tt>#title</tt>, <tt>#author</tt> and <tt>#legacy_isbn_name</tt>.
#
# If it uses <tt>String</tt> ids, use <tt>#key_format</tt> to define a formatting method:
#
#   books = Index::Memory.new(:books) do
#     key_format :to_s
#     source     Book.order('isbn ASC')
#     category   :title
#     category   :author
#     category   :isbn
#   end
#
# Finally, use the index for a <tt>Search</tt>:
#
#   route %r{^/media$} => Search.new(books, dvds, mp3s)
#
module Index

  # This class defines the indexing and index API that is exposed to the user
  # as the #index method inside the Application class.
  #
  # It provides a single front for both indexing and index options. We suggest to always use the index API.
  #
  # Note: An Index holds both an *Indexed*::*Index* and an *Indexing*::*Index*.
  #
  class Base

    attr_reader :name,
                :categories

    delegate :[],
             :each_category,
             :to => :categories

    # Create a new index with a given source.
    #
    # === Parameters
    # * name: A name that will be used for the index directory and in the Picky front end.
    #
    # === Options
    # * source: Where the data comes from, e.g. Sources::CSV.new(...). Optional, can be defined in the block using #source.
    # * result_identifier: Use if you'd like a different identifier/name in the results than the name of the index.
    # * after_indexing: As of this writing only used in the db source. Executes the given after_indexing as SQL after the indexing process.
    # * tokenizer: The tokenizer to use for this index. Optional, can be defined in the block using #indexing.
    # * key_format: The format the ids of this index are in. Optional, can be defined in the block using #key_format.
    #
    # Examples:
    #   my_index = Index::Memory.new(:my_index, source: some_source) do
    #     category :bla
    #   end
    #
    #   my_index = Index::Memory.new(:my_index) do
    #     source   Sources::CSV.new(file: 'data/index.csv')
    #     category :bla
    #   end
    #
    #
    def initialize name, options = {}
      check_name name
      @name = name.to_sym

      check_options options

      @source = options[:source]

      @after_indexing        = options[:after_indexing]
      @indexing_bundle_class = options[:indexing_bundle_class] # TODO This should probably be a fixed parameter.
      @tokenizer             = options[:tokenizer]
      @key_format            = options[:key_format]

      # Indexed.
      #
      @result_identifier    = options[:result_identifier] || name
      @indexed_bundle_class = options[:indexed_bundle_class] # TODO This should probably be a fixed parameter.

      # TODO Move ignore_unassigned_tokens to query, somehow.
      #
      @categories = Categories.new ignore_unassigned_tokens: (options[:ignore_unassigned_tokens] || false)

      # Centralized registry.
      #
      Indexes.register self

      #
      #
      instance_eval(&Proc.new) if block_given?

      # Check if any source has been given in the block or the options.
      #
      check_source @source
    end

    # Default bundles.
    #
    def indexing_bundle_class
      Indexing::Bundle::Memory
    end
    def indexed_bundle_class
      Indexed::Bundle::Memory
    end

    # Defines a searchable category on the index.
    #
    # === Parameters
    # * category_name: This identifier is used in the front end, but also to categorize query text. For example, “title:hobbit” will narrow the hobbit query on categories with the identifier :title.
    #
    # === Options
    # * partial: Partial::None.new or Partial::Substring.new(from: starting_char, to: ending_char). Default is Partial::Substring.new(from: -3, to: -1).
    # * similarity: Similarity::None.new or Similarity::DoubleMetaphone.new(similar_words_searched). Default is Similarity::None.new.
    # * qualifiers: An array of qualifiers with which you can define which category you’d like to search, for example “title:hobbit” will search for hobbit in just title categories. Example: qualifiers: [:t, :titre, :title] (use it for example with multiple languages). Default is the name of the category.
    # * qualifier: Convenience options if you just need a single qualifier, see above. Example: qualifiers => :title. Default is the name of the category.
    # * source: Use a different source than the index uses. If you think you need that, there might be a better solution to your problem. Please post to the mailing list first with your application.rb :)
    # * from: Take the data from the data category with this name. Example: You have a source Sources::CSV.new(:title, file:'some_file.csv') but you want the category to be called differently. The you use from: define_category(:similar_title, :from => :title).
    #
    def category category_name, options = {}
      options = default_category_options.merge options

      new_category = Category.new category_name.to_sym, self, options
      categories << new_category

      new_category = yield new_category if block_given?

      new_category
    end
    alias define_category category

    # By default, the category uses
    # * the index's bundle type.
    #
    def default_category_options
      {
        :indexed_bundle_class => @indexed_bundle_class
      }
    end

    # Make this category range searchable with a fixed range. If you need other
    # ranges, define another category with a different range value.
    #
    # Example:
    # You have data values inside 1..100, and you want to have Picky return
    # not only the results for 47 if you search for 47, but also results for
    # 45, 46, or 47.2, 48.9, in a range of 2 around 47, so (45..49).
    #
    # Then you use:
    #  ranged_category :values_inside_1_100, 2
    #
    # Optionally, you give it a precision value to reduce the error margin
    # around 47 (Picky is a bit liberal).
    #   Index::Memory.new :range do
    #     ranged_category :values_inside_1_100, 2, precision: 5
    #   end
    #
    # This will force Picky to maximally be wrong 5% of the given range value
    # (5% of 2 = 0.1) instead of the default 20% (20% of 2 = 0.4).
    #
    # We suggest not to use much more than 5 as a higher precision is more
    # performance intensive for less and less precision gain.
    #
    # == Protip 1
    #
    # Create two ranged categories to make an area search:
    #   Index::Memory.new :area do
    #     ranged_category :x, 1
    #     ranged_category :y, 1
    #   end
    #
    # Search for it using for example:
    #   x:133, y:120
    #
    # This will search this square area (* = 133, 120: The "search" point entered):
    #
    #    132       134
    #     |         |
    #   --|---------|-- 121
    #     |         |
    #     |    *    |
    #     |         |
    #   --|---------|-- 119
    #     |         |
    #
    # Note: The area does not need to be square, but can be rectangular.
    #
    # == Protip 2
    #
    # Create three ranged categories to make a volume search.
    #
    # Or go crazy and use 4 ranged categories for a space/time search! ;)
    #
    # === Parameters
    # * category_name: The category_name as used in #define_category.
    # * range: The range (in the units of your data values) around the query point where we search for results.
    #
    #  -----|<- range  ->*------------|-----
    #
    # === Options
    # * precision: Default is 1 (20% error margin, very fast), up to 5 (5% error margin, slower) makes sense.
    # * ... all options of #define_category.
    #
    def ranged_category category_name, range, options = {}
      precision = options[:precision] || 1

      options = { partial: Partial::None.new }.merge options

      define_category category_name, options do |category|
        Indexing::Wrappers::Category::Location.install_on category, range, precision
        Indexed::Wrappers::Category::Location.install_on category, range, precision
      end
    end
    alias define_ranged_category ranged_category

    # HIGHLY EXPERIMENTAL Not correctly working yet. Try it if you feel "beta".
    #
    # Also a range search see #ranged_category, but on the earth's surface.
    #
    # Parameters:
    # * lat_name: The latitude's name as used in #define_category.
    # * lng_name: The longitude's name as used in #define_category.
    # * radius: The distance (in km) around the query point which we search for results.
    #
    # Note: Picky uses a square, not a circle. That should be ok for most usages.
    #
    #  -----------------------------
    #  |                           |
    #  |                           |
    #  |                           |
    #  |                           |
    #  |                           |
    #  |             *<-  radius ->|
    #  |                           |
    #  |                           |
    #  |                           |
    #  |                           |
    #  |                           |
    #  -----------------------------
    #
    # Options
    # * precision: Default 1 (20% error margin, very fast), up to 5 (5% error margin, slower) makes sense.
    # * lat_from: The data category to take the data for the latitude from.
    # * lng_from: The data category to take the data for the longitude from.
    #
    # TODO Will have to write a wrapper that combines two categories that are
    #      indexed simultaneously, since lat/lng are correlated.
    #
    def geo_categories lat_name, lng_name, radius, options = {} # :nodoc:

      # Extract lat/lng specific options.
      #
      lat_from = options.delete :lat_from
      lng_from = options.delete :lng_from

      # One can be a normal ranged_category.
      #
      ranged_category lat_name, radius*0.00898312, options.merge(from: lat_from)

      # The other needs to adapt the radius depending on the one.
      #
      # Depending on the latitude, the radius of the longitude
      # needs to enlarge, the closer we get to the pole.
      #
      # In our simplified case, the radius is given as if all the
      # locations were on the 45 degree line.
      #
      # This calculates km -> longitude (degrees).
      #
      # A degree on the 45 degree line is equal to ~222.6398 km.
      # So a km on the 45 degree line is equal to 0.01796624 degrees.
      #
      ranged_category lng_name, radius*0.01796624, options.merge(from: lng_from)

    end
    alias define_geo_categories geo_categories

    #
    # Since this is an API, we fail hard quickly.
    #
    def check_name name # :nodoc:
      raise ArgumentError.new(<<-NAME


The index identifier (you gave "#{name}") for Index::Memory/Index::Redis should be a Symbol/String,
Examples:
  Index::Memory.new(:my_cool_index) # Recommended
  Index::Redis.new("a-redis-index")
NAME


) unless name.respond_to?(:to_sym)
    end
    def check_options options # :nodoc:
      raise ArgumentError.new(<<-OPTIONS


Sources are not passed in as second parameter for #{self.class.name} anymore, but either
* as :source option:
  #{self.class.name}.new(#{name.inspect}, source: #{options})
or
* given to the #source method inside the config block:
  #{self.class.name}.new(#{name.inspect}) do
    source #{options}
  end

Sorry about that breaking change (in 2.2.0), didn't want to go to 3.0.0 yet!

All the best
  -- Picky


OPTIONS
) unless options.respond_to?(:[])
    end
    def check_source source # :nodoc:
      raise ArgumentError.new(<<-SOURCE


The index "#{name}" should use a data source that responds to either the method #each, or the method #harvest, which yields(id, text).
Or it could use one of the built-in sources:
  Sources::#{(Sources.constants - [:Base, :Wrappers, :NoCSVFileGiven, :NoCouchDBGiven]).join(',
  Sources::')}


SOURCE
) unless source.respond_to?(:each) || source.respond_to?(:harvest)
    end

    def to_stats # :nodoc:
      stats = <<-INDEX
#{name} (#{self.class}):
#{"source:            #{source}".indented_to_s}
#{"categories:        #{categories.map(&:name).join(', ')}".indented_to_s}
INDEX
      stats << "  result identifier: \"#{result_identifier}\"".indented_to_s unless result_identifier.to_s == name.to_s
      stats
    end

    # Identifier used for technical output.
    #
    def identifier
      "#{PICKY_ENVIRONMENT}:#{name}"
    end

    #
    #
    def to_s
      "#{self.class}(#{name}, result_id: #{result_identifier}, source: #{source}, categories: #{categories})"
    end

  end

end