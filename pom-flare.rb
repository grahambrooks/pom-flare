require 'rexml/document'
require 'json'
require_relative './filters.rb'

class Node
  attr_accessor :id, :name, :children

  def initialize(name)
    self.name = name
    self.children = []
  end

  def add_child(child)
    children << child
  end

  def clean_name x
    name.gsub(/[\s\.\/-]/, '_')
  end
end

class PomFlare
  attr_accessor :roots, :all_nodes

  def initialize
    self.roots = {}
    self.all_nodes = {}
  end

  def interesting?(name)
    $dependency_filters.each { |pattern| return true if name =~ pattern }
    false
  end

  def expand(name, dictionary)
    if name =~/\$\{\S+}/
      id = group_id(dictionary)

      if id
        name.gsub!('${project.groupId}', id)
        name.gsub!('${parent.project.groupId}', id)
        name.gsub!('${project.parent.groupId}', id)
        name.gsub!('${parent.groupId}', id)
        name.gsub!('${groupId}', id)
      end

      id = artifact_id dictionary

      if id
        name.gsub!('${project.parent.artifactId}', id)
        name.gsub!('${parent.artifactId}', id)
        name.gsub!('${artifactId}', id)
      end
    end
    if name =~/\$\{\S+}/
      raise "Failed to expand name #{name}"
    end
    name
  end

  def artifact_id(dictionary)
    unless dictionary.elements['project/parent/artifactId'].nil?
      dictionary.elements['project/parent/artifactId'].text
    end

    unless dictionary.elements['project/artifactId'].nil?
      dictionary.elements['project/artifactId'].text
    end

    nil
  end

  def group_id(dom)
    unless dom.elements['project/groupId'].nil?
      return dom.elements['project/groupId'].text
    end

    unless dom.elements['project/parent/groupId'].nil?
      return dom.elements['project/parent/groupId'].text
    end
    nil
  end

  def node(name)
    unless self.all_nodes[name]
      self.all_nodes[name] = Node.new(name)
    end
    self.all_nodes[name]
  end

  def link(from, to)
    from.add_child(to)

    self.roots[from.name] = from
    self.roots.delete(to.name)
  end

  def add_dependency(from, to)
    from_node = node(from)
    to_node = node(to)

    link(from_node, to_node)
  end

  def gen(path)
    unprocessed_files = []
    Dir.glob(File.join(path, '**', 'pom.xml')) do |pom_filename|
      begin
        file = File.new pom_filename
        doc = REXML::Document.new file

        group_id = doc.elements['/project/parent/groupId']
        artifact_id = doc.elements['/project/artifactId']

        if group_id && artifact_id then
          component = "#{expand(group_id.text, doc)}.#{expand(artifact_id.text, doc)}"
          doc.elements.each('/project/dependencies/dependency') do |e|
            begin
              child_group_id = e.elements['groupId'].text
              child_atrifact_is = e.elements['artifactId'].text
              depend = "#{expand(child_group_id, doc)}.#{child_atrifact_is}"
              if interesting? depend
                add_dependency(component, depend)
              end
            rescue Exception => e
              STDERR.puts("Failed to expand name - dependency ignored #{e}")
            end
          end
        end
      rescue Exception => e
        puts "Rescue #{e}"
        unprocessed_files << pom_filename
      end
    end

    dependencies = []

    self.all_nodes.values.each do |node|
      imports = []
      node.children.each do |child|
        imports << child.name
      end
#      if imports.length > 0
        dependencies << {'name' => node.name, 'imports' => imports}
#      end
    end

    File.open('dependencies.json', 'w') do |f|
      f.print dependencies.to_json
    end

    File.open('unprocessed.json', 'w') do |f|
      f.print unprocessed_files.to_json
    end
  end
end

pom_flare = PomFlare.new
if ARGV[0]
  pom_flare.gen ARGV[0]
else
  puts 'Usage pom-flare path'
end