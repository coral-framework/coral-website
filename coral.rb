########################################################################
# Middleman Extension :coral_doc -- Coral Documentation Framework
########################################################################

require 'yaml'
require 'pygments'
require 'active_support'

module Coral

  API_BASE_PATH = "reference/modules"

  PRIMITIVE_TYPES = %w(string any bool int8 uint8 int16 uint16 int32 uint32 float double void)

  mattr_accessor :middleman_app

  mattr_accessor :modules  # hash: module name => documentation data
  mattr_accessor :types    # hash: type name => documentation data
  mattr_accessor :tags     # hash: tag name => types

  self.modules = {}
  self.types = {}
  self.tags = {}

  # Coral module methods
  class << self
    # Path to the API doc page of a Coral type given its name.
    def api_path(name)
      API_BASE_PATH + '/' + name.gsub('.', '/')
    end

    # Syntax highlight a code snippet using Pygments.
    def highlight(lang, code)
      %Q{<div class="hl code"><pre class="#{lang}">\n} <<
        Pygments.highlight(code, lexer: lang, options: {
          encoding: 'utf-8', nowrap: true, tabsize: 4,
        } ) << "</pre></div>"
    end

    # Modify a multi-line string so it is indented with spaces,
    # aligned left, with no blank lines at the beginning/end.
    def pre_format!( str )
      str.rstrip! # remove trailing whitespaces
      str.gsub! /\A(.)/, "\n\\1" # add a newline at the beginning
      str.gsub! "\t", ' ' * 4 # tab to spaces
      # align left
      min_indent = str.size
      str.scan /^( +)\S/ do |indent|
        min_indent = $1.size if $1.size < min_indent
      end
      str.gsub! /\n#{' ' * min_indent}/, "\n" if min_indent < str.size
      str.slice! /\A\n+/ # remove leading newlines
    end

    # Formats lines matching the pattern 'Raises an.Exception paragraph...'
    # into a markdown list and saves the raised exceptions in a hash.
    def format_raises(text, raises)
      text.gsub /^Raises ((?>(?>\w+)\.(?>\w+))+)/ do |s|
        raise "unknown exception '#{$1}'" unless types[$1]
        str = %Q{#{raises.empty? ? "{:.raises}\n" : ''}- #{$1}}
        raises[$1] = true
        str
      end
    end

  end

  # Helpers provided by extension :coral_doc
  module Helpers

    # Returns the pygments class for a type/member kind
    def pygment_for(kind)
      case kind
      when 'field' then 'nv'
      when 'method' then 'nf'
      else 'nc' # type names
      end
    end

    # The coral documentation data store
    def doc
      Coral
    end

    # Link to a Coral type or module. Auto-resolves incomplete names.
    def doc_link(name)
      is_array = name.end_with? '[]'
      basetype = is_array ? name[0, name.size - 2] : name
      if PRIMITIVE_TYPES.include? basetype
        link = %Q{<span class="k">#{basetype}</span>}
      else
        link = %Q{<a href="/#{Coral::api_path(basetype)}" class="nc">#{basetype}</a>}
      end
      link << ( is_array ? '<span class="o">[]</span>' : '' )
    end

    # Returns the ancestors of a type, from its parent to the root type.
    def ancestors_of(type)
      list = []
      while type.base
        list << type.base
        type = Coral::types[type.base]
      end
      list
    end

  end # End of Helpers

  # Extends API pages with custom methods
  class APIRefPage < ::Middleman::Sitemap::Resource
    def initialize(app, name, m, t)
      super(app.sitemap, "#{Coral::api_path(name)}/#{app.index_file}")
      @m, @t = m, t
      template = "reference/modules_/#{name.gsub('.', '/')}"
      if Dir.glob(File.expand_path("#{template}.*", app.source_dir)).empty?
        template = "reference/modules_/template"
      end
      proxy_to "#{template}.html"
      add_metadata options: { layout: t ? 'ref_type' : 'ref_module' },
        locals: { m: m, t: t }
    end

    def doc_data
      @t || @m
    end

    def title
      doc_data.name
    end
  end

  # Coral documentation extension, accessed via `doc` in templates.
  class DocExtension < ::Middleman::Extension
    option :modules, [], 'List of modules with JSON files in data/modules.'

    self.defined_helpers = [Coral::Helpers]

    def initialize(app, options_hash={}, &block)
      super
      raise "at least one module must be specified" if options.modules.empty?
    end

    def after_configuration
      Coral.middleman_app = @app
      @app.ignore 'reference/modules_/*'
      reload_data()
      coral_doc = self
      @app.before do
        # make sure all module data is up-to-date
        coral_doc.options.modules.each do |name|
          if Coral.modules[name].datetime != data.modules[name].datetime
            coral_doc.reload_data()
            sitemap.rebuild_resource_list!
            puts "Reloaded all coral modules!"
            break
          end
        end
      end
    end

    def manipulate_resource_list(resources)
      Coral.modules.each do |module_name, m|
        resources << APIRefPage.new(@app, module_name, m, nil)
        m.types.each do |t|
          resources << APIRefPage.new(@app, t.name, m, t)
        end
      end
      resources
    end

    def reload_data
      # Re-load all module data
      Coral.modules.clear
      Coral.types.clear
      Coral.tags.clear
      options.modules.each do |name|
        m = Marshal.load(Marshal.dump(@app.data.modules[name])) # deep copy
        load_module! m
        Coral.modules[name] = m
      end
      # Post-process all module data
      Coral.modules.each { |name,m| process_module! m }
    end

    private

    def load_module!(m)
      m.types.each { |t| load_type! t }
      m.types.delete_if { |t| t.tags.include? 'private' }
      # build the tags map, so m.tags[tag] = ['type.list']
      mtags = ::Thor::CoreExt::HashWithIndifferentAccess.new()
      m.types.each do |t|
        Coral.types[t.name] = t
        t.tags.each do |tag|
          mtags[tag] ||= []
          mtags[tag] << t
        end
        if t.tags.empty?
          mtags['untagged'] ||= []
          mtags['untagged'] << t
        end
      end
      Coral.tags.merge!(mtags) { |key,oldtags,newtags| oldtags | newtags }
      m['tags'] = mtags
    end

    def load_type!(t)
      begin
        load_doc! t
        t.members.each{ |m| load_doc! m } if t.members
      rescue Exception => e
        puts "Error while processing type #{t.name}: #{e.message}"
        raise
      end
      t['backrefs'] = {}
      t['subtypes'] = []
      t['tags'] = (t.tags or '').downcase.split /\s+/
      Coral::pre_format!(t.cpp) if t.cpp
    end

    def load_doc!(elem)
      Coral::pre_format!(elem.doc)

      # extract the content and YAML backmatter from the doc
      doc, sep, yaml = elem.doc.partition /^\s*---\s*$/
      elem.deep_merge!( (YAML.load(yaml)||{}).symbolize_keys ) if yaml
      elem['doc'] = doc

      # doc headline and body
      caption, _, body = doc.partition "\n\n"
      elem['doc_caption'], elem['doc_body'] = caption.strip, body
    end

    def process_module!(m)
      ids = {} # mapping: module-identifier => module-enum
      m.types.each do |t|
        t['module'] = m
        process_type! t
        # gather enum identifiers
        t.identifiers.each do |id|
          raise "enums #{t.name} and #{ids[id.id]} both define '#{id.id}'" if ids[id.id]
          ids[id.id] = t.name
        end if t.identifiers
      end
      m['ids'] = ids
    end

    def process_type!(t)
      Coral.types[t.base].subtypes << t.name if t.base
      # process type cross-references
      process_ref!(t, t.base)
      t.members.each do |m|
        process_ref!(t, m.type)
        process_ref!(t, m.returnType)
        m.parameters.each do |param|
          process_ref!(t, param.type)
        end if m.parameters
        m.exceptions.each do |ex|
          process_ref!(t, ex)
        end if m.exceptions
      end if t.members
    end

    def process_ref!(from_type, to_tname)
      return unless to_tname
      to_tname = to_tname[0, to_tname.size - 2] if to_tname.end_with? '[]'
      to_type = Coral.types[to_tname]
      to_type.backrefs[from_type] = true if to_type
    end

  end

  Middleman::Extensions.register(:coral_doc, DocExtension)

end

########################################################################
# Middleman Extension :coral_markdown -- Coral Flavored Markdown (CFM)
########################################################################

require 'middleman-core/renderers/kramdown'

class Kramdown::Parser::Coral < Kramdown::Parser::Kramdown

  def initialize(source, options)
    super
    i = @block_parsers.index(:codeblock_fenced)
    @block_parsers.delete(:codeblock_fenced)
    @block_parsers.insert(i, :codeblock_fenced_gfm)
  end

  # GitHub-style fenced codeblocks
  FENCED_CODEBLOCK_MATCH = /^(([~`]){3,})\s*?(\w+)?\s*?\n(.*?)^\1\2*\s*?\n/m
  define_parser(:codeblock_fenced_gfm, /^`{3,}/, nil, 'parse_codeblock_fenced')

end

class Kramdown::Converter::CoralHtml < Middleman::Renderers::MiddlemanKramdownHTML

  def convert_codeblock(el, indent)
    lang = extract_code_language(el.attr)
    if lang
      Coral::highlight(lang, el.value)
    else
      '<pre>' + el.value + '</pre>'
    end
  end

  def convert_a(el, indent)
    content = inner(el, indent)

    attr = el.attr.dup
    link = attr.delete('href')

    link = "/#{Coral::api_path link}" if Coral.types[link]

    Coral.middleman_app.link_to(content, link, attr)
  end

end

# Custom Tilt template extending Middleman's Kramdown template.
class Tilt::CoralTemplate < Middleman::Renderers::KramdownTemplate

  include Coral::Helpers

  def prepare
    str = data.to_str

    # auto link: type.Name#optMemberRef
    str.gsub! /((?>(?>\w+)\.(?>\w+))+)(?>\#(\w+))?/ do |s|
      type = Coral.types[$1]
      if type
        if $2
          m = type.members.find{ |m| m.name == $2 }
          raise "no such member '#{$2}' in #{$1}" unless m
          %Q{<a href="/#{Coral::api_path $1}##{$2}" class="#{pygment_for m.kind}">#{$2}</a>}
        else
          doc_link($1)
        end
      else
        s
      end
    end

    page = Coral.middleman_app.current_page
    if page.is_a? Coral::APIRefPage
      type = page.doc_data
      # auto link enum identifiers
      str.gsub! /`(\w+)`/ do |s|
        enum = type.module.ids[$1]
        enum ? %Q{<a href="/#{Coral::api_path enum}##{$1}" class="no">#{$1}</a>} : s
      end
      # auto link: #memberRef
      str.gsub! /(?<=\s)\#(\w+)/ do |s|
        m = type.members.find{ |m| m.name == $1 }
        m ? %Q{<a href="#{s}" class="#{pygment_for m.kind}">#{$1}</a>} : s
      end
    end

    options[:input] ||= 'Coral'
    options[:auto_ids] ||= false
    options[:enable_coderay] ||= false
    @engine = Kramdown::Document.new(str, options)
    @output = nil
  end

  def evaluate(scope, locals, &block)
    @output ||= begin
      output, warnings = Kramdown::Converter::CoralHtml.convert(@engine.root, @engine.options)
      @engine.warnings.concat(warnings)
      output
    end
  end

end

module Coral

  class MarkdownExtension < Middleman::Extension

    def initialize(app, options_hash={}, &block)
      super
    end

    helpers do
      # Coral-flavored Markdown to HTML
      def cfm_to_html(text, scope=Object.new, locals={})
        Tilt['markdown'].new{ text }.render(scope, locals)
      end

      # Coral-flavored Markdown to Plain Text
      def cfm_to_plaintext(text)
        text = text.gsub(/\#(\w+)/) { $1 } # member references
        text.gsub!(/\!?\[([^\]]+)\]\([^\)]+\)/) { $1 } # inline links
        strip_tags(Kramdown::Document.new(text, config.markdown).to_html)
      end
    end

    def after_configuration
      raise "please activate :coral_doc before :coral_markdown" unless Coral.middleman_app
      Kramdown::Converter::CoralHtml.middleman_app = Coral.middleman_app
    end

  end

  Middleman::Extensions.register(:coral_markdown, MarkdownExtension)
end