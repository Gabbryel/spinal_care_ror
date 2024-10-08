module ApplicationHelper
  def path_helper
    request.path.split('/')[1].to_s
  end

  def path_for_id
    request.path.split('/').join('-')
  end

  def access
    current_user && current_user.admin
  end

  def god_mode
    current_user && current_user.god_mode
  end

  def btn_color(u)
    u.admin ? 'btn-red' : 'btn-green'
  end

  def btn_color_god(u)
    u.god_mode ? 'btn-red' : 'btn-green'
  end

  def no_access
    render 'shared/no_access'
  end

  def full_name(member)
    "#{member.first_name} #{member.last_name}" if member
  end
# helper for medical_service dots
  def m_s_helper(ms)
    30 - (ms.name.length + ms.price.to_s.length).to_i
  end

  def description_gsub(item)
    description = item.description.body.to_s
    replacements = {'<div>' => '', '</div' => '', '<br>' => '', '<strong>' => '', '</strong>' => '', '>' => '', '<li>' => '', '</li>' => '', '<ul>' => '', '</ul>' => '', '<div class="trix-content"' => ''}
    description.gsub(/#{Regexp.union(replacements.keys)}/, replacements).strip
  end

  def action_btn(text, x, y)
    button_tag text, class:"btn-nude #{x} #{y}", data: { bs_toggle: "modal", bs_target: "#contactModal"}
  end

  def book_btn(text, class_name)
    button_tag text, class:"btn-nude #{class_name}", data: {bs_toggle: "modal", bs_target: "#promoModal"}
  end

  def see_the_team(anchor)
    button_to 'VEZI TOATĂ ECHIPA', echipa_path.concat("##{anchor}"), class: 'btn btn-action', method: :get, data: {turbo: false}, type: :action
  end
  def selected_and_sorted_medical_services(specialty)
    specialty.medical_services.select { |ms| ms.member != nil }.sort {|a, b| a.member <=> b.member}
  end

  def specialty_specialists(specialty)
    specialists = []
    specialty.medical_services.select { |ms| ms.member != nil }.each do |ms|
      specialists.push(ms.member) unless specialists.include?(ms.member)
    end
    specialists
  end

  def motto(text, class_name)
    content_tag(:div, content_tag(:p, text), class: class_name)
  end

  def title(text, class_reverse_blue, class_reverse_text)
    content_tag :div, class: "section-title" do
      (content_tag :div, nil, class: "section-title-blue #{class_reverse_blue}").concat(
        content_tag :div, text, class: "section-title-text #{class_reverse_text}"
      )
    end
  end
end
