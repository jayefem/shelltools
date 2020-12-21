#!/bin/bash
#
# Apache License 2.0
#
# Author: Jan Mutter (info@jayefem.de), 2017-2019
#
# For configuration copy _shelltools to .shelltools and put it to:
# - Your home directory (e.g. ~/.shelltools) or
# - This directory (e.g. /shelltools/.shelltools)
#
# Script is not standalone but called by build.sh and run.sh
# The following variables should be already set from calling script:
# 	- MY_DIR
# 	- MY_EXEC_NAME (values: run | stop | build)
#

MY_LIB_DIR="$MY_DIR"

# Load libraries
source ${MY_LIB_DIR}lib_shelltools.sh

function setup {
	NO_RUN=""
	DRYRUN=""
}

function loadConfiguration {
	if [[ -f "${HOME}/.shelltools" ]]; then
		source "${HOME}/.shelltools"
	elif [[ -f "${MY_DIR}.shelltools" ]]; then
		source ${MY_DIR}.shelltools
	elif [[ -f "${MY_DIR}pcd.config" ]]; then
		# Keep this for downward compatability
		source ${MY_DIR}pcd.config
	fi
}

function initialize {
	if [[ -n "$PEXEC_ALREADY_INITIALIZED" ]];then
		# Only one initialization per session. Start new Bash for new configurations
		return
	fi

	# Load configuration
	loadConfiguration

	# allexport: Automatically exports all variables and functions that you create or modify after giving this command.
	set -a
		
	configMap="run"_configMap_
	for line in "${runConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#}"

		#echo "run - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	configMap="runAlias"_configMap_
	for line in "${runAliasConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#*\#\#\#}"

		#echo "runAlias - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	configMap="stop"_configMap_
	for line in "${stopConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#}"

		#echo "stop - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	configMap="stopAlias"_configMap_
	for line in "${stopAliasConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#*\#\#\#}"

		#echo "stopAlias - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	configMap="test"_configMap_
	for line in "${testConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#}"

		#echo "test - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	configMap="build"_configMap_
	for line in "${buildConfigArray[@]}" ; do
		key="${line%\#\#\#*}"
		value="${line#*\#\#\#}"

		#echo "build - configMap: $configMap - key: ${key} - value: ${value}"

		map_put $configMap ${key} ${value}
	done

	export PEXEC_ALREADY_INITIALIZED=true
}

function changeToApplicationDir {
	if [ -n "$PARAM_PROJECT_NAME" ]; then
		source $MY_DIR"pcd.sh" --no-warning $PARAM_PROJECT_NAME

		if [[ "$RETURN_CODE" == "NO_PORJECT_FOUND" ]];then
			PARAM_EXEC_ALIAS=$PARAM_PROJECT_NAME
		fi
	fi

	APPLICATION_DIR="$(basename `pwd`)"
}

function runCommand {
	runCmd=$*

	echo "${runCmd}"

	if [[ "$DRYRUN" == "true" ]];then
		echo ""
		echo "== Dry run. Did not execute command. =="
		return
	fi

	eval ${runCmd}
}

function buildDefault {
	#echo "buildDefault"

	if [[ -f "pom.xml" ]];then
		runCommand "mvn clean compile"
	elif [[ -f "build.gradle" ]];then
		runCommand "./gradlew clean compileJava"
	elif [[ -f "package.json" ]];then
		#echo "npm pack"
		#source npm pack
		runCommand "npm pack"
	else
		echo "No project found"
	fi
}

function testDefault {
	#echo "testDefault"

	if [[ -f "pom.xml" ]];then
		runCommand "mvn test"
	elif [[ -f "build.gradle" ]];then
		runCommand "./gradlew test"
	else
		echo "No project found"
	fi
}

function runDefault {
	#echo "runDefault"

	if [[ -f "pom.xml" ]];then
		runCommand "mvn spring-boot:run"
	elif [[ -f "build.gradle" ]];then
		runCommand "./gradlew bootRun"
	elif [[ -f "Vagrantfile" ]];then
		runCommand "vagrant up"
	elif [[ -f "package.json" ]];then
		runCommand "npm start"
	else
		echo "No project found"
	fi
}

function stopDefault {
	#echo "stopDefault"

	if [[ -f "pom.xml" ]];then
		runCommand "mvn spring-boot:stop"
	elif [[ -f "Vagrantfile" ]];then
		runCommand "vagrant halt"
	elif [[ -f "package.json" ]];then
		runCommand "npm stop"
	else
		echo "No project found"
	fi
}

function execute {
	if [ -z "$APPLICATION_DIR" ]; then
		return
	fi

	if [[ -n "$PARAM_EXEC_ALIAS" ]];then
		execAlias
	else
		execNormal
	fi
}

function execAlias {
	key=$APPLICATION_DIR
	configMapName=${MY_EXEC_NAME}

	key="${key}###${PARAM_EXEC_ALIAS}"
	configMapName="${configMapName}Alias"

	configMap=${configMapName}_configMap_
	projectCmd=$(map_get $configMap $key)

	# echo "configMap: ${configMap} - key: $key - projectCmd: $projectCmd"

	if [[ -z "$projectCmd" ]];then
		echo "No command found. Script aborted."

		return
	fi

	execProjectCmd $projectCmd
}

function execNormal {
	key=$APPLICATION_DIR
	configMapName=${MY_EXEC_NAME}

	configMap=${configMapName}_configMap_
	projectCmd=$(map_get $configMap $key)

	# echo "configMap: ${configMap} - key: $key - projectCmd: $projectCmd"

	execProjectCmd $projectCmd
}

function execProjectCmd {
	projectCmd=$*

	if [ -n "$projectCmd" ]; then
		runCommand $projectCmd
	else
		if [[ "${MY_EXEC_NAME}" == "run" ]];then
			runDefault
		elif [[ "${MY_EXEC_NAME}" == "stop" ]];then
			stopDefault
		elif [[ "${MY_EXEC_NAME}" == "test" ]];then
			testDefault
		else
			buildDefault
		fi
	fi
}

function usage {
	echo ""
	echo "Usage: ${MY_EXEC_NAME} [ -h | --help ] [ --dryrun ] [ <alias> ] [ <projectname> ]"
	echo ""
	echo " -h | --help     : Prints this help."
	echo " --dryrun        : Dry run. Prints the command without executing it."
	echo ""
	echo "This program '${MY_EXEC_NAME}' executes a certain command according to the given <projectname>."
	echo ""
	echo "For configuration copy _shelltools to .shelltools and put it to:"
	echo " - Your home directory (e.g. ~/.shelltools) or"
	echo " - This directory (e.g. /shelltools/.shelltools)"
	echo ""
	echo "See also https://github.com/jayefem/shelltools"
	echo ""

	NO_RUN="true"
}

function parseCommandoLineParameters {
	PARAM_EXEC_ALIAS=""
	PARAM_PROJECT_NAME=""

	while [ "$1" != "" ]; do
		case $1 in
			-h|--help)
				usage;;
			--dryrun)
				DRYRUN=true;;
			--dryRun)
				DRYRUN=true;;
			*)
				break
        		;;
	   esac

	   shift
	done

	if [[ -n "$2" ]];then
		PARAM_EXEC_ALIAS=$1
		PARAM_PROJECT_NAME=$2
	else
		PARAM_PROJECT_NAME=$1
	fi
}

setup

parseCommandoLineParameters $@

if [[ -z "${NO_RUN}" ]]; then
	initialize

	changeToApplicationDir "$1"

	execute
fi

