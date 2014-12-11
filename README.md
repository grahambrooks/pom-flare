# POM Flare

Simple visualisation of Java POM dependencies using the http://mbostock.github.io/d3/talk/20111116/bundle.html tools.

The pom-flare.rb file takes a single parameter for your project root directory. The script scans for pom.xml files and
then reads the dependencies and artifact names. The script outputs two JSON files. One lists each project with its
dependencies and the second a list of files that proved problematic.

The script also does some basic macro replacement for artifact and group ids.

## Usage

Clone the repo

    git clone git@github.com:grahambrooks/pom-flare.git

Install the required dependencies

    bundle install

edit the filters.rb file to only match one or more regular expression filters

Run the app

    ruby pom-flare.rb /path/to/projects

Run the web server

    rackup

Open

    http://localhost:9292

Enjoy!