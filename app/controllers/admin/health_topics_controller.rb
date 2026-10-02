# /dashboard/afectiuni: the condition and procedure pages. New pages start
# as drafts; the list offers suggestions (common conditions per specialty,
# and the clinic's own services as procedures) that create a draft in one
# click, ready to be written.
module Admin
  class HealthTopicsController < BaseController
    before_action :set_topic, only: %i[edit update destroy]

    # Common conditions, each tied to the specialties (by slug) whose doctors
    # treat it. Only those whose specialties exist at the clinic are offered.
    CONDITION_SUGGESTIONS = [
      ["Hernie de disc", %w[neurochirurgie neurologie medicina-fizica-si-de-reabilitare fizioterapie-si-recuperare-medicala]],
      ["Scolioză", %w[terapie-schroth-terapie-pentru-deviatii-de-coloana fizioterapie-si-recuperare-medicala ortopedie]],
      ["Lombosciatică", %w[neurologie medicina-fizica-si-de-reabilitare fizioterapie-si-recuperare-medicala]],
      ["Gonartroză (artroza genunchiului)", %w[ortopedie reumatologie medicina-fizica-si-de-reabilitare]],
      ["Osteoporoză", %w[reumatologie dexa-osteodensitometria endocrinologie]],
      ["Artrită reumatoidă", %w[reumatologie]],
      ["Migrenă", %w[neurologie]],
      ["Recuperare după AVC", %w[neurologie medicina-fizica-si-de-reabilitare fizioterapie-si-recuperare-medicala]],
      ["Hipertensiune arterială", %w[cardiologie medicina-interna]],
      ["Noduli tiroidieni", %w[endocrinologie]],
      ["Diabet zaharat", %w[endocrinologie medicina-interna]],
      ["Reflux gastroesofagian", %w[gastroenterologie]],
      ["Astm bronșic", %w[pneumologie]],
      ["Endometrioză", %w[obstetrica-ginecologie]]
    ].freeze

    def index
      @kind = HealthTopic::KINDS.key?(params[:kind]) ? params[:kind] : nil
      scope = HealthTopic.includes(:specialties).order(published: :asc, updated_at: :desc)
      scope = scope.where(kind: @kind) if @kind
      @topics = scope.to_a
      existing = HealthTopic.pluck(:name).map { |n| I18n.transliterate(n).downcase }
      slugs = Specialty.where(is_active: true).pluck(:slug)
      @condition_suggestions = CONDITION_SUGGESTIONS.select { |name, specs| (specs & slugs).any? && !existing.include?(I18n.transliterate(name).downcase) }
      @services = MedicalService.joins(:specialty).merge(Specialty.where(is_active: true))
                                .includes(:specialty).order("specialties.name", :name).to_a
                                .reject { |s| existing.include?(I18n.transliterate(s.name.to_s).downcase) }
    end

    def new
      @topic = HealthTopic.new(kind: params[:kind].presence_in(HealthTopic::KINDS.keys) || "afectiune")
    end

    def create
      @topic = HealthTopic.new(topic_params)
      if @topic.save
        redirect_to edit_dashboard_health_topic_path(@topic), notice: "Pagina a fost creată ca ciornă. Scrieți textul, apoi bifați „Publicată”."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @topic.update(topic_params)
        redirect_to edit_dashboard_health_topic_path(@topic), notice: @topic.published ? "Salvat. Pagina e publică." : "Salvat ca ciornă."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @topic.destroy!
      redirect_to dashboard_health_topics_path, notice: "Pagina „#{@topic.name}” a fost ștearsă."
    end

    # One click from a suggestion to a draft: a condition with its
    # specialties, or a procedure made from one of the clinic's services.
    def suggest
      if params[:service_id].present?
        service = MedicalService.find(params[:service_id])
        topic = HealthTopic.new(kind: "procedura", name: service.name.to_s.strip, specialty_ids: [service.specialty_id].compact, medical_service_ids: [service.id])
      else
        name, specs = CONDITION_SUGGESTIONS.find { |n, _| n == params[:name] }
        return redirect_to(dashboard_health_topics_path, alert: "Sugestie necunoscută.") unless name

        topic = HealthTopic.new(kind: "afectiune", name: name, specialty_ids: Specialty.where(slug: specs, is_active: true).ids)
      end
      if topic.save
        redirect_to edit_dashboard_health_topic_path(topic), notice: "Ciorna „#{topic.name}” e gata de scris."
      else
        redirect_to dashboard_health_topics_path, alert: "Nu am putut crea ciorna: #{topic.errors.full_messages.to_sentence}."
      end
    end

    private

    def set_topic
      @topic = HealthTopic.find(params[:id])
    end

    def topic_params
      params.require(:health_topic).permit(:kind, :name, :slug, :summary, :body, :seo_title, :meta_description, :faqs_text, :published,
                                           specialty_ids: [], medical_service_ids: [])
    end
  end
end
