# Edit these:
access_token = ''
domain = ''  #only need the subdomain
env = nil #test, beta or nil
input_file = 'courses.csv'
#============
# Don't edit from here down unless you know what you're doing.

require 'unirest'
require 'csv'
require 'json'
require 'open-uri'
require 'fileutils'
require "net/http"
require 'active_support/core_ext/object/blank'



unless access_token
  puts "what is your access token?"
  access_token = gets.chomp
end

unless domain
  puts "what is your Canvas domain?"
  domain = gets.chomp
end

unless input_file
  puts "where is your input CSV, listing courses to migrate, located?"
  input_file = gets.chomp
end

unless File.exists?(input_file)
  raise "Error: can't locate the input CSV"
end



def directory_exists?(directory)
  File.directory?(directory)
end


env ? env << "." : env
base_url = "https://#{domain}.#{env}instructure.com/api/v1"
test_url = "#{base_url}/accounts/self"

Unirest.default_header("Authorization", "Bearer #{access_token}")

# Make generic API call to test token, domain, and env.
test = Unirest.get(test_url)

unless test.code == 200
  raise "Error: The token, domain, or env variables are not set correctly"
end

CSV.foreach(input_file, {:headers => true}) do |cid|

  FileUtils.mkdir "#{cid[0]}"

  url ="#{base_url}/courses/#{cid[0]}/assignments"
  list_assignments = Unirest.get(url)
  job = list_assignments.body
  
#commented out from here. lets focus on the folders first

    job.each do |assignment|
      
      aid = assignment["id"]
      submissionsurl ="#{base_url}/courses/#{cid[0]}/assignments/#{aid}/submissions?include[]=course&include[]=assignment&per_page=100"
      

      list_submissions = Unirest.get(submissionsurl)
      submissions = list_submissions.body


     # unless submissions[0] == nil

      submissions.each do |sub|
        user_canvas_id = sub["user_id"]
        late = sub["late"]
        course_code =  sub["course"]["course_code"]
        attachments =  sub['attachments']
        assignment_name = sub["assignment"]["id"]
        


        if attachments.present?

            attachments.each do |things|


            user_details_url = "#{base_url}/users/#{user_canvas_id}" 
            get_user_details = Unirest.get(user_details_url)
            user_details = get_user_details.body

            user_name = user_details["name"]
            sis_user_id = user_details["sis_user_id"]
            

            if !directory_exists?("#{cid[0]}/#{sis_user_id}")
             FileUtils.mkdir "#{cid[0]}/#{sis_user_id}"

            end
            
            if directory_exists?("#{cid[0]}/#{sis_user_id}/Assignment_id_#{assignment_name}")
            
              downloadurl = things["url"]
              file_name = things["display_name"]
              check_url = URI.parse(downloadurl)
              req = Net::HTTP.new(check_url.host, check_url.port)
              req.use_ssl = true
              resolvedurl = req.request_head(check_url.path)
                

                if resolvedurl.code == "302"

                  open("#{cid[0]}/#{sis_user_id}/Assignment_id_#{assignment_name}/#{file_name}", 'wb') do |file|
                  file << open(downloadurl).read
                  
                end
      
                else

                puts "that file has been deleted by the user and is not longer accessible from the API"

                end
            
            else
            
            FileUtils.mkdir "#{cid[0]}/#{sis_user_id}/Assignment_id_#{assignment_name}"
            
            downloadurl = things["url"]
            file_name = things["display_name"]
            check_url = URI.parse(downloadurl)
            req = Net::HTTP.new(check_url.host, check_url.port)
            req.use_ssl = true
            resolvedurl = req.request_head(check_url.path)
                

              if resolvedurl.code == "302"

                open("#{cid[0]}/#{sis_user_id}/Assignment_id_#{assignment_name}/#{file_name}", 'wb') do |file|

                file << open(downloadurl).read

                end
        
              else

              puts "that file has been deleted by the user and is not longer accessible from the API"

              end

          end

          
        end


      end


end

end

end

puts "Successfully output files to directory."

