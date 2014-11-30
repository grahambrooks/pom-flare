require 'rexml/document'
require 'json'

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
      STDERR.puts "Failed to expand name #{name}"
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

    'Artifact ID not found'
  end

  def group_id(dom)
    unless dom.elements['project/groupId'].nil?
      return dom.elements['project/groupId'].text
    end

    unless dom.elements['project/parent/groupId'].nil?
      return dom.elements['project/parent/groupId'].text
    end
    'Group id not found'
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
          component = "#{group_id.text}.#{artifact_id.text}"
          doc.elements.each('/project/dependencies/dependency') do |e|
            depend = "#{expand(e.elements['groupId'].text, doc)}.#{e.elements['artifactId'].text}"
            add_dependency(component, depend)
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
      dependencies << {'name' => node.name, 'imports' => imports}
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