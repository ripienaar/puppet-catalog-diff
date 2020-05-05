require 'spec_helper'
require 'puppet/catalog-diff/comparer'

describe Puppet::CatalogDiff::Comparer do
  include described_class

  let(:res1) do
    [
      {
        resource_id: 'file.foo',
        type: 'file',
        parameters: {
          name: 'foo',
          alias: 'baz',
          path: '/foo',
          content: 'foo content',
          checksum: '6dbda444875c24ec1bbdb433456be11f',
        },
      },
    ]
  end

  let(:res2) do
    [
      {
        resource_id: 'file.foo',
        type: 'file',
        parameters: {
          name: 'foo',
          alias: 'baz',
          path: '/food',
          content: 'foo content 2',
          checksum: '4eb91aa4f5795ef3658d1e0a2798c816',
        },
      },
    ]
  end

  let(:resources1) do
    [
      {
        resource_id: 'foo',
      },
      {
        resource_id: 'bar',
      },
    ]
  end

  let(:resources2) do
    [
      {
        resource_id: 'foo',
      },
      {
        resource_id: 'baz',
      },
    ]
  end

  describe 'extract_titles' do
    it 'returns resource ids' do
      extract_titles(resources1).should eq(['foo', 'bar'])
    end
  end

  describe 'compare_resources' do
    it 'returns a diff without options' do
      diffs = compare_resources(res1, res2, {})
      expect(diffs[:old]).to eq(res1[0][:resource_id] => res1[0])
      expect(diffs[:new]).to eq(res2[0][:resource_id] => res2[0])
      expect(diffs[:old_params]).to eq('file.foo' => { content: 'foo content', path: '/foo', checksum: '6dbda444875c24ec1bbdb433456be11f' })
      expect(diffs[:new_params]).to eq('file.foo' => { content: 'foo content 2', path: '/food', checksum: '4eb91aa4f5795ef3658d1e0a2798c816' })
      expect(diffs[:content_differences]['file.foo']).to match(%r{^\+foo content 2$})
      expect(diffs[:string_diffs]).to be_empty
    end

    it 'returns string_diffs with show_resource_diff' do
      diffs = compare_resources(res1, res2, show_resource_diff: true)
      expect(diffs[:string_diffs]['file.foo'][3]).to eq("-\t     content => \"foo content\"")
    end

    it 'returns a diff without path parameter' do
      diffs = compare_resources(res1, res2, ignore_parameters: 'path')
      expect(diffs[:old_params]).to eq('file.foo' => { content: 'foo content', checksum: '6dbda444875c24ec1bbdb433456be11f' })
      expect(diffs[:new_params]).to eq('file.foo' => { content: 'foo content 2', checksum: '4eb91aa4f5795ef3658d1e0a2798c816' })
    end
  end

  describe 'return_resource_diffs' do
    it 'returns differences' do
      diffs = return_resource_diffs(extract_titles(resources1), extract_titles(resources2))
      expect(diffs[:titles_only_in_old]).to eq(['bar'])
      expect(diffs[:titles_only_in_new]).to eq(['baz'])
    end
  end

  describe 'do_str_diff' do
    it 'diffs two strings' do
      diff = do_str_diff('abc', 'abd')
      expect(diff).to match(/^-abc$/)
      expect(diff).to match(/^\+abd$/)
    end
  end

  describe 'str_diff' do
    context 'when passing strings' do
      it 'diffs two strings' do
        diff = str_diff('abc', 'abd')
        expect(diff).to match(/^-abc$/)
        expect(diff).to match(/^\+abd$/)
      end
    end

    context 'when passing hashes' do
      it 'diffs content params' do
        diff = str_diff(res1[0][:parameters], res2[0][:parameters])
        expect(diff).to match(/^-foo content$/)
        expect(diff).to match(/^\+foo content 2$/)
      end
    end
  end
end
