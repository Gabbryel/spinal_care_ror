# Repairs what pasting into the rich-text editor leaves behind, on save
# (condition/procedure pages, specialties, team members, patient info):
#
# - Text pasted while the cursor sat in a numbered list arrives as one big
#   <ol> whose items are the paragraphs and headings, so the page showed a
#   numbering nobody typed. A list that contains headings is never a real
#   list, so it is unwrapped (lists nested inside its items are kept).
# - Images pasted together with text arrive as data: URLs inside the HTML
#   (one page reached 1.3 MB). They are uploaded as Active Storage blobs and
#   replaced by normal attachments.
module CleanRichText
  extend ActiveSupport::Concern

  HEADINGS = "h1, h2, h3, h4, h5, h6".freeze
  DATA_URL = %r{\Adata:(image/[a-z0-9.+-]+);base64,(.+)\z}im

  class_methods do
    def cleans_rich_text(*names)
      before_save { names.each { |name| clean_rich_text(name) } }
    end
  end

  private

  def clean_rich_text(name)
    rich = public_send(name)
    return if rich.nil? || rich.body.blank?

    fragment = Nokogiri::HTML::DocumentFragment.parse(rich.body.to_html)
    lists = unwrap_heading_lists(fragment)
    images = upload_inline_images(fragment)
    rich.body = ActionText::Content.new(fragment.to_html) if lists || images
  end

  # Returns true when something changed.
  def unwrap_heading_lists(fragment)
    changed = false
    while (list = fragment.css("ol, ul").find { |l| l.xpath("./li").any? { |li| li.at_css(HEADINGS) } })
      list.xpath("./li").each do |item|
        # Trix keeps paragraph text inline in <li>; give each run of inline
        # content its own block so paragraphs stay apart once unwrapped.
        blocks = []
        inline = Nokogiri::XML::NodeSet.new(fragment.document)
        flush = lambda do
          unless inline.empty? || inline.all? { |n| n.name == "br" || (n.text? && n.text.strip.empty?) }
            div = Nokogiri::XML::Node.new("div", fragment.document)
            inline.each { |n| div.add_child(n) }
            blocks << div
          end
          inline = Nokogiri::XML::NodeSet.new(fragment.document)
        end
        item.children.each do |child|
          if child.element? && (child.matches?(HEADINGS) || %w[ol ul div blockquote pre].include?(child.name))
            flush.call
            blocks << child
          else
            inline << child
          end
        end
        flush.call
        blocks.each { |block| item.add_previous_sibling(block) }
        item.remove
      end
      list.children.each { |child| list.add_previous_sibling(child) }
      list.remove
      changed = true
    end
    changed
  end

  def upload_inline_images(fragment)
    changed = false
    fragment.css("action-text-attachment[url^='data:'], img[src^='data:']").each_with_index do |node, index|
      match = DATA_URL.match(node["url"] || node["src"])
      next unless match

      content_type = match[1].downcase
      extension = Rack::Mime::MIME_TYPES.invert[content_type]&.delete_prefix(".") || "png"
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(Base64.decode64(match[2])),
                                                    filename: "imagine-#{index + 1}.#{extension}", content_type: content_type)
      attachment = ActionText::Attachment.from_attachable(blob, caption: node["caption"].presence)
      node.replace(Nokogiri::HTML::DocumentFragment.parse(attachment.to_html))
      changed = true
    end
    changed
  end
end
