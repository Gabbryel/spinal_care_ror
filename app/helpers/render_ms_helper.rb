module RenderMsHelper
  def render_medical_service(medical_service)
    # content_tag :div, class: '' do
      concat render(partial: 'admin/medical_services/medical_service_info', locals: { medical_service: medical_service })
      concat(
        content_tag(:div, class: 'grid grid-cols-10') do
          concat content_tag(:span, class: 'col-span-8 max-h-max mb-[1rem]') {
            concat medical_service.name
            concat tag(:br)
            # if medical_service.member
            #   concat tag.a(href: "/echipa/#{medical_service.member.slug if medical_service.member}", class: 'text-color-1') {
            #     concat content_tag(:span, "#{medical_service.member.academic_title}", class: 'font-semibold')
            #     concat content_tag(:span, "#{full_name(medical_service.member)}", class: 'font-semibold')
            #   }
            # end
            if medical_service.has_day_hospitalization
              concat link_to('specialitati-medicale/spitalizare-de-zi') {
                content_tag(:span, '🏥 spitalizare de zi', class: 'badge bg-color-1')
              }
            end
          }
          concat content_tag(:span, class: 'col-span-2 text-end') {
            medical_service.price == 0 ? action_btn('📞', nil, nil) : "#{medical_service.price} lei"
          }
        end
      )
      if access
        concat render(partial: 'admin/medical_services/medical_service_policy', locals: { medical_service: medical_service })
      end
    end
  # end
end