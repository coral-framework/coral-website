###
# Global Settings
###

set :build_dir, 'build'
set :data_dir, 'data'
set :css_dir, 'css'
set :sass_dir, 'css'
set :fonts_dir, 'css/fonts'
set :images_dir, 'img'
set :js_dir, 'js'
set :layouts_dir, 'layouts'
set :partials_dir, 'layouts'

set :strip_index_file, true
set :trailing_slash, false

set :markdown_engine, :kramdown
set :markdown, auto_ids: false, header_offset: 1, enable_coderay: false

ignore 'css/fonts/*'

# custom acronyms
ActiveSupport::Inflector.inflections do |inflect|
  inflect.acronym "API"
  inflect.acronym "CSL"
end

###
# Custom extensions
###

require 'middleman-coral'
activate :coral_doc, modules: %w(co lua)
activate :coral_highlighter

###
# Compass
###

require 'bootstrap-sass'

# Change Compass configuration
compass_config do |config|
#   config.output_style = :compact
  config.http_path = "/"
  config.images_dir = "img"
  config.javascripts_dir = "js"
end

###
# Helpers
###

# Reload the browser automatically whenever files change
activate :livereload

# Methods defined in the helpers block are available in templates
helpers do
  def find_page(extensionless_path)
    sitemap.find_resource_by_destination_path "#{extensionless_path}/#{index_file}"
  end

  def get_page(extensionless_path)
    find_page(extensionless_path) or raise "could not find page '#{extensionless_path}'"
  end

  # List of page ancestors from the first-level page (which is
  # directly under the root) down to the page's parent.
  def page_lineage(page)
    lineage = [] 
    while page.parent.parent
      page = page.parent
      lineage << page
    end
    lineage.reverse!
  end

  # Children of a page in sorted order.
  def page_children(page)
    page.children.sort do |x, y|
      ( x.data.sort_key or x.url ).to_s <=> ( y.data.sort_key or y.url ).to_s
    end
  end

  # The normal title of a page.
  def page_title(page)
    page.data.title || page.title
  end

  # The short title of a page.
  def page_short_title(page)
    page.data.title_short || page_title(page)
  end

  # Page content in HTML (no layout)
  def page_body(page)
    page.render layout: false
  end

  # Page summary in HTML (first paragraph extracted from body)
  def page_summary(page)
    page.data.summary || page_body(page).match(/<p[^>]*>(.+?)<\/p>/m)[1]
  end

  # Formats a nav link to an url
  def nav_link(url, title, &block)
    active = ( url == current_page.url ? ' class="active"' : '' )
    %Q{<li#{active}><a href="#{url}">#{title}</a>#{capture &block if block_given?}</li>}
  end

  # Formats a nav link to a page
  def nav_link_page(p, &block)
    title = page_title(p)
    title = %Q{<i class="fa fa-fw #{p.data.icon}"></i> #{title}} if p.data.icon
    nav_link(p.url, title, &block)
  end

  # Given HTML containing header tags with ids, returns a hash: id => [title, level]
  def extract_toc(content)
    toc = {}
    content.scan /^<h([1-6]) id="([^"]+)"[^>]*>([^<]+).*?<\/h\1>/ do |n, id, title|
      raise "duplicate header id '#{id}'" if toc[id]
      toc[id] = [title, n.to_i]
    end
    toc
  end

  def nav_toc(toc, current_level)
    str = ''; open_lists = 0
    toc.each do |id, (title, level)|
      if current_level < level
        str << %Q{<ul class="nav level-#{level}">}
        open_lists += 1
      elsif current_level > level
        str << '</li></ul>'
        open_lists -= 1
      end
      str << %Q{<li><a href="##{id}">#{title}</a>}
      current_level = level
    end
    open_lists.times { str << '</li></ul>' }
    str
  end

end

# Build-specific configuration
configure :build do
  # Generate favicons
  activate :favicon_maker

  # Optimizations for deployment
  activate :minify_css
  activate :minify_html
  activate :minify_javascript

  # Enable cache buster
  # activate :asset_hash

  # Use relative URLs
  activate :relative_assets

  # Or use a different image path
  # set :http_prefix, "/img/"
end

# Pretty URLs
activate :directory_indexes

# Deploy via gh-pages
activate :deploy do |deploy|
  deploy.method = :git
end
