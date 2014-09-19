require 'ripper'
require 'forwardable'

class TraversingContext
  extend Forwardable
  attr_reader :module, :options
  def_instance_delegators :'@options', :'[]', :'[]='

  def initialize(mod = [], options = {})
    @module = mod
    @options = options
  end

  def push_modules(*modules)
    @module = @module.concat(modules)
  end

  def module_name
    @module.join('::')
  end

  def full_class_name(class_name)
    module_name + '::' + class_name
  end
end

class TraversingResult
  attr_reader :namespace, :declared, :used, :parent, :children
  def initialize(namespace = nil, parent = nil)
    @declared = []
    @used = []
    @parent = parent
    @namespace = namespace
    @children = []
  end

  def declare_const(const)
    @declared << const
  end

  def use_const(const, analyze = true)
    if analyze
      return if @used.map{|a| a.last }.include?(const)
      if const.start_with?('::')
        @used << [const]
      else
        const_ary = const.split('::')
        variants = []
        if const_ary.first == namespace
          (variants << const_ary.dup).last.shift
        else
          (variants << const_ary.dup).last.unshift(@namespace) unless @namespace.nil?
        end

        variants << [ const_ary ]
        @used << variants.map{|v| v.join('::')}
      end
    else
      @used << const
    end
  end

  def nest(namespace)
    r = TraversingResult.new(namespace, self)
    @children << r
    r
  end

  def used; @used end
  def declared; @declared end

  def full_namespace
    p = self
    namespace_parts = []
    namespace_parts << p.namespace if p.namespace
    unless p.parent.nil?
      p = p.parent
      namespace_parts.unshift(p.namespace) if p.namespace
    end

    namespace_parts
  end

  def extract_consts
    result = {
        declared: declared.map{|d| (namespace || '') + '::' + d },
        used: []
    }

    @children.map(&:extract_consts).each{|c|
       result[:declared] = result[:declared].concat(c[:declared].map{|d| (namespace || '') + '::' + d })
       result[:used] = result[:used].concat(c[:used].map!{|_| _.map!{|v|
                 if v.start_with?('::') || (namespace && v.start_with?(namespace + '::'))
                   v
                 else
                   (namespace || '') + '::' + v
                 end
               } })
    }

    result[:used] = result[:used].reject {|variants|
      !variants.find{|v| result[:declared].include?(v) }.nil?
    }

    used = self.used.reject {|variants| !variants.find{|v| result[:declared].include?(v) }.nil? }
    if namespace.nil?
      used = used.map {|variants| variants.map{|v| (v.start_with?('::') ? '' : (namespace || '') + '::') + v }}
    end
    #
    # ns_variants = [namespace.to_s+'::']
    # full_namespace[0..-2].reverse.each{|ns| ns_variants << ns + '::' + ns_variants.last}
    # used.each do |variants|
    #   # variants = variants.reject{ |v|
    #   #   !ns_variants.find{|ns_part| v.start_with?(ns_part) }.nil?
    #   # }
    #   result[:used] = result[:used] << variants
    # end

    result[:used] = result[:used].concat(used)

    result
  end
end

class ASTEntity
  class << self
    def ripper_id; raise 'Override ripper_id method with ripper id value' end
    def inherited(subclass)
      node_classes << subclass
    end
    def node_classes
      @node_classes ||= []
    end
    def node_classes_cache
      return @node_classes_cache if @node_classes_cache
      @node_classes_cache = Hash[node_classes.map(&:ripper_id).zip(node_classes)]
    end
    def node_for(node_ary)
      if node_classes_cache[node_ary.first]
        node_classes_cache[node_ary.first].new(*node_ary[1..-1])
      else
        if node_ary.first.kind_of?(Symbol)
          load(node_ary)
        else
          # Code position for identifier
          return if node_ary.kind_of?(Array) and (node_ary.size == 2) and node_ary[0].kind_of?(Integer) and node_ary[1].kind_of?(Integer)
          node_ary.map{|n| load(n) }
        end
      end
    end
    def load(node)
      new(*node[1..-1])
    end
  end

  def initialize(*args)
    @body = args.map{ |node_ary|
      ASTEntity.node_for(node_ary) if node_ary.kind_of?(Array)
    }
  end

  def collect_constants(result, context = nil)
    result ||= TraversingResult.new
    @body.each{|e|
      case e
        when ASTEntity
          e.collect_constants(result, context || (TraversingContext.new)) unless e.nil?
        when Array
          e.map{|e| e.collect_constants(result, context || (TraversingContext.new)) unless e.nil? }
        else
      end
    } unless @body.nil?
    result
  end
