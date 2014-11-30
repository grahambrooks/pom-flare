# POM Flare

Simple visualisation of Java POM dependencies using the http://mbostock.github.io/d3/talk/20111116/bundle.html tools.

The pom-flare.rb file takes a single parameter for your project root directory. The script scans for pom.xml files and
then reads the dependencies and artifact names. The script outputs two JSON files. One lists each project with its
dependencies and the second a list of files that proved problematic.

The script also does some basic macro replacement for artifact and group ids.
