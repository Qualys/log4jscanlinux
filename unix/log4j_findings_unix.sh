#!/bin/sh

if [ $# -eq 0 ]; then
	BASEDIR="/";
elif [ $# -eq 1 ]; then
	BASEDIR=$1;
	if [ ! -d $BASEDIR ]; then
		echo "Please enter valid directory path";
		exit 1;
	fi;
else
	echo "Too many parameters passed in."
	echo "sh ./log4j_findings_unix.sh [base_dir] "
	echo "example: sh ./log4j_findings_unix.sh /home "
	echo "(default: [base_dir]=/ )" 
	exit 1
fi

log4j()
{
	echo "Script version: 1.0 (scans JAR files only)";	
	
	if [ "${OS}" = "AIX" ] || [ "${OS}" = "SunOS" ]; then
		echo "Scanning started.." > /opt/qualys/cloud-agent/log4j_findings.stderr;
		date >> /opt/qualys/cloud-agent/log4j_findings.stderr;
	elif [ "${OS}" = "Darwin" ]; then
		echo "Scanning started.." > /Library/Application\ Support/QualysCloudAgent/Data/log4j_findings.stderr ;
		date >> /Library/Application\ Support/QualysCloudAgent/Data/log4j_findings.stderr;
	fi;

	id=`id`
	if ! (echo $id | grep "uid=0") > /dev/null; then
		echo "Please run the script as root user for complete results";
	fi;
	
	log4j_exists=0;
	if [ ! -d /tmp/log4j_jar ]; then
		mkdir -p /tmp/log4j_jar;
	fi;	
	
	cd /tmp/log4j_jar 2>/dev/null	
	
	jars=$(find ${BASEDIR} -follow -name "*.jar" -type f 2>/dev/null)
	
	for i in $jars;	do
		if test=$(jar -tf $i | grep "[l]og4j-core" | grep "pom.xml" 2>/dev/null); then
			log4j_exists=1;	
			if jar -tf $i | grep "JndiLookup.class" >/dev/null; then
				jdi="JNDI Class Found"
			else
				jdi="JNDI Class Not Found"
			fi
			echo "Source: "$test
			echo "JNDI-Class: "$jdi
			echo 'Path= '$i;
			jar -xf $i > /dev/null
			if [ "${OS}" = "SunOS" ]; then
				ve=`cat $test | head -30 | ggrep -A 1 '<artifactId>log4j</artifactId>'| cut -d ">" -f 2 | cut -d "<" -f 1 | tail -1`
			else
				ve=`cat $test 2>/dev/null | grep -E "<artifactId>log4j</artifactId>
.+?<version>"| cut  -d ">" -f 2 | cut -d "<" -f 1 | head -2|tail -1`;
			fi;
			if [ -z "$ve" ]; then 
				echo 'log4j Unknown'; 
			else 
				echo 'log4j '$ve;
			fi;
			echo "------------------------------------------------------------------------"
			rm -rf /tmp/log4j_jar/*
		fi
	done
	
	if [ $log4j_exists -eq 0 ]; then
		echo "No log4j jars found on the system , exiting now.";
	fi;
	
	if [ "${OS}" = "AIX" ] || [ "${OS}" = "SunOS" ]; then
		echo "Run Status : Success" >> /opt/qualys/cloud-agent/log4j_findings.stderr;
	elif [ "${OS}" = "Darwin" ]; then
		echo "Run Status : Success" >> /Library/Application\ Support/QualysCloudAgent/Data/log4j_findings.stderr;
	fi;
}

OS=`uname -s`

if [ "${OS}" = "AIX" ] || [ "${OS}" = "SunOS" ]; then
	if [ ! -d "/opt/qualys/cloud-agent/" ]; then
		mkdir -p "/opt/qualys/cloud-agent/";
		chmod 750 "/opt/qualys/cloud-agent/";
	fi; 
	if [ ! -f "/opt/qualys/cloud-agent/log4j_findings_disabled" ]; then
		log4j > /opt/qualys/cloud-agent/log4j_findings.stdout 2>/opt/qualys/cloud-agent/log4j_findings.stderr;
	else
		rm -rf /opt/qualys/cloud-agent/log4j_findings.stdout; 
		echo "Flag is disabled, skipping command execution" > /opt/qualys/cloud-agent/log4j_findings.stderr;
	fi;
elif [ "${OS}" = "Darwin" ]; then
	if [ ! -d /Library/Application\ Support/QualysCloudAgent/Data/ ]; then
		mkdir -p /Library/Application\ Support/QualysCloudAgent/Data/;
		chmod 750 /Library/Application\ Support/QualysCloudAgent/Data/;
	fi;
	if [ ! -f /Library/Application\ Support/QualysCloudAgent/Data/log4j_findings_disabled ]; then
		log4j > /Library/Application\ Support/QualysCloudAgent/Data/log4j_findings.stdout 2>/Library/Application\ Support/QualysCloudAgent/Data/log4j_findings.stderr;
	else
		rm -rf /Library/Application\ Support/QualysCloudAgent/Data/log4j_findings.stdout;
		echo "Flag is disabled, skipping command execution" > /Library/Application\ Support/QualysCloudAgent/Data/log4j_findings.stderr;
	fi;
else
	echo "Unsupported platform: ${OS}, script supports only AIX, MacOS and Solaris platforms.";
fi;

