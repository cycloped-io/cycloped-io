module Syntax
  class ParsedSentence
    attr_accessor :tree,:dependencies

    def initialize(tree, dependencies)
      @tree = tree
      @dependencies = dependencies

      combine_to_tree
    end

    # Adds dependency relations to nodes.
    def combine_to_tree
      @dependencies.dependencies.each do |dependency|
        matches = /(.*?)\((.*?)-([0-9]+)'*, (.*?)-([0-9]+)'*\)/.match(dependency) # cop(disorder-4, is-2) # ROOT! NSUBJ
        if matches.nil?
          p dependency
        end
        dependency_name,word1,number1,word2,number2 = matches[1],matches[2],matches[3],matches[4],matches[5]
        node1=dependency_to_node(number1.to_i)
        node2=dependency_to_node(number2.to_i)
        node1.add_dependency_to(dependency_name, node2)
        node2.add_dependency_from(dependency_name, node1)
      end
    end

    def dependencies(dependency_name)
      deps = []
      @dependencies.dependencies.each do |dependency|
        matches = /#{dependency_name}\((.*?)-([0-9]+), (.*?)-([0-9]+)\)/.match(dependency) # cop(disorder-4, is-2) # ROOT! NSUBJ
        if matches != nil
          deps.push [matches[1], matches[2], matches[3], matches[4]]
        end
      end
      return dependencies_to_nodes(deps)
    end
    
    def heads
      [@tree.find_head_noun_bfs, @tree.find_head_noun_dfs, @tree.find_plural_noun_bfs, @tree.find_plural_noun_dfs]
    end

    # Determines head based on found dependencies nsubj
    def dep_head
      deps = dependencies('nsubj')
      dep = nil
      deps.each do |n1,n2|
        next if n1.content != 'good'
        if n2.parent.content =~ /^N/
          if dep.nil? or n2.parent.head?
            dep = n2
          end
        end
      end
      return dep
    end
    
    private
    def dependencies_to_nodes(deps)
      deps_nodes = []
      deps.each do |w1,n1,w2,n2|
        deps_nodes.push [dependency_to_node(n1.to_i), dependency_to_node(n2.to_i)]
      end
      return deps_nodes
    end
    
    def dependency_to_node(number)
      i=1
      @tree.tree.each_leaf do |l|
        if i == number
          return l
        end
        i += 1      
      end
      return @tree.tree #ROOT-0
    end
  end
end