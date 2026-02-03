class JobPostingsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  skip_after_action :verify_policy_scoped, only: [:index]
  skip_after_action :verify_authorized, only: [:show]
  before_action :set_job_posting, only: [:show, :update, :destroy]
  before_action :set_dashboard_layout, only: [:create, :update, :destroy]
  
  def index
    @job_postings = JobPosting.active.recent
  end
  
  def show
  end

  def create
    @job_posting = JobPosting.new(job_posting_params)
    authorize @job_posting
    
    if @job_posting.save
      redirect_to admin_job_postings_path, notice: 'Postarea a fost creată cu succes.'
    else
      redirect_to admin_job_postings_path, alert: 'Eroare la crearea postării.'
    end
  end

  def update
    authorize @job_posting
    
    if @job_posting.update(job_posting_params)
      redirect_to admin_job_postings_path, notice: 'Postarea a fost actualizată cu succes.'
    else
      redirect_to admin_job_postings_path, alert: 'Eroare la actualizarea postării.'
    end
  end

  def destroy
    authorize @job_posting
    @job_posting.destroy
    redirect_to admin_job_postings_path, notice: 'Postarea a fost ștearsă cu succes.'
  end
  
  private
  
  def set_job_posting
    @job_posting = JobPosting.find(params[:id])
  end
  
  def job_posting_params
    params.require(:job_posting).permit(:name, :valid_until, :description)
  end
  
  def set_dashboard_layout
    self.class.layout 'dashboard'
  end
end
