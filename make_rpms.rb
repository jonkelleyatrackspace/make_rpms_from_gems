#!/usr/bin/ruby
 
# Author: Saleem Ansari <tuxdna@gmail.com>
# License: GPLv2
 
# Requirements:
#  # yum install rubygem-gem2rpm
#  # yum install ruby rubygems
#  # yum install rpmdevtools
#
# How to run:
#  $ ruby make_rpms.rb -t ~/tmp/rpm-gem-packaging/ -n mechanize -r 2.2.1
# This will download the gem and dependencies and generate SRPM and RPM 
#  files in the ~/tmp/rpm-gem-packaging/rpmbuild/ folder. 
# NOTE: The status of SUCCESS and FAILURE can be seen in the file:
#  ~/tmp/rpm-gem-packaging/rpmbuild/status.txt
#
# Check for RPM and SRPM files which were generated:
#  $ cd ~/tmp/rpm-gem-packaging/
#  $ tree rpmbuild/{RPMS,SRPMS}
 
 
 
# Algorithm:
# given a gem name and its version
# download the gem and its dependencies ( cache/ )
# TODO: do this in DAG order
# for each of the gem in gems do
#   create a RPM spec file for gem
#   copy spec file to SPECS folder
#   copy gem file to SOURCES folder
#   run rpmbuild
# end
 
require 'rubygems'
require 'optparse'
require 'fileutils'
 
 
## These are some notes - ignore them
# Gem::Specification::dirs()
# Gem::Specification::find_all_by_name('rails')
# Gem::Specification::find_all_by_name('rails').each { |s| puts s.version }; nil
# cmd = "GEM_HOME=#{gem_install_dir} gem specification #{gem_name} -v #{gem_version} > #{gem_name}-#{gem_version}.yml"
 
# puts cmd
# GEM_HOME=`pwd`/gem-tmp irb
# >> Gem::Specification::dirs
# => ["/home/sansari/tmp/gem-tmp/specifications", "/home/sansari/.gem/ruby/1.8/specifications", "/usr/lib/ruby/gems/1.8/specifications"]
# >> 
# >> yd = YAML.load_file("mechanize.yml")
## end notes
 
tmp_folder = "/tmp/mk-gem2rpm"
verbose = false
gem_name = nil
gem_version = nil
 
option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: make_rpms.rb [options]"
  opts.separator ""
  opts.separator "Specific options:"
 
  # Mandatory arguments
 
  opts.on("-t", "--tmpdir ",
          "Temporary directory") do |tmp_dir|
    tmp_folder = File.expand_path(tmp_dir)
  end
 
  opts.on("-n", "--gem-name [GEM_NAME]", "Gem name") do |name|
    gem_name = name
  end
 
  opts.on("-r", "--gem-version [GEM_VERSION]]", "Gem version") do |version|
    gem_version = version
  end
 
  opts.separator ""
  opts.separator "Common options:"
 
  opts.on("-v", "--verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
 
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
 
  # Another typical switch to print the version.
  opts.on_tail("--version", "Show version") do
    puts OptionParser::Version.join('.')
    exit
  end
end
 
option_parser.parse!
 
gem_install_dir = File.join(tmp_folder, "gems")
rpmbuild_dir = File.join(tmp_folder, "rpmbuild")
status_file = File.join(tmp_folder, "status.txt")
 
puts "TMP folder:            #{tmp_folder}"
puts "GEM install directory: #{gem_install_dir}"
puts "RPM build directory:   #{rpmbuild_dir}"
puts "Gem Name:              #{gem_name}"
puts "Gem Version:           #{gem_version}"
 
gem_spec_dir = File.join(gem_install_dir, "specification")
FileUtils.mkdir_p(gem_install_dir)
FileUtils.mkdir_p(rpmbuild_dir)
 
 
cmd = "gem install  -V --no-ri --no-rdoc --install-dir #{gem_install_dir} #{gem_name} -v #{gem_version}"
 
puts "executing: #{cmd}"
system(cmd)
 
gems_cache_dir = File.join(gem_install_dir, "cache")
gem_entries = Dir.entries(gems_cache_dir)
gem_entries.reject! { |x| [".",".."].include?(x) or (x !~ /\.gem$/ )}
rpm_specs_dir = File.join(rpmbuild_dir, "SPECS")
rpm_sources_dir = File.join(rpmbuild_dir, "SOURCES")
FileUtils.mkdir_p(rpm_sources_dir)
FileUtils.mkdir_p(rpm_specs_dir)
 
rpm_macros = {
  "_topdir" => "#{rpmbuild_dir}",
  "_unpackaged_files_terminate_build" => "0"
}
 
macros_cli = rpm_macros.map{ |a| "--define '#{a[0]} #{a[1]}'" }.join(" ")
 
gem_status = []
 
status_f = File.open(status_file, "w")
 
gem_entries.each do |gem|
  gem_location = File.join(gems_cache_dir, gem)
  puts gem_location
 
  specfile_name = gem.sub(/.gem$/, ".spec")
  specfile_location = "#{rpm_specs_dir}/#{specfile_name}"
  cmd = "gem2rpm -t spec.template #{gem_location} > #{specfile_location}"
  puts "executing: #{cmd}"
  system(cmd)
 
  FileUtils.cp(gem_location, rpm_sources_dir)
 
  cmd = "rpmbuild  #{macros_cli} -ba #{specfile_location} "
  puts "executing: #{cmd}"
  retval = system(cmd)
  status = if retval then "SUCCESS" else "FAILURE" end
  s = {:gem => gem, :status => status}
  gem_status.push(s)
  status_f.write("#{s[:gem]}: #{s[:status]} \n")
  status_f.flush
end
