##########################################################################
# Coral's Middleman Extensions
##########################################################################

require 'yaml'
require 'kramdown'
require 'pygments'
require 'active_support/json'

# support for '.blank?' queries
require 'active_support/core_ext/object/blank'

module Coral

  API_BASE_PATH = "reference/modules/"

  # General-purpose module methods
  class << self

    # Path to the API doc page of a Coral type given its name.
    def api_path(name)
      API_BASE_PATH + name.gsub('.', '/')
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

  end

  # Extension that provides the `coral_highlight` helper and
  # makes Kramdown use our syntax highlighter.
  class HighlighterExtension < Middleman::Extension
    def initialize(app, options_hash={}, &block)
      super
    end
    helpers do
      def coral_highlight(lang, &block)
        Coral::highlight(lang, capture(&block))
      end
    end
    def after_configuration
      require 'kramdown'
      Kramdown::Converter::Html.class_eval do
        def convert_codeblock(el, indent)
          lang = extract_code_language!(el.attr.dup)
          return '<pre>' + el.value + '</pre>' unless lang
          Coral::highlight(lang, el.value)
        end
      end
    end
  end
  ::Middleman::Extensions.register(:coral_highlighter, HighlighterExtension)

  # Helpers provided by the DocExtension
  module DocHelpers
    @@primitive_types = %w(string any bool int8 uint8 int16 uint16 int32 uint32 float double void)

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
      extensions[:coral_doc]
    end

    # Link to a Coral type or module. Auto-resolves incomplete names.
    def doc_link(name)
      is_array = name.end_with? '[]'
      basetype = is_array ? name[0, name.size - 2] : name
      if @@primitive_types.include? basetype
        link = %Q{<span class="k">#{basetype}</span>}
      else
        link = %Q{<a href="/#{Coral::api_path(basetype)}" class="nc">#{basetype}</a>}
      end
      link << ( is_array ? '<span class="o">[]</span>' : '' )
    end

    # Coral-flavored Markdown to HTML
    def doc_render(text, out={})
      t = current_page.doc_data
      types = doc.types
      # auto-format the list of raised exceptions
      raises = {}
      doc = text.gsub /^Raises ((?>(?>\w+)\.(?>\w+))+)/ do |s|
        raise "unknown exception '#{$1}'" unless types[$1]
        str = %Q{#{raises.empty? ? "{:.raises}\n" : ''}- #{$1}}
        raises[$1] = true
        str
      end
      out[:raises] = raises
      # explicit type references
      doc.gsub! /\[([^\]]+)\]\(([^\)]+)\)/ do |s|
        "[#{$1}](#{types[$2] ? "/#{Coral::api_path($2)}" : $2})"
      end
      # auto link enum identifiers
      doc.gsub! /`(\w+)`/ do |s|
        enum = t.module.ids[$1]
        enum ? %Q{<a href="/#{Coral::api_path enum}##{$1}" class="no">#{$1}</a>} : s
      end
      # auto link: #memberRef
      doc.gsub! /(?<=\s)\#(\w+)/ do |s|
        m = t.members.find{ |m| m.name == $1 }
        m ? %Q{<a href="#{s}" class="#{pygment_for m.kind}">#{$1}</a>} : s
      end
      # auto link: type.Name#optMemberRef
      doc.gsub! /((?>(?>\w+)\.(?>\w+))+)(?>\#(\w+))?/ do |s|
        tt = types[$1]
        if tt and $2
          m = tt.members.find{ |m| m.name == $2 }
          raise "no such member '#{$2}' in #{$1}" unless m
          %Q{<a href="/#{Coral::api_path $1}##{$2}" class="#{pygment_for m.kind}">#{$2}</a>}
        else
          tt ? doc_link($1) : s
        end
      end
      Kramdown::Document.new(doc, config.markdown).to_html
    end

    # Coral-flavored Markdown to Plain Text
    def doc_plain(text)
      text = text.gsub(/\#(\w+)/) { $1 } # member references
      text.gsub!(/\!?\[([^\]]+)\]\([^\)]+\)/) { $1 } # inline links
      strip_tags(Kramdown::Document.new(text, config.markdown).to_html)
    end

    # Iterate the supertypes of a type
    def each_supertype_of(type)
      while type.base
        yield type.base
        type = doc.types[type.base]
      end
    end

    def supertypes_of(type)
      [].tap { |res| each_supertype_of(type) { |sup| res << sup } }
    end
  end # End of DocHelpers

  # Extends API pages with custom methods
  class APIRefPage < Middleman::Sitemap::Resource
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
      @t ? @t : @m
    end

    def title
      doc_data.name
    end
  end

  # Coral documentation extension, accessed via `doc` in templates.
  class DocExtension < Middleman::Extension
    option :modules, [], 'List of modules with JSON files in data/modules.'

    attr_reader :modules  # hash: module name => documentation data
    attr_reader :types    # hash: type name => documentation data
    attr_reader :tags     # hash: tag name => types

    self.defined_helpers = [Coral::DocHelpers]

    def initialize(app, options_hash={}, &block)
      super
      raise "at least one module must be specified" if options.modules.empty?
      @modules = {}
      @types = {}
      @tags = {}
    end

    def after_configuration
      @app.ignore 'reference/modules_/*'
      reload_data()
      doc_ext = self
      @app.before do
        # make sure all module data is up-to-date
        doc_ext.options.modules.each do |name|
          if doc_ext.modules[name].datetime != data.modules[name].datetime
            doc_ext.reload_data()
            sitemap.rebuild_resource_list!
            puts "Reloaded all coral modules!"
            break
          end
        end
      end
    end

    def manipulate_resource_list(resources)
      @modules.each do |module_name, m|
        resources << APIRefPage.new(@app, module_name, m, nil)
        m.types.each do |t|
          resources << APIRefPage.new(@app, t.name, m, t)
        end
      end
      resources
    end

    def reload_data
      # Re-load all module data
      @modules.clear
      @types.clear
      @tags.clear
      options.modules.each do |name|
        m = Marshal.load(Marshal.dump(@app.data.modules[name])) # deep copy
        load_module! m
        @modules[name] = m
      end
      # Post-process all module data
      @modules.each { |name,m| process_module! m }
    end

    private

    def load_module!(m)
      m.types.each { |t| load_type! t }
      m.types.delete_if { |t| t.tags.include? 'private' }
      # build the tags map, so m.tags[tag] = ['type.list']
      mtags = ::Thor::CoreExt::HashWithIndifferentAccess.new()
      m.types.each do |t|
        @types[t.name] = t
        t.tags.each do |tag|
          mtags[tag] ||= []
          mtags[tag] << t
        end
        if t.tags.empty?
          mtags['untagged'] ||= []
          mtags['untagged'] << t
        end
      end
      @tags.merge!(mtags) { |key,oldtags,newtags| oldtags | newtags }
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
      @types[t.base].subtypes << t.name if t.base
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
      to_type = @types[to_tname]
      to_type.backrefs[from_type] = true if to_type
    end

  end
  ::Middleman::Extensions.register(:coral_doc, DocExtension)

end