require 'spec_helper'

RSpec.describe JsonapiCompliable::Resource do
  let(:klass) { Class.new(described_class) }
  let(:instance) { klass.new }

  describe '#stat' do
    let(:avg_proc) { proc { |scope, attr| 1 } }

    before do
      klass.class_eval do
        allow_stat :myattr do
          average { |scope, attr| 1 }
        end
      end
    end

    context 'when passing strings' do
      it 'returns the corresponding proc' do
        expect(instance.stat('myattr', 'average').call(nil, nil)).to eq(1)
      end
    end

    context 'when passing symbols' do
      it 'returns the corresponding proc' do
        expect(instance.stat(:myattr, :average).call(nil, nil)).to eq(1)
      end
    end

    context 'when no corresponding attribute' do
      it 'raises error' do
        expect { instance.stat(:foo, 'average') }
          .to raise_error(JsonapiCompliable::Errors::StatNotFound, "No stat configured for calculation 'average' on attribute :foo")
      end
    end

    context 'when no corresponding calculation' do
      it 'raises error' do
        expect { instance.stat('myattr', :median) }
          .to raise_error(JsonapiCompliable::Errors::StatNotFound, "No stat configured for calculation :median on attribute :myattr")
      end
    end
  end

  describe '#with_context' do
    it 'sets/resets correct context' do
      dbl = double
      instance.with_context(dbl, :index) do
        expect(instance.context).to eq(object: dbl, namespace: :index)
      end
      expect(instance.context).to eq({})
    end

    context 'when an error' do
      it 'resets the context' do
        expect {
          instance.with_context({}, :index) do
            raise 'foo'
          end
        }.to raise_error('foo')
        expect(instance.context).to eq({})
      end
    end
  end

  describe '#default_sort' do
    it 'gets/sets correctly' do
      klass.default_sort([{ name: :desc }])
      expect(instance.default_sort).to eq([{ name: :desc }])
    end

    it 'defaults' do
      expect(instance.default_sort).to eq([{ id: :asc }])
    end
  end

  describe '#default_page_number' do
    it 'gets/sets correctly' do
      klass.default_page_number(2)
      expect(instance.default_page_number).to eq(2)
    end

    it 'defaults' do
      expect(instance.default_page_number).to eq(1)
    end
  end

  describe '#default_page_size' do
    it 'gets/sets correctly' do
      klass.default_page_size(10)
      expect(instance.default_page_size).to eq(10)
    end

    it 'defaults' do
      expect(instance.default_page_size).to eq(20)
    end
  end

  describe '#type' do
    it 'gets/sets correctly' do
      klass.type :authors
      expect(instance.type).to eq(:authors)
    end

    it 'defaults' do
      expect(instance.type).to eq(:undefined_jsonapi_type)
    end
  end

  describe '#association_names' do
    it 'collects nested + resource sideloads' do
      klass.allow_sideload :books do
        genre_resource = Class.new(JsonapiCompliable::Resource) do
          allow_sideload :from_genre_resource do
            allow_sideload :nested_from_genre_resource
          end
        end
        allow_sideload :genre, resource: genre_resource
      end
      klass.allow_sideload :state, polymorphic: true
      expect(instance.association_names)
        .to match_array([:books, :genre, :state, :from_genre_resource, :nested_from_genre_resource])
    end

    context 'when no whitelist' do
      it 'defaults to empty array' do
        expect(instance.association_names).to eq([])
      end
    end
  end

  describe '#resolve' do
    it 'delegates to the adapter' do
      scope = double
      expect(instance.adapter).to receive(:resolve).with(scope)
      instance.resolve(scope)
    end
  end

  describe '#allowed_sideloads' do
    subject do
      instance.allowed_sideloads
    end

    context 'when no sideloads' do
      before do
        instance.instance_variable_set(:@sideloads, {})
      end

      it { is_expected.to eq({}) }
    end

    context 'when sideloads' do
      before do
        klass.allow_sideload :foo do
          allow_sideload :bar
        end
        klass.allow_sideload :baz
        klass.allow_sideload :blah
        klass.sideload_whitelist \
          index: [{ foo: :bar }],
          show: :blah
      end

      context 'and a namespace is passed as an argument' do
        around do |e|
          instance.with_context({}, :show) do
            e.run
          end
        end

        it 'uses that namespace' do
          expect(instance.allowed_sideloads(:index)).to eq({
            foo: { bar: {} }
          })
        end
      end

      context 'and a context namespace is set' do
        around do |e|
          instance.with_context({}, :show) do
            e.run
          end
        end

        it { is_expected.to eq({ blah: {} }) }
      end

      context 'and a namespace is not set' do
        it { is_expected.to eq({ foo: { bar: {} }, baz: {}, blah: {} }) }
      end
    end
  end
end
