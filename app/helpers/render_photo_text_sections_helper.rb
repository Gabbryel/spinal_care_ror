module RenderPhotoTextSectionsHelper
  def render_feature(image, txt, reverse)
    content_tag(:div, class: 'modern-feature-section') do
      content_tag(:div, class: 'modern-feature-content') do
        content_tag(:div, class: "feature-content-inner #{reverse ? 'reverse' : ''}") do
          concat(content_tag(:div, class: "feature-image") do
            cl_image_tag(image, :quality=>70, :width=>800, :crop=>"scale", :fetch_format=>:auto)
          end)
          concat(content_tag(:div, class: "feature-text") do
            content_tag(:p, txt)
          end)
        end
      end
    end
  end
end
