class MedicinesConsumption < ApplicationRecord
  include Auditable
  
  MONTHS = [
    'Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie',
    'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie'
  ].freeze
  
  # Validations
  validates :month, presence: true, inclusion: { in: MONTHS }
  validates :year, presence: true, 
            numericality: { only_integer: true, greater_than_or_equal_to: 2000, less_than_or_equal_to: 2100 }
  validates :consumption, presence: true, 
            numericality: { greater_than_or_equal_to: 0 }
  validates :month, uniqueness: { scope: :year, message: "pentru acest an există deja" }
  
  # Scopes
  scope :by_year, ->(year) { where(year: year) if year.present? }
  scope :recent, -> { order(year: :desc, month: :desc) }
  scope :by_year_and_month, -> { order(year: :desc, month: :desc) }
  scope :current_year, -> { where(year: Time.current.year) }
  scope :last_12_months, -> {
    current_date = Time.current
    where('year > ? OR (year = ? AND month >= ?)', 
          current_date.year - 1, 
          current_date.year - 1, 
          MONTHS[current_date.month - 1])
  }
  
  # Instance methods
  def month_number
    MONTHS.index(month) + 1 if month.present?
  end
  
  def display_name
    "#{month} #{year}"
  end
  
  def formatted_consumption
    format('%.2f', consumption)
  end
end
