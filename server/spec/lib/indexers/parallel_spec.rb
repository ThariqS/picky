require 'spec_helper'

describe Indexers::Parallel do

  before(:each) do
    @source     = stub :source
    @index      = stub :index, :name => :some_index, :source => @source
    
    @categories = stub :categories
    
    @indexer = described_class.new @index
    @indexer.stub! :timed_exclaim
  end
  
  describe 'flush' do
    it 'flushes to joined cache to the file and clears it' do
      cache = stub :cache
      file  = stub :file
      
      cache.should_receive(:join).twice.and_return :joined
      file.should_receive(:write).twice.with(:joined).and_return :joined
      cache.should_receive(:clear).twice
      
      @indexer.flush [[nil, cache, file], [nil, cache, file]]
    end
  end
  
end