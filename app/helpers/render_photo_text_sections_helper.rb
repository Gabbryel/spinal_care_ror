module RenderPhotoTextSectionsHelper
  def render_feature(image, txt, reverse)
    if current_page?(controller: 'pages', action: 'home')
      content_tag(:div, class: 'main-landing schroth-main !bg-cl-navbar') do
        concat(content_tag(:div, class: "main-image #{reverse ? 'md:!col-span-1 md:!col-start-1 md:!row-span-2 md:!row-start-1' : 'md:!col-span-1 md:!col-start-2 md:!row-span-2 md:!row-start-1'}") do
          cl_image_tag(image, :quality=>60, :width=>1000, :crop=>"scale")
        end)
        concat(content_tag(:div, class: "main-motto  #{reverse ? 'md:!col-span-1 md:!col-start-2 md:!row-span-2 md:!row-start-1' : 'md:!col-span-1 md:!col-start-1 md:!row-span-2 md:!row-start-1'}") do
          content_tag(:p, txt, class: 'text-lg sm:text-xl md:text-2xl lg:text-3xl 2xl:text-4xl text-center text-cl-txt-light font-poppins')
        end)
      end
    end
  end
end
