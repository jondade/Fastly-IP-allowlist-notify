# Fastly IP whitelist mailer cron script

## Introduction

This script is a cron script which keeps an MD5 of the last / latest list of IPs that Fastly uses.
It prediodically will pull a new list and check the MD5 against the stored one. If it has changed, 
it will mail out to a .

## Requirements

### System Requirements

* Curl - A command line web client [http://curl.haxx.se/](http://curl.haxx.se/)
* mail(x) - A command line tool for smtp/mail interactions.
* /etc/mail.rc - This needs to be configured to successfully send email.

### Fastly Requirements

* Fastly account with IP list enabled.
* Fastly API key found on the account page.

## Instructions

### Using Git to get this script

Ensure you have a version of git installed on the machine you wish to use this script on. In github 
review the branches and choose the one you wish to use. At each major release there will be a stable 
branch. Or you can run on the Head version, but this may be in active development and so is not advised 
for production environments. 

Run the following to clone the respository to your target machine.

```
git clone -b <branch_name> https://github.com/jondade/IP-whitelist-cron.git <target_folder_name>
```

### Using https to get this script

Review the branches on github and choose which you wish to pull down and use. Click into the script 
'whitelist-cron.sh' and choose the raw view. Note down the URL (or copy it). Then on the machine you 
wish to install it on.You will need to use a command line tool like curl or wget. Or your browser to save the file.

```
wget https://github.com/jondade/IP-whitelist-cron/<rest_of_path>
```

### Running the install

Then change directory into the folder that was cloned or the location the file was saved. Make sure you have your Fastly API key to hand 
and a list of email recipients. Then run

```
/bin/bash whitelist-cron.sh -i
```

This will call the install function and configure the script to run on a weekly basis. It will ask 
for the necessary details (key and recipients). If you wish to change any of the other default values used, these 
are stored at the top of the script.

## Support

While no official support for this is offered by Fastly, please contact them via the [community forums](https://community.fastly.com/), 
or via [support](mailto:support@fastly.com). 

This script is provided as-is with no warranty offered or implied. It is used entirely at the user's own risk. The author 
accepts no liability for any defects or unexpected or undesired results.

## Contributing
If you find any bugs with this code, please post full details to this repository on Github and I'll do my best to address these.

On the other hand should you have a patch, feature or improvement a pull request is always welcome. Please make sure you comment your changes and keep the code neat as this will help me to review and merge any changes.