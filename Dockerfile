# Start from the latest
# Apache server.
# When first set up we get version 2.4.
FROM httpd:latest

# Set up some controls
ARG hugo_version=0.109.0

# Hugo repository hosted by github
# Assumes that this is accessible
# via the Host github configured
# in ssh/config, and that a read-only
# deploy key is supplied as ssh/id_rsa
ARG repo=github:gusgw/www.git
# Host that needs to be marked as known for ssh
# access to a repository
ARG host=github.com
# Branch to publish
ARG branch=work

# Ensure this is consistent with the port
# set in httpd.conf. This setting does
# not set the port for Apache, only docker EXPOSE.
ARG port=8080

# Put arguments into environment variables
ENV REPO $repo
ENV BRANCH $branch

# Set other environment variables
# This is chosen by the httpd image
ENV APACHE2 /usr/local/apache2
ENV CONF ${APACHE2}/conf
ENV HTDOCS ${APACHE2}/htdocs
ENV SCRIPT /root

# Environment variables controlling the hugo setup
ENV HUGO_VERSION $hugo_version
ENV HUGO_PACKAGE hugo_extended_${HUGO_VERSION}_linux-amd64.deb
ENV HUGO_DL https://github.com/gohugoio/hugo/releases/download
ENV HUGO_URL ${HUGO_DL}/v${HUGO_VERSION}/${HUGO_PACKAGE}

# Set Hugo parameters here instead of in the
# config.yaml or config.toml
ENV HUGO_PARAMS_BookEditPath edit/${BRANCH}/

# Configure ssh with a GitHub deploy
# key so the latest website can be cloned.
COPY ssh/ /root/.ssh/

# Configure httpd and set up accounts
COPY httpd/httpd.conf ${CONF}/httpd.conf
COPY httpd/htaccess ${HTDOCS}/.htaccess
COPY httpd/htpasswd ${APACHE2}/.htpasswd

# Install setup, hourly, and daily maintenance scripts
COPY setup ${SCRIPT}/
COPY daily /etc/cron.daily/

# Update Debian
RUN apt update -y
RUN apt upgrade -y

# Lynx is used by apachectl
# and access to the command line
# is provided by the web app host
RUN apt install -y lynx

# Install git so we can fetch the website,
# and make sure github.com is known.
RUN apt install -y git
RUN ssh-keyscan -t rsa $host >> /root/.ssh/known_hosts

# Obtain a binary install for Hugo Extended
# Note the hugo version is set above
RUN apt install -y wget
RUN wget ${HUGO_URL}
RUN dpkg --install ./${HUGO_PACKAGE}
RUN hugo version

# Use rsync to copy over the rendered site
# into Apache's served folder.
RUN apt install -y rsync

# Set up tasks such as downloading the
# raw website, rendering, and installing for Apache.
# Also configures the firewall.
RUN ${SCRIPT}/setup

# The port to serve the site
EXPOSE ${port}/tcp
