###
# Global Settings
###

set :build_dir, 'build'
set :data_dir, 'data'
set :css_dir, 'assets/stylesheets'
set :sass_dir, 'assets/stylesheets'
set :fonts_dir, 'assets/fonts'
set :images_dir, 'assets/images'
set :js_dir, 'assets/javascripts'
set :layouts_dir, 'layouts'
set :partials_dir, 'layouts'

set :strip_index_file, true
set :trailing_slash, false

ignore 'assets/icons/*'
ignore 'assets/fonts/bootstrap/*'

# custom acronyms
ActiveSupport::Inflector.inflections do |inflect|
  inflect.acronym "API"
  inflect.acronym "CSL"
end

###
# Extensions
###

require 'compass'

require 'coral'
activate :coral_doc, modules: %w(co lua)
activate :coral_markdown

set :markdown, header_offset: 1
set :markdown_engine, :coral

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
  def page_title_short(page)
    page.data.title_short || page_title(page)
  end

  # The short title of a page.
  def page_icon(page)
    %Q{<i class="icon-#{page.data.icon || 'page'}"></i>}
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
    nav_link(p.url, "#{page_icon(p)} #{page_title_short(p)}", &block)
  end

  # Scans header tags within an html string and returns a hash: id => [title, level]
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
  activate :favicon_maker, icons: {
    "favicon_hires.png" => [
      { icon: "apple-touch-icon-152x152-precomposed.png" },
      { icon: "apple-touch-icon-114x114-precomposed.png" },
      { icon: "apple-touch-icon-72x72-precomposed.png" },
    ],
    "favicon_lores.png" => [
      { icon: "favicon.png", size: "64x64" },
      { icon: "favicon.ico", size: "64x64,32x32,24x24,16x16" },
    ]
  }

  # Optimizations for deployment
  activate :minify_css
  activate :minify_html
  activate :minify_javascript

  # Enable cache buster
  # activate :asset_hash

  # Use relative URLs
  activate :relative_assets
end

# Pretty URLs
activate :directory_indexes

# Deploy via gh-pages
activate :deploy do |deploy|
  deploy.method = :git
end
