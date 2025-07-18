require 'net/http'
require 'json'
require 'uri'
require 'csv'
require 'time'

# === Configuration ===
owner = "dalhougaard"
repo = "DX"
state = "closed" # or "all" if you want open + closed PRs
output_file = "pull_requests.csv"

# Optional: use a GitHub token to avoid rate limits
# token = "your_token_here"

# === Fetch PR list ===
pulls_url = URI("https://api.github.com/repos/#{owner}/#{repo}/pulls?state=#{state}&per_page=100")

http = Net::HTTP.new(pulls_url.host, pulls_url.port)
http.use_ssl = true

pulls_request = Net::HTTP::Get.new(pulls_url)
# pulls_request["Authorization"] = "token #{token}"
pulls_request["User-Agent"] = "ruby-script"

pulls_response = http.request(pulls_request)

unless pulls_response.is_a?(Net::HTTPSuccess)
  puts "❌ Failed to fetch pull requests: #{pulls_response.code} #{pulls_response.message}"
  puts pulls_response.body
  exit
end

pulls = JSON.parse(pulls_response.body)

# === Create CSV file ===
CSV.open(output_file, "w") do |csv|
  csv << [
    "PR Number", "Title", "Author",
    "Created At", "Merged At", "Time to Merge (hrs)",
    "Additions", "Deletions", "URL"
  ]

  pulls.each do |pr|
    # Skip if not merged (since you want merge info)
    next unless pr["merged_at"]

    # Fetch detailed PR info to get additions/deletions
    pr_url = URI(pr["url"])
    pr_request = Net::HTTP::Get.new(pr_url)
    # pr_request["Authorization"] = "token #{token}"
    pr_request["User-Agent"] = "ruby-script"
    pr_response = http.request(pr_request)

    unless pr_response.is_a?(Net::HTTPSuccess)
      puts "⚠️ Failed to fetch PR ##{pr['number']} details"
      next
    end

    pr_details = JSON.parse(pr_response.body)

    created_at = Time.parse(pr["created_at"])
    merged_at = Time.parse(pr["merged_at"])
    time_to_merge = ((merged_at - created_at) / 3600).round(2)

    csv << [
      pr["number"],
      pr["title"],
      pr["user"]["login"],
      created_at.utc.iso8601,
      merged_at.utc.iso8601,
      time_to_merge,
      pr_details["additions"],
      pr_details["deletions"],
      pr["html_url"]
    ]
  end
end

puts "✅ Pull request data saved to #{output_file}"
