#!/usr/bin/env ruby

require 'rubygems'
require 'fog'
require 'set'
require 'digest/md5'

SPIN_CHARS=['|','/','-','\\']
MAX_FILES_TO_PURGE=10

def spin()
	@counter = ((@counter || 0) + 1) % SPIN_CHARS.length
	print "\b#{SPIN_CHARS[@counter]}"
end

def error(text)
	puts text
	exit(127)
end

container_name = ARGV[0] || File.basename(Dir.pwd)

site_directory = File.join(Dir.pwd, "_site")
site_files = Dir.glob(File.join(site_directory, "**/*")).reject{|f| File.directory?(f)}

site_files_set = Set.new(site_files.collect{|f| f.gsub(/^#{site_directory}\//,"")})
#Convert the list of local files to name => hash
site_files_hash = site_files_set.to_a.collect{|f| [f, Digest::MD5.hexdigest(File.read(File.join(site_directory, f)))]}.inject({}) { |r, s| r.merge!({s[0] => s[1]}) }

begin
	service = Fog::Storage.new({
		:provider=>"Rackspace",
		:rackspace_username=>Fog.credentials[:rackspace_username],
		:rackspace_api_key=>Fog.credentials[:rackspace_api_key],
		:rackspace_region =>Fog.credentials[:rackspace_region].to_sym,
	})
rescue Exception => e
	error("Unable to log in, please check your credentials")
end

cloud_directory = service.directories.find{|d| d.key == container_name}

error("No container found with name #{container_name}") if cloud_directory.nil?

cloud_files = cloud_directory.files.reject{|f| f.content_type.include?("/directory")}

puts "Synchronizing #{site_files_set.length} files to container #{container_name}"

#Convert the list of cloud files to name => CloudFile object
cloud_files_hash = cloud_files.collect{|f| [f.key, f]}.inject({}) { |r, s| r.merge!({s[0] => s[1]}) }
cloud_files_set = Set.new(cloud_files_hash.keys)

to_delete_set = cloud_files_set - site_files_set
to_delete = cloud_files_hash.select { |key,_| to_delete_set.include? key }

print "Deleting #{to_delete.size} files... "
to_delete.each do |name, file|
	spin
	file.destroy
end
puts "\bdone."

to_create = site_files_hash.select { |name, _| !cloud_files_set.include?(name) }

print "Creating #{to_create.size} files... "
to_create.each do |name, hash|
	spin
	cloud_directory.files.create :key => name, :body => File.open(File.join(site_directory, name))
end
puts "\bdone."

to_update = site_files_hash.select do |name, md5| 
	cloud_files_set.include?(name) && cloud_files_hash[name].etag != md5
end

print "Updating #{to_update.size} files... "
to_update.each do |name, hash|
	spin
	new_file = cloud_directory.files.create :key => name, :body => File.open(File.join(site_directory, name))
end
puts "\bdone."

if(to_delete.size + to_create.size + to_update.size > 0)
	puts "------------"
	puts "Changes: "
	puts to_delete_set.to_a.collect{|f| " D #{f}"}.join("\n") if to_delete.size > 0
	puts to_create.collect{|f, _| " A #{f}"}.join("\n") if to_create.size > 0
	puts to_update.collect{|f, _| " M #{f}"}.join("\n") if to_update.size > 0
end

if(to_update.length < MAX_FILES_TO_PURGE)
	puts "------------"
	print "Attempting to purge #{to_update.length} file(s) from CDN..."
	purged = 0
	to_update.each do |name, hash|
		begin
			ret=cloud_files_hash[name].purge_from_cdn
			purged = purged + 1 if ret
		rescue Exception => e
		    #Ignore
		end
	end
	puts "#{purged} file(s) purged."
else
	puts "Too many files modified to purge, must wait for TTL to expire."
end