end

class ASTProgramDecl < ASTEntity
  def self.ripper_id; :program end
  def initialize(*args)
    @body = args.first.map{|a| ASTEntity.node_for(a)}
  end
end


class ASTBody < ASTEntity
  def self.ripper_id; :bodystmt end
  def initialize(*args)
    @body = args.first.map{ |node| ASTEntity.node_for(node) }
  end
  def collect_constants(result, context)
    context[:variable_assignment] = false
    super(result, context)
  end
end

class ASTClass < ASTEntity
  def self.ripper_id; :class end
  def collect_constants(result, context)
    context[:variable_assignment] = true
    super(result, context)
  end
end

class ASTConstRef < ASTEntity
  def self.ripper_id; :const_ref end
  def initialize(*args)
    @const_name = args[0][1]
  end
  def collect_constants(result, context)
    result.declare_const(@const_name)
    super(result, context)
  end
end

class ASTTopConstRef < ASTEntity
  def self.ripper_id; :top_const_ref end
  def collect_constants(result, context)
    context[:top] = true
    super(result, context)
    context[:top] = false
  end
end

class ASTArgsAddBlock < ASTEntity
  def self.ripper_id; :args_add_block end
  def initialize(*args)
    super(*args.flatten(1))
  end
end

class ASTBareAssocHash < ASTEntity
  def self.ripper_id; :bare_assoc_hash end
  def initialize(*args)
    super(*args.flatten(2))
  end
end

class ASTArray < ASTEntity
  def self.ripper_id; :array end
  def initialize(*args)
    super(*args.flatten(1))
  end
end

class ASTConst < ASTEntity
  def self.ripper_id; :'@const' end
  def initialize(*args)
    @const_name = args[0]
  end
  def collect_constants(result, context)
    if context[:variable_assignment]
      result.declare_const(@const_name)
    else
      analyze_const = context[:analyze_const].nil? ? true  : context[:analyze_const]
      if context[:top]
        result.use_const('::'+@const_name)
      else
        result.use_const(@const_name, analyze_const)
      end

    end

    super(result, context)
  end
end

class ASTConstPathRef < ASTEntity
  def self.ripper_id; :const_path_ref end
  def initialize(*args)
    @path = ASTEntity.node_for(args.first)
    @const = ASTEntity.node_for(args.last)
  end
  def collect_constants(result, context)
    if context[:const_path_ref]
      r = TraversingResult.new
      c = context.dup
      c[:analyze_const] = false
      path_consts = @path.collect_constants(r, context)
      const = @const.collect_constants(r, context)
      result.use_const(path_consts.used.join('::'), false)
    else
      r = TraversingResult.new
      new_context = TraversingContext.new([], {const_path_ref: true, analyze_const: false})
      path_consts = @path.collect_constants(r, new_context)
      const = @const.collect_constants(r, new_context)
      result.use_const(path_consts.used.join('::'))
    end
    result
  end
end

class ASTModule < ASTEntity
  def self.ripper_id; :module end
  def initialize(*args)
    @module_name = args.find{|a| a.first == :const_ref}.last[1]
    @body = args.find{|a| a.first == :bodystmt}[1].map{|node|
      ASTEntity.node_for(node)
    }
  end
  def collect_constants(result, context)
    result = result.nest(@module_name)
    context.module << @module_name
    super(result, context)
  end
end

class ASTVarField < ASTEntity
  def self.ripper_id; :var_field end
  def collect_constants(result, context)
    context[:variable_assignment] = true
    super(result, context)
    context[:variable_assignment] = false
  end
end

class ASTRef < ASTEntity
  def self.ripper_id; :var_ref end
  def collect_constants(result, context)
    context[:variable_assignment] = false
    super(result, context)
  end
end


class Ripper
  def self.extract_constants(code)
    ast = Ripper.sexp(code)
    result = ASTEntity.node_for(ast).collect_constants(TraversingResult.new)
    consts = result.extract_consts
    consts[:declared].flatten!
    consts[:declared].uniq!
    consts
  end
end
