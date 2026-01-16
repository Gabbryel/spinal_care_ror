class AdminController < ApplicationController
  layout "dashboard"
  def dashboard
    @m = Member.new()
    @professions = Profession.all
  end
  
  def analytics
    # Audit data
    @total_members = Member.count
    @total_services = MedicalService.count
    @total_specialties = Specialty.count
    @total_professions = Profession.count
    @total_facts = Fact.count
    @total_users = User.count
    @admin_users = User.where(admin: true).count
    @god_mode_users = User.where(god_mode: true).count
    
    # Visitor analytics (exclude dashboard/admin pages)
    public_visits = Ahoy::Visit.where("landing_page NOT LIKE ? OR landing_page IS NULL", '%/dashboard%')
    
    @total_visits = public_visits.count
    @total_visits_today = public_visits.where('started_at >= ?', Time.zone.now.beginning_of_day).count
    @total_visits_this_week = public_visits.where('started_at >= ?', 1.week.ago).count
    @total_visits_this_month = public_visits.where('started_at >= ?', 1.month.ago).count
    @unique_visitors = public_visits.distinct.count(:visitor_token)
    @unique_visitors_this_month = public_visits.where('started_at >= ?', 1.month.ago).distinct.count(:visitor_token)
    
    # Most viewed pages (public only)
    @most_viewed_pages = public_visits.group(:landing_page)
                                     .order('count_all DESC')
                                     .limit(10)
                                     .count
    
    # Referrer sources (public visits only)
    @top_referrers = public_visits.where.not(referrer: nil)
                                  .group(:referring_domain)
                                  .order('count_all DESC')
                                  .limit(10)
                                  .count
    
    # Browser statistics (public visits only)
    @browsers = public_visits.group(:browser)
                             .order('count_all DESC')
                             .limit(10)
                             .count
    
    # Device types (public visits only)
    @device_types = public_visits.group(:device_type)
                                 .order('count_all DESC')
                                 .count
    
    # Daily visits trend (last 30 days, public only)
    @daily_visits = (0..29).map do |i|
      date = i.days.ago.beginning_of_day
      {
        date: date.strftime('%d %b'),
        count: public_visits.where('started_at >= ? AND started_at < ?', date, date + 1.day).count
      }
    end.reverse
    
    # Recent activity
    @recent_members = Member.order(updated_at: :desc).limit(5)
    @recent_services = MedicalService.order(updated_at: :desc).limit(5)
    @recent_facts = Fact.order(updated_at: :desc).limit(5)
    @recent_users = User.order(updated_at: :desc).limit(5)
    
    # Content statistics
    @members_with_bio = Member.joins(:rich_text_description).where.not(action_text_rich_texts: { body: [nil, ''] }).count rescue 0
    @members_with_photo = Member.joins(:photo_attachment).distinct.count rescue 0
    @services_per_specialty = MedicalService.group(:specialty_id).count
    @members_per_profession = Member.group(:profession_id).count
    
    # Time-based statistics
    @members_created_this_month = Member.where('created_at >= ?', 1.month.ago).count
    @services_created_this_month = MedicalService.where('created_at >= ?', 1.month.ago).count
    @facts_updated_this_week = Fact.where('updated_at >= ?', 1.week.ago).count
    @users_created_this_month = User.where('created_at >= ?', 1.month.ago).count
    
    # Database size metrics
    @total_records = Member.count + MedicalService.count + Specialty.count + 
                     Profession.count + Fact.count + User.count
    
    # Growth trends (last 6 months)
    @members_growth = (0..5).map do |i|
      date = i.months.ago.beginning_of_month
      {
        month: date.strftime('%b'),
        count: Member.where('created_at >= ? AND created_at < ?', date, date.end_of_month).count
      }
    end.reverse
    
    @services_growth = (0..5).map do |i|
      date = i.months.ago.beginning_of_month
      {
        month: date.strftime('%b'),
        count: MedicalService.where('created_at >= ? AND created_at < ?', date, date.end_of_month).count
      }
    end.reverse
    
    # Most active models (by updates)
    @most_updated_members = Member.order(updated_at: :desc).limit(10)
    @most_updated_services = MedicalService.order(updated_at: :desc).limit(10)
    
    # Completeness metrics
    @members_without_specialty = Member.where(specialty_id: nil).count
    @services_without_members = MedicalService.left_joins(:members).where(members: { id: nil }).count rescue 0
    
    # Top specialties by service count
    @top_specialties = Specialty.left_joins(:medical_services)
                                .group('specialties.id', 'specialties.name')
                                .select('specialties.*, COUNT(medical_services.id) as services_count')
                                .order('services_count DESC')
                                .limit(10)
    
    # Top professions by member count
    @top_professions = Profession.left_joins(:members)
                                 .group('professions.id', 'professions.name')
                                 .select('professions.*, COUNT(members.id) as members_count')
                                 .order('members_count DESC')
                                 .limit(10)
  end
  
  def edit_users
    @users = User.all.order(email: :asc)
  end

  def personal
    @member = Member.new()
    @members = Member.all.order(last_name: :asc)
    @professions = Profession.all.order(order: :asc)
    @specialties = Specialty.all.order(name: :asc)
  end
  
  def professions
    @profession = Profession.new()
    @professions = Profession.all.order(name: :asc)
  end
  
  def specialties
    @specialty = Specialty.new()
    @specialties = Specialty.all.order(name: :asc)
  end

  def medical_services
    @medical_service = MedicalService.new()
    @medical_services = MedicalService.order(name: :asc).to_a
    @selected_members = Member.includes([:medical_services]).select { |m| m.medical_services.count > 0}.to_a
    @specialties = Specialty.all.order(name: :asc)
  end

  def specialty_admin
    @medical_service = MedicalService.new()
    @specialty = Specialty.find_by!(slug: params[:id])
    
    # Order services: first by member (with member first), then by name
    @services_with_member = @specialty.medical_services
                                      .where.not(member_id: nil)
                                      .includes(:member)
                                      .order('members.last_name ASC, medical_services.name ASC')
    
    @services_without_member = @specialty.medical_services
                                         .where(member_id: nil)
                                         .order(name: :asc)
  end

  def info_pacient
    @fact = Fact.new()
    @facts = Fact.all.sort {|x, y| y.updated_at <=> x.updated_at}
  end

  def test
    @profession = Profession.new()
    @professions = Profession.all.order(name: :asc)
    @specialty = Specialty.new()
    @specialties = Specialty.all.order(name: :asc)
  end

end
