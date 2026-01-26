namespace :analytics do
  desc "Seed Ahoy data for testing analytics dashboard"
  task seed: :environment do
    puts "🌱 Seeding Ahoy analytics data..."
    
    # Clear existing data (optional - comment out if you want to keep existing data)
    # Ahoy::Visit.delete_all
    # Ahoy::Event.delete_all
    
    cities = ["București", "Cluj-Napoca", "Timișoara", "Iași", "Constanța", "Craiova", "Brașov", "Galați", "Ploiești", "Oradea"]
    countries = ["România", "Moldova", "Italia", "Spania", "Germania", "Franța"]
    browsers = ["Chrome", "Firefox", "Safari", "Edge"]
    devices = ["Desktop", "Mobile", "Tablet"]
    referrers = [nil, "google.com", "facebook.com", "instagram.com", "direct"]
    
    # Get sample doctors, specialties, services
    doctors = Member.limit(10).pluck(:slug).compact
    specialties = Specialty.limit(5).pluck(:slug).compact
    services = MedicalService.limit(8).pluck(:slug).compact
    
    # Pages to track
    pages = ["/", "/echipa", "/servicii-medicale", "/specialitati-medicale", "/contact"]
    doctors.each { |slug| pages << "/echipa/#{slug}" }
    specialties.each { |slug| pages << "/specialitati-medicale/#{slug}" }
    services.each { |slug| pages << "/servicii-medicale/#{slug}" }
    
    # Generate visits for the last 90 days
    puts "Creating visits..."
    90.times do |i|
      date = i.days.ago
      
      # More visits on recent days, less on older days
      visits_count = (90 - i) / 3 + rand(5..15)
      
      visits_count.times do
        visitor_token = SecureRandom.uuid
        visit_token = SecureRandom.uuid
        
        landing_page_path = pages.sample
        referrer = referrers.sample
        referring_domain = referrer == "direct" ? nil : referrer
        
        visit = Ahoy::Visit.create!(
          visit_token: visit_token,
          visitor_token: visitor_token,
          landing_page: "http://localhost:3000#{landing_page_path}",
          referrer: referrer && referrer != "direct" ? "https://#{referrer}" : nil,
          referring_domain: referring_domain,
          browser: browsers.sample,
          os: "Mac",
          device_type: devices.sample,
          city: cities.sample,
          country: countries.sample,
          started_at: date + rand(0..23).hours + rand(0..59).minutes
        )
        
        # Generate 2-5 page views per visit
        page_views = rand(2..5)
        page_views.times do |pv|
          page = pages.sample
          Ahoy::Event.create!(
            visit_id: visit.id,
            name: "$view",
            properties: { url: page },
            time: visit.started_at + (pv * 30).seconds
          )
        end
        
        # Generate some clicks (20% of visits)
        if rand < 0.2
          click_elements = [
            "Programare",
            "Contact",
            "Vezi mai mult",
            "Servicii",
            "Echipa medicală",
            "Telefon",
            "Email"
          ]
          
          clicks_count = rand(1..3)
          clicks_count.times do |ck|
            Ahoy::Event.create!(
              visit_id: visit.id,
              name: "$click",
              properties: {
                name: click_elements.sample,
                url: pages.sample
              },
              time: visit.started_at + (ck * 45 + 60).seconds
            )
          end
        end
      end
      
      print "." if i % 10 == 0
    end
    
    puts "\n✅ Seeding complete!"
    puts "📊 Total visits: #{Ahoy::Visit.count}"
    puts "📊 Total events: #{Ahoy::Event.count}"
    puts "🎉 You can now test the analytics dashboard at /dashboard/analytics"
  end
  
  desc "Clear all Ahoy analytics data"
  task clear: :environment do
    print "⚠️  This will delete ALL Ahoy data. Are you sure? (yes/no): "
    confirmation = STDIN.gets.chomp
    
    if confirmation.downcase == "yes"
      Ahoy::Event.delete_all
      Ahoy::Visit.delete_all
      puts "✅ All Ahoy data cleared!"
    else
      puts "❌ Operation cancelled."
    end
  end
end
