require 'spec_helper'

describe Indexed::Bundle::Redis do

  before(:each) do
    @backend = stub :backend
    
    Backend::Redis.stub! :new => @backend
    
    @index        = Index::Memory.new :some_index, source: []
    @category     = Category.new :some_category, @index
    
    @similarity   = stub :similarity
    @bundle       = described_class.new :some_name, @category, @similarity
  end
  
  describe 'ids' do
    it 'delegates to the backend' do
      @backend.should_receive(:ids).once.with :some_sym
      
      @bundle.ids :some_sym
    end
  end
  
  describe 'weight' do
    it 'delegates to the backend' do
      @backend.should_receive(:weight).once.with :some_sym
      
      @bundle.weight :some_sym
    end
  end
  
  describe '[]' do
    it 'delegates to the backend' do
      @backend.should_receive(:setting).once.with :some_sym
      
      @bundle[:some_sym]
    end
  end
  
end