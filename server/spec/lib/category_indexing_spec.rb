require 'spec_helper'

describe Category do
  
  before(:each) do
    @index  = Index::Memory.new :some_index, source: []
    @source = stub :some_given_source, :key_format => nil
  end
  let(:category) { described_class.new(:some_category, @index, :source => @source).tap { |c| c.stub! :timed_exclaim } }
  
  context "unit specs" do
    let(:exact) { category.indexing_exact }
    let(:partial) { category.indexing_partial }
    
    describe 'backup' do
      it 'delegates to both bundles' do
        exact.should_receive(:backup).once.with()
        partial.should_receive(:backup).once.with()
        
        category.backup
      end
    end
    describe 'restore' do
      it 'delegates to both bundles' do
        exact.should_receive(:restore).once.with()
        partial.should_receive(:restore).once.with()
        
        category.restore
      end
    end
    describe 'check' do
      it 'delegates to both bundles' do
        exact.should_receive(:raise_unless_cache_exists).once.with()
        partial.should_receive(:raise_unless_cache_exists).once.with()
        
        category.check
      end
    end
    describe 'clear' do
      it 'delegates to both bundles' do
        exact.should_receive(:delete).once.with()
        partial.should_receive(:delete).once.with()
        
        category.clear
      end
    end
    
    describe 'dump_caches' do
      before(:each) do
        exact.stub! :dump
        partial.stub! :dump
      end
      it 'should dump the exact index' do
        exact.should_receive(:dump).once.with

        category.dump_caches
      end
      it 'should dump the partial index' do
        partial.should_receive(:dump).once.with

        category.dump_caches
      end
    end
    
    describe 'generate_caches_from_memory' do
      it 'should delegate to partial' do
        partial.should_receive(:generate_caches_from_memory).once.with
        
        category.generate_caches_from_memory
      end
    end
    
    describe 'generate_partial' do
      it 'should return whatever the partial generation returns' do
        exact.stub! :index
        partial.stub! :generate_partial_from => :generation_returns

        category.generate_partial
      end
      it 'should use the exact index to generate the partial index' do
        exact_index = stub :exact_index
        exact.stub! :inverted => exact_index
        partial.should_receive(:generate_partial_from).once.with(exact_index)

        category.generate_partial
      end
    end

    describe 'generate_caches_from_source' do
      it 'should delegate to exact' do
        exact.should_receive(:generate_caches_from_source).once.with

        category.generate_caches_from_source
      end
    end

    describe 'cache' do
      it 'should call multiple methods in order' do
        category.should_receive(:generate_caches_from_source).once.with().ordered
        category.should_receive(:generate_partial).once.with().ordered
        category.should_receive(:generate_caches_from_memory).once.with().ordered
        category.should_receive(:dump_caches).once.with().ordered
        category.should_receive(:timed_exclaim).once.ordered
        
        category.cache
      end
    end
    
    describe 'key_format' do
      context 'source has key_format' do
        before(:each) do
          category.stub! :source => stub(:source, :key_format => :some_key_format)
        end
        it 'returns that key_format' do
          category.key_format.should == :some_key_format
        end
      end
      context 'source does not have key_format' do
        before(:each) do
          category.stub! :source => stub(:source)
        end
        context 'category has its own key_format' do
          before(:each) do
            category.instance_variable_set :@key_format, :other_key_format
          end
          it 'returns that key_format' do
            category.key_format.should == :other_key_format
          end
        end
        context 'category does not have its own key format' do
          before(:each) do
            category.instance_variable_set :@key_format, nil
          end
          context 'it has an index' do
            before(:each) do
              category.instance_variable_set :@index, stub(:index, :key_format => :yet_another_key_format)
            end
            it 'returns that key_format' do
              category.key_format.should == :yet_another_key_format
            end
          end
        end
      end
    end
    
    describe 'source' do
      context 'with explicit source' do
        let(:category) { described_class.new(:some_category, @index, :source => :category_source) }
        it 'returns the right source' do
          category.source.should == :category_source
        end
      end
      context 'without explicit source' do
        let(:category) { described_class.new(:some_category, @index.tap{ |index| index.stub! :source => :index_source }) }
        it 'returns the right source' do
          category.source.should == :index_source
        end
      end
    end
    
    describe "index" do
      before(:each) do
        @indexer = stub :indexer, :index => nil
        category.stub! :indexer => @indexer
      end
      it "tells the indexer to index" do
        @indexer.should_receive(:index).once.with [category]
        
        category.prepare
      end
    end
    describe "source" do
      context "without source" do
        it "has no problem with that" do
          lambda { described_class.new :some_name, @index }.should_not raise_error
        end
      end
    end
  end
  
end