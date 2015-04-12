$:.unshift 'lib'

require 'syntax/penn_tree'
require 'syntax/parsed_sentence'
require 'syntax/dependencies'
require 'syntax/stanford/converter'

module Syntax
  describe PennTree do
    subject { pt }

    context 'sentence 1' do
      let(:pt) { Syntax::PennTree.new('(ROOT (S=H (NP (NNP=H SI)) (VP=H (VBD=H derived) (SBAR (S=H (NP (NNS=H units)) (VP=H (VBP=H are) (ADJP (JJ=H good)))))) (. .)))') }

      it '.find_head_noun_bfs' do
        expect(subject.find_head_noun_bfs.content).to eq('SI')
      end
      it '.find_head_noun_dfs' do
        expect(subject.find_head_noun_dfs.content).to eq('SI')
      end
      it '.find_plural_noun_dfs' do
        expect(subject.find_plural_noun_dfs.content).to eq('units')
      end
      it '.find_plural_noun_bfs' do
        expect(subject.find_plural_noun_bfs.content).to eq('units')
      end
      it '.find_last_plural_noun' do
        expect(subject.find_last_plural_noun.content).to eq('units')
      end
      it '.find_last_nominal' do
        expect(subject.find_last_nominal.content).to eq('units')
      end
    end

    context 'sentence 2' do
      let(:pt) { Syntax::PennTree.new('(ROOT (S=H (NP (NP=H (CD=H 1912)) (PP (IN=H in) (NP (NNS=H gymnastics)))) (VP=H (VBP=H are) (ADJP (JJ=H good))) (. .)))') }

      it '.find_head_noun_bfs' do
        expect(subject.find_head_noun_bfs.content).to eq('1912')
      end
      it '.find_head_noun_dfs' do
        expect(subject.find_head_noun_dfs.content).to eq('1912')
      end
      it '.find_plural_noun_dfs' do
        expect(subject.find_plural_noun_dfs.content).to eq('gymnastics')
      end
      it '.find_plural_noun_bfs' do
        expect(subject.find_plural_noun_bfs.content).to eq('gymnastics')
      end
      it '.find_last_plural_noun' do
        expect(subject.find_last_plural_noun.content).to eq('gymnastics')
      end
      it '.find_last_nominal' do
        expect(subject.find_last_nominal.content).to eq('gymnastics')
      end
    end

    context 'head 1' do
      let(:pt) { Syntax::PennTree.new('(NP=H (NNS=H Buildings) (CC and) (NNS structures))') }

      it '.heads' do
        expect(subject.heads.map{|node| node.find_head_noun.content}).to eq(['Buildings', 'structures'])
      end
    end

    context 'head 2' do
      let(:pt) { Syntax::PennTree.new('(NP=H (JJ Naval) (NNS=H units) (CC and) (NNS formations))') }

      it '.heads' do
        expect(subject.heads.map{|node| node.find_head_noun.content}).to eq(['units','formations'])
      end
    end

    context 'head 3' do
      let(:pt) { Syntax::PennTree.new('(NP=H (JJ Military) (CC and) (NN war) (NNS=H museums))') }

      it '.heads' do
        expect(subject.heads.map{|node| node.find_head_noun.content}).to eq(['museums'])
      end
    end


    context 'head 4' do
      let(:pt) { Syntax::PennTree.new('(NP=H (JJ Paralympic) (JJ wheelchair) (JJ rugby) (NNS=H players))') }

      it '.heads' do
        expect(subject.heads.map{|node| node.find_head_noun.content}).to eq(['players'])
      end
    end

    context 'head 5' do
      let(:pt) { Syntax::PennTree.new('(NP (JJ British) (NN exercise) (CC and) (NN fitness) (NNS=H writers))') }

      it '.heads' do
        expect(subject.heads.map{|node| node.find_head_noun.content}).to eq(['exercise','writers']) # should be fixed with knowledge about plurals
      end
    end

    context 'head 6 NX' do
      let(:pt) { Syntax::PennTree.new('(NP (JJ Ornithological) (NX=H (NX=H (NN=H equipment)) (CC and) (NX (NNS=H methods))))') }

      it '.heads' do
        expect(subject.heads.map{|node| node.find_head_noun.content}).to eq(['equipment','methods'])
      end
    end

  end
end