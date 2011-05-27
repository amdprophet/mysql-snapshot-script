require 'rubygems'
require 'mysql'
require 'open4'
require 'fog'
require 'active_support'

# Amazon AWS Configuration
AWS_ACCESS_KEY_ID = ''
AWS_SECRET_ACCESS_KEY = ''
AWS_VOLUME = '' # EBS volume to make snapshots of

# MySQL Configuration
MYSQL_HOST = ''
MYSQL_USERNAME = ''
MYSQL_PASSWORD = ''

class Time 
  %w(to_date to_datetime).each do |method| 
    public method if private_instance_methods.include?(method) 
  end 
end

now = Time.now
today = now.to_date
hr24 = (now - 86400)

# Connect to MySQL
puts 'Connecting to MySQL...'
my = Mysql::new(MYSQL_HOST, MYSQL_USERNAME, MYSQL_PASSWORD)

# Connect to AWS
puts 'Connecting to AWS...'
compute = Fog::Compute.new(:provider => 'AWS', 
	:aws_access_key_id => AWS_ACCESS_KEY_ID,
	:aws_secret_access_key => AWS_SECRET_ACCESS_KEY)

# Stop replication
puts 'Stopping MySQL Replication...'
my.query('STOP SLAVE')

# Lock the table(s)
puts 'Locking MySQL Tables...'
my.query('FLUSH TABLES WITH READ LOCK')

# Sync the filesystem
puts 'Syncing the filesystem...'
status = Open4::popen4('sync') do |pid, stdin, stdout, stderr|
	# Wait for the command to finish executing; handle any errors
	# TODO: Add e-mail / ticket support if an error occurs
end

# XFS Freeze
puts 'Freezing XFS...'
status = Open4::popen4('xfs_freeze -f') do |pid, stdin, stdout, stderr|
	# Wait for the command to finish executing; handle any errors
	# TODO: Add e-mail / ticket support if an error occurs
end

# Create new EBS Snapshot
puts 'Creating a new EBS Snapshot...'
snap = compute.snapshots.new :volume_id => AWS_VOLUME, :description => 'MySQL Backup'
puts 'Saving the new EBS Snapshot...'
snap.save

# XFS Unfreeze
puts 'Unfreezing XFS...'
status = Open4::popen4('xfs_freeze -u') do |pid, stdin, stdout, stderr|
	# Wait for the command to finish executing; handle any errors
	# TODO: Add e-mail / ticket support if an error occurs
end

# Unlock the table(s)
puts 'Unlocking MySQL Tables...'
my.query('UNLOCK TABLES')

# Start replication
puts 'Starting MySQL Replication...'
my.query('START SLAVE')

# Delete old EBS Snapshot(s)
puts 'Deleting old EBS Snapshots...'
snaps = compute.snapshots.all.collect do |s|
	if s.volume_id == AWS_VOLUME
		if s.progress == '100%'
			[s.id, Time.parse(s.created_at.to_s)]
		end
	end
end

# Remove nil entries
snaps.delete_if do |s|
	s == nil
end

# Remove entries from the past 24 hours
snaps.delete_if do |s|
	s.last >= hr24
end

# Keep only one from each day
dated = snaps.group_by do |s|
	s.last.to_date
end

today.downto(today - 7) do |date|
	dated[date].delete dated[date].sort_by(&:last).last if dated[date]
end

deleting = dated.inject([]) { |a,(k,v)| a << v.map(&:first) }.flatten 

deleting.each do |snap|
	compute.snapshots.get(snap).destroy
end
