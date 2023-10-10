module ApplicationHelper
  def path_helper
    request.path.split('/')[1].to_s
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
    "#{member.first_name} #{member.last_name}"
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
end
