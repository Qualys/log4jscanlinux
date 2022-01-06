#!/bin/sh

if [ $# -eq 0 ]; then
	BASEDIR="/"
	NETDIR_SCAN=false
elif [ $# -eq 1 ]; then
	BASEDIR=$1
	if [ ! -d $BASEDIR ];then
		echo "Please enter valid directory path";
		exit 1;
	fi;
	NETDIR_SCAN=false
elif [ $# -eq 2 ]; then
	BASEDIR=$1
	NETDIR_SCAN=$2
	if [ ! -d $BASEDIR ]; then
		echo "Please enter valid directory path";
		exit 1;
	fi;
else
	echo "Too many parameters passed in."
	echo "sh ./log4j_findings.sh [base_dir] [network_filesystem_scan<true/false>]"
	echo "example: sh ./log4j_findings.sh /home false"
	echo "(default: [base_dir]=/ [network_filesystem_scan]=false)" 
	exit 1
fi

handle_war_ear_zip()
{
	war_file=$1
	if jar1=`unzip -l $war_file | awk '{print $NF}'| grep -i ".jar" 2> /dev/null `;then
		rm -rf /tmp/log4j_for_extract/
		mkdir /tmp/log4j_for_extract;
		unzip -d /tmp/log4j_for_extract/ $war_file > /dev/null
	fi;
	jars=`find /tmp/log4j_for_extract -type f -regextype posix-egrep -iregex ".+\.(jar)$"  2> /dev/null`; 
	for i in $jars; do 		
		IFS=$'\n'
		handle_jar $i $war_file	
	done;
	rm -rf /tmp/log4j_for_extract/
}

handle_jar_without_zip()
{	
	jar_file=$1;	
	echo "Zip/Unzip utility not present on the system, showing limited results for " $jar_file " only in output file" >> /usr/local/qualys/cloud-agent/log4j_findings.stderr;

	var=`echo $jar_file | grep -i "log4j.*jar"` 2> /dev/null; 
	if [ ! -z "$var" ]; then 
		log4j_exists=1;				
		echo 'Path= '$jar_file; 
		## Fetch log4j version from jar
		ver=`echo $jar_file | grep -o '[^\/]*$' | grep -oE "([0-9]+\.[0-9]+\.[0-9]+-[a-zA-Z0-9]*[0-9]*|[0-9]+\.[0-9]+-[a-zA-Z0-9]+[0-9]*|[0-9]+\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+)" | tail -1` 2> /dev/null; 
		if [ -z "$ver" ]; then 
			echo 'log4j Unknown'; 
		else 
			echo 'log4j '$ver; 
		fi; 
		echo "------------------------------------------------------------------------"; 
	else 
		injars=`(jar -tf $jar_file | grep -i "log4j.*jar") 2> /dev/null`; 
		for j in $injars ; do 
			if [ ! -z "$j" ]; then 						
				log4j_exists=1;
				echo 'Path= '$j; 
				## Fetch log4j version from jar
				ver1=`echo $j | grep -o '[^\/]*$' | grep -oE "([0-9]+\.[0-9]+\.[0-9]+-[a-zA-Z0-9]*[0-9]*|[0-9]+\.[0-9]+-[a-zA-Z0-9]+[0-9]*|[0-9]+\.[0-9]+\.[0-9]+|[0-9]+\.[0-9]+)" | tail -1` 2> /dev/null; 
				if [ -z "$ver1" ]; then 
					echo 'log4j Unknown'; 
				else 
					echo 'log4j '$ver1; 
				fi; 
			fi; 
			echo "------------------------------------------------------------------------"; 
		done;
	fi;
}

handle_jar_with_zip()
{
	jar_file=$1
	war_file=$2	
	if zip -sf $jar_file | grep "JndiLookup.class" >/dev/null; then 
		jdi="JNDI Class Found";
	else 
		jdi="JNDI Class Not Found";
	fi;	
	## Checking JNDI-Class value from jar file
	if test=`zip -sf $jar_file | grep -i "log4j" | grep "pom.xml"`;then 
		IFS=$oldIFS
		echo "Source: "$test;
		log4j_exists=1;
		## Reading file pom.xml to fetch log4j version
		echo "JNDI-Class: "$jdi;		
		IFS=$'\n'		
		if [ ! -z "$war_file" ];then
			p=`echo $jar_file | sed -n 's|^/tmp/log4j_for_extract/||p' `;
			echo 'Path= '$war_file'/'$p
		else 
			echo 'Path= '$jar_file
		fi
		IFS=$oldIFS
		ve=`unzip -p $i $test 2> /dev/null | grep -Pzo "<artifactId>log4j</artifactId>\s*<version>.+?</version>"| cut -d ">" -f 2 | cut -d "<" -f 1 | head -2|awk 'ORS=NR%3?FS:RS'`;
		if [ -z "$ve" ]; then 
			echo 'log4j Unknown'; 
		else 
			echo $ve; 
		fi;
		echo "------------------------------------------------------------------------";
	fi;
}

handle_jar()
{
  if [ "$isZip" -eq 0 ] && [ "$isUnZip" -eq 0 ]; then         
	handle_jar_with_zip "$@";  
  else
	handle_jar_without_zip "$@";  
  fi;
}

log4j()
{
    echo "Script version: 2.1 (scans jar/war/ear/zip files)" ;
    echo "Scanning started.." > /usr/local/qualys/cloud-agent/log4j_findings.stderr ;
    date >> /usr/local/qualys/cloud-agent/log4j_findings.stderr ;    
    id=`id`;
    if ! (echo $id | grep "uid=0")>/dev/null; then 
        echo "Please run the script as root user for complete results";
    fi;    
    zip -v 2> /dev/null 1> /dev/null;
    isZip=$?;
    unzip -v 2> /dev/null 1> /dev/null;
    isUnZip=$?;
    log4j_exists=0;
    oldIFS=$IFS

    # Change to a network filesystem only scan if 2nd parameter is true. network filesystem scan command
    # does not use '!' flags
    if [ $NETDIR_SCAN = true ];then
        jars=$(find ${BASEDIR} -type f -regextype posix-egrep -iregex ".+\.(jar|war|ear|zip)$"  2> /dev/null); 
    else
	jars=$(find ${BASEDIR} -type f -regextype posix-egrep -iregex ".+\.(jar|war|ear|zip)$"  ! -fstype nfs ! -fstype nfs4 ! -fstype cifs ! -fstype smbfs ! -fstype gfs ! -fstype gfs2 ! -fstype safenetfs ! -fstype secfs ! -fstype gpfs ! -fstype smb2 ! -fstype vxfs ! -fstype vxodmfs ! -fstype afs -print 2>/dev/null);
    fi 
	
    	IFS=$'\n'
	for i in $jars ; do 	 
		if `echo $i | grep -q ".jar"`; then
			handle_jar $i
		else
			if [ "$isZip" -eq 0 ] && [ "$isUnZip" -eq 0 ];then 
				handle_war_ear_zip $i
			else
				echo "Zip/Unzip utility not present on the system, skipping processing of file: "$i >> /usr/local/qualys/cloud-agent/log4j_findings.stderr;
			fi
		fi
    		IFS=$'\n'
	done
	if [[ $log4j_exists -eq 0 ]]; then
		echo "No log4j jars found on the system for base directory , exiting now.";
	fi;
    echo "Run status : Success" >> /usr/local/qualys/cloud-agent/log4j_findings.stderr;
};

if [ ! -d "/usr/local/qualys/cloud-agent/" ]; then 
    mkdir -p "/usr/local/qualys/cloud-agent/";
    chmod 750 "/usr/local/qualys/cloud-agent/";
fi; 

if [ ! -f "/usr/local/qualys/cloud-agent/log4j_findings_disabled" ]; then 
    log4j > /usr/local/qualys/cloud-agent/log4j_findings.stdout 2>/usr/local/qualys/cloud-agent/log4j_findings.stderr;
else 
    rm -rf /usr/local/qualys/cloud-agent/log4j_findings.stdout; 
    echo "Flag is disabled, skipping command execution" > /usr/local/qualys/cloud-agent/log4j_findings.stderr;
fi;
