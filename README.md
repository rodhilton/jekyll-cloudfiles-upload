jekyll-cloudfiles-upload
========================

This is a simple script that uploads the contents of a jekyll-generated `_site` directory to rackspace cloud files.  There's a popular python-based solution out there, but I was unable to make it work properly, so I gave up and wrote my own.

# Prerequisites

 * Ruby (tested on 2.1.1)
 * `fog` ruby gem
 * Rackspace cloudfiles account

# Installation

1. Log into Rackspace Cloud Files and create your container.  _You must create your container first, the script will not do that_.

2. Install `fog` rubygem via `gem install fog`

3. Put a `.fog` file in your home directory that looks like this (it's a yaml file, be careful not to use tabs instead of spaces):

~~~yaml
default:
    rackspace_username: your_user_name
    rackspace_api_key: your_api_key
    rackspace_region: your_preferred_region
~~~

The rackspace regions are strings like 'iad' or 'dfw', depending on your preferred container region.  You can get your api key from the Rackspace control panel's Account page.

4. Copy the `cloudfiles_upload.rb` script into the directory for your jekyll project.  It's a good idea to also make it executable via `chmod a+x cloudfiles_upload.rb`

5. Build your site via `jekyll build`

6. Execute `./cloudfiles_upload.rb container_name` or `ruby cloudfiles_upload.rb container_name`.

The script will spider through the `_site` subdirectory and look for any files that need to be added, deleted, or updated.  Only files whose md5 hashes differ will from those in the container will be uploaded, so it will upload files unnecessarily.

**Note**: You may optionally leave off the `container_name` parameter, and the script will use the name of the directory you are in.  So if you name your directory and container `mysite.com`, you can just run `./cloudfiles_upload.rb` with no arguments.

# Disclaimer

I make no guarantees about this software, though I'll happily accept pull requests for any fixes or updates that are applied.  I use this script to manage my own jekyll-based blogs, but I've only tested it on my particular machines with my particular versions of ruby, fog, etc.  Software provided as-is.


        
